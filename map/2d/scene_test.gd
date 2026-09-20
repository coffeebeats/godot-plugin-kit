##
## Unit tests for the `KitMap2D` projection methods that bridge SubViewport-local
## coordinates with screen-space coordinates.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TOLERANCE := Vector2(0.001, 0.001)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _map: KitMap2D = null
var _container: SubViewportContainer = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_world_to_screen_identity_default_transforms() -> void:
	# Given: Default transforms (no scale, position, or canvas offset).
	# When: A world position is projected.
	var screen := _map.world_to_screen(Vector2(10, 20))

	# Then: The screen position equals the world position.
	assert_almost_eq(screen, Vector2(10, 20), TOLERANCE)


func test_world_to_screen_with_container_position() -> void:
	# Given: The container is positioned at (100, 50).
	_container.position = Vector2(100, 50)

	# When: World origin is projected.
	var screen := _map.world_to_screen(Vector2.ZERO)

	# Then: Screen position reflects the container offset.
	assert_almost_eq(screen, Vector2(100, 50), TOLERANCE)


func test_world_to_screen_with_container_scale() -> void:
	# Given: The container is scaled (2, 2).
	_container.scale = Vector2(2, 2)

	# When: World (10, 5) is projected.
	var screen := _map.world_to_screen(Vector2(10, 5))

	# Then: Screen position is doubled in both axes.
	assert_almost_eq(screen, Vector2(20, 10), TOLERANCE)


func test_world_to_screen_with_canvas_transform() -> void:
	# Given: A camera-style canvas_transform offset.
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-50, -25))

	# When: World origin is projected.
	var screen := _map.world_to_screen(Vector2.ZERO)

	# Then: Screen reflects the canvas offset.
	assert_almost_eq(screen, Vector2(-50, -25), TOLERANCE)


func test_world_to_screen_combined_transforms() -> void:
	# Given: Non-trivial scale, container position, and canvas offset.
	_container.scale = Vector2(2, 3)
	_container.position = Vector2(100, 50)
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-10, -20))

	# When: World (5, 5) is projected.
	# Then: viewport = world + canvas_offset = (-5, -15);
	#       screen = container_pos + scale * viewport = (100 + 2*-5, 50 + 3*-15) = (90, 5).
	var screen := _map.world_to_screen(Vector2(5, 5))
	assert_almost_eq(screen, Vector2(90, 5), TOLERANCE)


func test_world_to_screen_stretch_with_shrink_2() -> void:
	# Given: A stretching container with `stretch_shrink = 2`. The container will
	# auto-resize the SubViewport to `container.size / 2` once the next frame ticks.
	_container.stretch = true
	_container.stretch_shrink = 2
	await wait_process_frames(1)

	# When: World (10, 5) is projected.
	var screen := _map.world_to_screen(Vector2(10, 5))

	# Then: Visual scale is 2x (640/320 = 2).
	assert_almost_eq(screen, Vector2(20, 10), TOLERANCE)


func test_world_to_screen_stretch_with_canvas_transform() -> void:
	# Given: A stretching container (shrink=2) AND a translated canvas_transform.
	_container.stretch = true
	_container.stretch_shrink = 2
	await wait_process_frames(1)
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-10, -20))

	# When: World (15, 25) is projected.
	# Then: viewport = (5, 5); visual scale = 2; screen = (10, 10).
	var screen := _map.world_to_screen(Vector2(15, 25))
	assert_almost_eq(screen, Vector2(10, 10), TOLERANCE)


func test_world_to_screen_stretch_with_container_scale() -> void:
	# Given: A stretching container (shrink=2) AND a container scale of 3x.
	_container.stretch = true
	_container.stretch_shrink = 2
	_container.scale = Vector2(3, 3)
	await wait_process_frames(1)

	# When: World (10, 5) is projected.
	# Then: visual scale = 2 (stretch); container scale = 3; total = 6.
	var screen := _map.world_to_screen(Vector2(10, 5))
	assert_almost_eq(screen, Vector2(60, 30), TOLERANCE)


func test_no_subviewport_passthrough() -> void:
	# Given: A map with no SubViewport.
	_map.sub_viewport = null

	# When: Bridge methods are called.
	var v := Vector2(42, 84)

	# Then: Input is returned unchanged.
	assert_almost_eq(_map.viewport_to_screen(v), v, TOLERANCE)
	assert_almost_eq(_map.world_to_screen(v), v, TOLERANCE)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	add_child_autofree(root)

	_map = partial_double(KitMap2D).new()
	stub(_map, "_ready").to_do_nothing()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)

	_map.sub_viewport = _viewport
