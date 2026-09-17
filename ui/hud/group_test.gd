##
## Unit tests for `KitHudGroup`: the off-screen visibility it owns, and the
## configuration warning that catches a group scene authored without a tracker.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GROUP_2D := preload("group_2d.tscn")

## OFFSCREEN is a world position well outside the 640x360 viewport.
const OFFSCREEN := Vector2(10000, 10000)

const TOLERANCE := Vector2(0.001, 0.001)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _anchor: KitHudAnchor2D = null
var _container: SubViewportContainer = null
var _layer: KitHudLayer2D = null
var _map: KitMap2D = null
var _root: Control = null
var _target: Node2D = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_group_is_visible_while_its_target_is_in_view() -> void:
	# Given: A target inside the viewport.
	_target.global_position = Vector2(100, 100)
	var group := _layer.attach(_anchor)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The group shows.
	assert_true(group.visible)


func test_group_hides_when_its_target_leaves_the_view() -> void:
	# Given: A visible group.
	_target.global_position = Vector2(100, 100)
	var group := _layer.attach(_anchor)
	await wait_process_frames(1)
	assert_true(group.visible)
	# When: The target moves off-screen.
	_target.global_position = OFFSCREEN
	await wait_process_frames(1)
	# Then: The group hides, so it never draws in the letterbox.
	assert_false(group.visible)


func test_group_stays_visible_offscreen_when_hiding_is_off() -> void:
	# Given: A group that opts out of hiding, as an off-screen indicator does.
	var group := _layer.attach(_anchor)
	group.hide_offscreen = false
	group.visible = true
	# When: The target moves off-screen.
	_target.global_position = OFFSCREEN
	await wait_process_frames(1)
	# Then: It keeps drawing, clamped at the edge by its tracker.
	assert_true(group.visible)


func test_group_starts_hidden_so_it_never_flashes() -> void:
	# Given: A target that spawns off-screen.
	_target.global_position = OFFSCREEN
	# When: Its group is attached, before any frame has run.
	var group := _layer.attach(_anchor)
	# Then: The group is already hidden, rather than showing for one frame at the wrong
	# position and then correcting.
	assert_false(group.visible)


func test_of_finds_the_group_from_an_element_it_does_not_own() -> void:
	# Given: An element nested inside a sub-scene within the group, so the group is an
	# ancestor but not its `owner`. Reusing one row of elements across several group
	# scenes produces exactly this, and reading `owner` would answer the row instead.
	var group := _layer.attach(_anchor)

	var row := Control.new()
	group.add_child(row)

	var element := Control.new()
	row.add_child(element)
	element.owner = row

	# When: The element looks for its group.
	# Then: It finds it, where `owner` would have answered the row.
	assert_eq(KitHudGroup.of(element), group)
	assert_ne(element.owner, group)


func test_of_returns_null_outside_a_group() -> void:
	# Given: A node with no group among its ancestors.
	# When: It looks for one.
	# Then: There is none, rather than an error.
	assert_null(KitHudGroup.of(_target))


func test_group_hides_when_hiding_is_turned_on_offscreen() -> void:
	# Given: A visible group whose entity is off-screen because hiding was off.
	var group := _layer.attach(_anchor)
	group.hide_offscreen = false
	_target.global_position = OFFSCREEN
	await wait_process_frames(2)
	assert_true(group.visible)
	# When: Hiding is turned back on.
	group.hide_offscreen = true
	# Then: It hides at once, rather than staying visible until the entity next crosses
	# the edge, which for a stationary entity is never.
	assert_false(group.visible)


func test_make_world_origin_holds_the_world_point_it_froze() -> void:
	# Given: A group whose entity sits at a known world position.
	_target.global_position = Vector2(100, 50)
	var group := _layer.attach(_anchor)
	# When: An origin is taken, and the entity then moves away.
	var origin := group.make_world_origin()
	_target.global_position = Vector2(300, 200)
	# Then: It still answers where the entity was, projected as it is now, which is what
	# keeps a floating number over the spot it came from.
	assert_true(origin.is_valid())
	assert_almost_eq(
		origin.call() as Vector2, _map.world_to_screen(Vector2(100, 50)), TOLERANCE
	)


func test_project_target_follows_the_entity() -> void:
	# Given: A group whose entity moves.
	var group := _layer.attach(_anchor)
	_target.global_position = Vector2(300, 200)
	# When: The target is projected.
	# Then: It answers the entity's live, unclamped position, which is what an arrow
	# pinned to the viewport edge points along.
	assert_almost_eq(
		group.project_target(), _map.world_to_screen(Vector2(300, 200)), TOLERANCE
	)


func test_group_without_a_tracker_warns_in_the_editor() -> void:
	# Given: A group scene authored without a tracker.
	var group := KitHudGroup.new()
	# When: The editor asks it for configuration warnings.
	var warnings: PackedStringArray = group._get_configuration_warnings()
	# Then: It names the missing tracker, since nothing at runtime would say so.
	assert_true("Missing property: 'tracker'" in warnings)

	group.free()


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
