##
## Unit tests for `KitWorldTracker3D` — verifies its `Node3D` projection drives the host
## via `KitMap3D.world_to_screen`, including behind-camera handling. Shared tracking
## behavior is covered by `world_tracker_test.gd`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _camera: Camera3D = null
var _container: SubViewportContainer = null
var _host: Control = null
var _map: KitMap3D = null
var _root: Control = null
var _target: Node3D = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_positions_host_at_projection() -> void:
	# Given: A target at world origin, on the camera's optical axis.
	_target.global_position = Vector3.ZERO
	_attach_tracker(_host)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host sits at the 3D projection of the target.
	assert_eq(_host.global_position, _map.world_to_screen(_target.global_position))


func test_follows_target_movement() -> void:
	# Given: A tracker following a target at world origin.
	_target.global_position = Vector3.ZERO
	_attach_tracker(_host)
	await wait_process_frames(1)
	var before := _host.global_position
	# When: The target moves along world X.
	_target.global_position = Vector3(1, 0, 0)
	await wait_process_frames(1)
	# Then: The host moves to a different finite position.
	assert_ne(_host.global_position, before)
	assert_true(_host.global_position.is_finite())


func test_no_op_when_behind_camera() -> void:
	# Given: A tracker following a target in front of the camera.
	_target.global_position = Vector3.ZERO
	_attach_tracker(_host)
	await wait_process_frames(1)
	var last := _host.global_position
	# When: The target moves behind the camera.
	_target.global_position = Vector3(0, 0, 10)
	await wait_process_frames(1)
	# Then: The host stays put — a behind-camera target has no projection.
	assert_eq(_host.global_position, last)


func test_clamped_host_pins_to_edge_when_behind_camera() -> void:
	# Given: A clamped tracker and a target behind the camera, to the left.
	_target.global_position = Vector3(-100, 0, 10)
	var tracker := _attach_tracker(_host)
	tracker.clamped = true
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host pins to the left edge at (0, 180), not freezing.
	assert_eq(_host.global_position, Vector2(0, 180))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920, 1080)
	add_child_autofree(_root)

	_map = partial_double(KitMap3D).new()
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

	_camera = Camera3D.new()
	_camera.current = true
	_viewport.add_child(_camera)
	_camera.global_transform = Transform3D(Basis(), Vector3(0, 0, 5))

	_target = Node3D.new()
	_viewport.add_child(_target)

	_map.sub_viewport = _viewport

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.add_child(_ui)

	_host = Control.new()
	_ui.add_child(_host)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _attach_tracker(parent: Node) -> KitWorldTracker3D:
	var tracker := KitWorldTracker3D.new()
	tracker.map = _map
	tracker.target = _target
	parent.add_child(tracker)
	return tracker
