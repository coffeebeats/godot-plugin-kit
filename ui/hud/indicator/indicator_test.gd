##
## Unit tests for `KitHudIndicator`: the arrow's bearing, and the visibility that pairs
## a clamped tracker with a group that does not hide.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GROUP_2D := preload("../group_2d.tscn")
const INDICATOR := preload("indicator.tscn")

## VIEWPORT_SIZE matches the fixture's SubViewport, whose screen rect is therefore
## (0, 0) to (640, 360) with a centre at (320, 180).
const VIEWPORT_SIZE := Vector2(640, 360)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _anchor: KitHudAnchor2D = null
var _container: SubViewportContainer = null
var _group: KitHudGroup = null
var _indicator: KitHudIndicator = null
var _layer: KitHudLayer2D = null
var _map: KitMap2D = null
var _root: Control = null
var _target: Node2D = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_arrow_points_toward_a_target_past_each_edge() -> void:
	# Given: A clamped group carrying an indicator.
	var centre := VIEWPORT_SIZE / 2.0

	# When: The target sits far past each edge in turn.
	# Then: The arrow's rotation is the bearing from the screen centre toward it, which
	# is exact because the tracker clamps the group along that same ray.
	var offsets: Array[Vector2] = [
		Vector2(5000, 0),
		Vector2(-5000, 0),
		Vector2(0, 5000),
		Vector2(0, -5000),
	]

	for offset in offsets:
		_target.global_position = centre + offset
		await wait_process_frames(2)

		var expected: float = offset.angle()
		assert_almost_eq(wrapf(_indicator.rotation - expected, -PI, PI), 0.0, 0.05)


func test_group_stays_visible_while_the_target_is_offscreen() -> void:
	# Given: An indicator group, which does not hide with its target.
	_target.global_position = Vector2(10000, 10000)
	# When: A frame is processed.
	await wait_process_frames(2)
	# Then: The group is still drawn, clamped to the edge, and the arrow with it.
	assert_true(_group.visible)
	assert_true(_indicator.visible)
	assert_false(_group.is_target_in_view)


func test_arrow_hides_while_the_target_is_in_view() -> void:
	# Given: An indicator group whose target is on screen.
	_target.global_position = Vector2(100, 100)
	# When: A frame is processed.
	await wait_process_frames(2)
	# Then: The arrow hides, since there is nothing to point at that cannot be seen.
	assert_true(_group.is_target_in_view)
	assert_false(_indicator.visible)


func test_arrow_keeps_its_pivot_centred_after_a_resize() -> void:
	# Given: An arrow at its authored size.
	assert_eq(_indicator.pivot_offset, _indicator.size / 2.0)
	# When: A game gives it a size of its own.
	_indicator.size = Vector2(40, 32)
	await wait_process_frames(1)
	# Then: The pivot has followed. `rotation` turns the arrow about this point, so a
	# stale pivot swings it around a corner and it no longer points where it says.
	assert_eq(_indicator.pivot_offset, Vector2(20, 16))


func test_group_is_clamped_within_the_screen_rect() -> void:
	# Given: A target far outside the viewport.
	_target.global_position = Vector2(10000, 0)
	# When: A frame is processed.
	await wait_process_frames(2)
	# Then: The group is pinned inside the screen rect rather than following the target
	# off into space.
	var screen_rect := _layer.get_screen_rect()
	assert_true(screen_rect.has_point(_group.get_global_rect().get_center()))


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
	_container.size = VIEWPORT_SIZE
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEWPORT_SIZE)
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

	# An indicator group is the mirror of a nameplate's: clamped to the viewport edge,
	# and staying visible while its entity cannot be seen.
	_group = _anchor.group
	_group.hide_offscreen = false
	_group.tracker.clamped = true
	_group.tracker.offset = Vector2.ZERO

	_indicator = INDICATOR.instantiate()
	_group.add_child(_indicator)
	_indicator.owner = _group

	# NOTE: The tracker insets the viewport edge by the host's half-extent, so a clamped
	# group must be sized to its content or it hangs off the edge.
	_group.size = _indicator.size
