##
## Unit tests for `KitWorldTracker2D` — verifies its `Node2D` projection drives the host
## via `KitMap2D.world_to_screen`, including camera-pan tracking. Shared tracking
## behavior is covered by `world_tracker_test.gd`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _container: SubViewportContainer = null
var _host: Control = null
var _map: KitMap2D = null
var _root: Control = null
var _target: Node2D = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_positions_host_at_projection() -> void:
	# Given: A target at world (10, 20).
	_target.global_position = Vector2(10, 20)
	_attach_tracker(_host)

	# When: A frame is processed.
	await wait_process_frames(1)

	# Then: The host sits at the 2D projection of the target.
	assert_eq(_host.global_position, _map.world_to_screen(_target.global_position))


func test_follows_target_movement() -> void:
	# Given: A tracker following a target at (50, 50).
	_target.global_position = Vector2(50, 50)
	_attach_tracker(_host)
	await wait_process_frames(1)
	var before := _host.global_position

	# When: The target moves by (20, 0).
	_target.global_position = Vector2(70, 50)
	await wait_process_frames(1)

	# Then: The host shifts by the same amount.
	assert_eq(_host.global_position - before, Vector2(20, 0))


func test_follows_camera_pan() -> void:
	# Given: A tracker following a target at (50, 50).
	_target.global_position = Vector2(50, 50)
	_attach_tracker(_host)
	await wait_process_frames(1)
	var before := _host.global_position

	# When: The canvas_transform shifts, simulating a camera pan.
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-30, 0))
	await wait_process_frames(1)

	# Then: The host shifts by the same amount.
	assert_eq(_host.global_position - before, Vector2(-30, 0))


# -- TEST HOOKS ---------------------------------------------------------------------- #


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

	_target = Node2D.new()
	_viewport.add_child(_target)

	_map.sub_viewport = _viewport

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.add_child(_ui)

	_host = Control.new()
	_ui.add_child(_host)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _attach_tracker(parent: Node) -> KitWorldTracker2D:
	var tracker := KitWorldTracker2D.new()
	tracker.map = _map
	tracker.target = _target
	parent.add_child(tracker)
	return tracker
