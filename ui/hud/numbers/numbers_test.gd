##
## Unit tests for `KitHudNumbers`, which owns floating combat numbers end to end: where
## they spawn, that they hold their place in the world, and that they free themselves.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GROUP_2D := preload("../group_2d.tscn")
const NUMBERS := preload("numbers.gd")
const STYLE_CRIT := preload("style_crit.tres")
const STYLE_DAMAGE := preload("style_damage.tres")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _anchor: KitHudAnchor2D = null
var _container: SubViewportContainer = null
var _group: KitHudGroup = null
var _layer: KitHudLayer2D = null
var _map: KitMap2D = null
var _numbers: KitHudNumbers = null
var _root: Control = null
var _target: Node2D = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_pop_spawns_a_number_under_the_layer() -> void:
	# Given: A numbers element in a mounted group.
	# When: A value is popped.
	_numbers.pop(12.0)
	# Then: A number exists, parented to the layer rather than to the group, so it does
	# not follow the entity that produced it.
	var number := _find_number()
	assert_not_null(number)
	assert_eq(number.get_parent(), _layer)
	assert_eq(number.text, "12")


func test_number_holds_its_world_position_across_a_camera_pan() -> void:
	# Given: A number popped over an entity, with drift removed so the projection is the
	# only thing that can move it.
	_numbers.style = _make_still_style()
	_target.global_position = Vector2(120, 80)
	_numbers.pop(5.0)
	await wait_process_frames(1)

	var number := _find_number()
	var before := number.global_position

	# When: The camera pans.
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-40, -10))
	await wait_process_frames(1)

	# Then: The number moves with the world, staying over the spot it came from, rather
	# than hanging in screen space.
	assert_almost_eq(number.global_position - before, Vector2(-40, -10), Vector2(1, 1))


func test_number_does_not_follow_its_entity() -> void:
	# Given: A number popped over an entity, with drift removed.
	_numbers.style = _make_still_style()
	_target.global_position = Vector2(120, 80)
	_numbers.pop(5.0)
	await wait_process_frames(1)

	var number := _find_number()
	var before := number.global_position

	# When: The entity walks away.
	_target.global_position = Vector2(300, 80)
	await wait_process_frames(1)

	# Then: The number stays where the hit landed. Only the drift moved it.
	assert_lt(absf(number.global_position.x - before.x), 2.0)


func test_two_styles_produce_different_motion() -> void:
	# Given: Two numbers elements in one group, one damage and one critical.
	var crit := NUMBERS.new()
	crit.style = STYLE_CRIT
	_group.add_child(crit)
	crit.owner = _group

	# When: Each pops a value.
	_numbers.pop(7.0)
	crit.pop(7.0)
	await wait_process_frames(1)

	# Then: They differ in how they read, from the style alone and with no branch in the
	# element; the critical one is scaled up by its punch.
	var spawned := _find_numbers()
	assert_eq(spawned.size(), 2)

	var scales: Array[float] = []
	for number in spawned:
		scales.append(number.scale.x)

	scales.sort()
	assert_almost_eq(scales[0], 1.0, 0.01)
	assert_gt(scales[1], 1.0)


func test_number_frees_itself_when_it_finishes() -> void:
	# Given: A numbers element with a very short style.
	var style := KitHudNumberStyle.new()
	style.duration = 0.05
	style.punch = 0.0
	_numbers.style = style
	# When: A value is popped and its life elapses.
	_numbers.pop(1.0)
	assert_eq(_find_numbers().size(), 1)

	await wait_seconds(0.2)

	# Then: It is gone, with no pool and nothing to clean up.
	assert_eq(_find_numbers().size(), 0)


func test_pop_works_before_the_layer_is_ready() -> void:
	# Given: A layer that has not entered the tree, so nothing under it has been readied.
	# An entity placed in a map scene at author time pops its first number from a
	# `_ready` that lands in exactly this window.
	var layer := KitHudLayer2D.new()
	layer.map = _map
	assert_false(layer.is_node_ready())

	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	_target.add_child(anchor)

	var group := layer.attach(anchor)
	var numbers := NUMBERS.new()
	numbers.style = STYLE_DAMAGE
	group.add_child(numbers)

	# When: A value is popped before any of it is ready.
	numbers.pop(7.0)

	# Then: The number exists rather than the call failing on an unready element.
	var found := 0
	for child in layer.get_children():
		if child is KitHudNumber:
			found += 1

	assert_eq(found, 1)

	layer.queue_free()


func test_pop_outside_a_group_freezes_the_screen_position() -> void:
	# Given: A numbers element mounted on the layer with no group to ask, with drift
	# removed so the projection is the only thing that can move what it spawns.
	var loose := NUMBERS.new()
	loose.style = _make_still_style()
	_layer.add_child(loose)
	loose.global_position = Vector2(400, 300)

	# When: A value is popped and the camera then pans.
	loose.pop(3.0)
	await wait_process_frames(1)

	var number := _find_number()
	var before := number.global_position

	_viewport.canvas_transform = Transform2D(0.0, Vector2(-40, 0))
	await wait_process_frames(1)

	# Then: It stays put on screen rather than erroring for want of a world position.
	assert_almost_eq(number.global_position.x, before.x, 0.001)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920, 1080)
	add_child_autofree(_root)

	_map = partial_double(KitMap2D).new()
	stub(_map, "_ready").to_do_nothing()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)
	_map.sub_viewport = _viewport

	_ui = Control.new()
	_map.add_child(_ui)

	_layer = KitHudLayer2D.new()
	_layer.map = _map
	_ui.add_child(_layer)
	_map.hud = _layer

	_target = Node2D.new()
	_viewport.add_child(_target)

	_anchor = KitHudAnchor2D.new()
	_anchor.group_scene = GROUP_2D
	_target.add_child(_anchor)

	_group = _anchor.group

	_numbers = NUMBERS.new()
	_numbers.style = STYLE_DAMAGE
	_group.add_child(_numbers)

	# NOTE: `owner` is how an element finds its group, and Godot only sets it for nodes
	# loaded from a scene, so a hand-built fixture sets it itself.
	_numbers.owner = _group


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_still_style returns a style with no drift and no spread, so a test can watch
## the projection alone move a number.
func _make_still_style() -> KitHudNumberStyle:
	var style := KitHudNumberStyle.new()
	style.travel = Vector2.ZERO
	style.spread_degrees = 0.0
	style.punch = 0.0
	style.duration = 5.0

	return style


## _find_number returns the single spawned number, failing the test when there is not
## exactly one.
func _find_number() -> KitHudNumber:
	var spawned := _find_numbers()
	assert_eq(spawned.size(), 1)
	return spawned[0] if spawned.size() == 1 else null


## _find_numbers returns every live number mounted on the layer.
func _find_numbers() -> Array[KitHudNumber]:
	var out: Array[KitHudNumber] = []

	for child in _layer.get_children():
		var number := child as KitHudNumber
		if number and not number.is_queued_for_deletion():
			out.append(number)

	return out
