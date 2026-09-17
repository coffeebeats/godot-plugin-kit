##
## Unit tests for `KitMap3D`'s screen-projection methods — `world_to_screen` and
## `world_to_screen_direction`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TOLERANCE := Vector2(1.0, 1.0)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _map: KitMap3D = null
var _container: SubViewportContainer = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_in_front_returns_finite() -> void:
	# Given: A camera at (0, 0, 5) looking at the origin.
	_install_camera(Vector3(0, 0, 5))
	# When: The world origin is projected.
	var screen := _map.world_to_screen(Vector3.ZERO)
	# Then: The result is finite (i.e. not the INF sentinel).
	assert_true(screen.is_finite(), "expected finite screen position; got %s" % screen)


func test_centered_camera_projects_origin_to_viewport_center() -> void:
	# Given: A camera at (0, 0, 5) looking at the origin (default rotation -> -Z).
	_install_camera(Vector3(0, 0, 5))
	# When: The world origin is projected.
	var screen := _map.world_to_screen(Vector3.ZERO)
	# Then: The result is the viewport center. Catches sign flips and axis swaps
	# that `is_finite()` alone misses.
	var center := Vector2(_viewport.size) / 2.0
	assert_almost_eq(screen, center, TOLERANCE)


func test_behind_camera_returns_inf() -> void:
	# Given: A camera at (0, 0, 5) looking down -Z.
	_install_camera(Vector3(0, 0, 5))
	# When: A position behind the camera (further +Z) is projected.
	var screen := _map.world_to_screen(Vector3(0, 0, 10))
	# Then: The result is `Vector2.INF`.
	assert_false(screen.is_finite(), "expected INF for behind-camera position")


func test_no_camera_returns_inf() -> void:
	# Given: A SubViewport with no Camera3D.
	# When: A world position is projected.
	var screen := _map.world_to_screen(Vector3.ZERO)
	# Then: The result is `Vector2.INF`.
	assert_false(screen.is_finite(), "expected INF when no camera is active")


func test_no_subviewport_returns_inf() -> void:
	# Given: A map with no SubViewport reference.
	_map.sub_viewport = null
	# When: A world position is projected.
	var screen := _map.world_to_screen(Vector3.ZERO)
	# Then: The result is `Vector2.INF`.
	assert_false(screen.is_finite(), "expected INF when sub_viewport is null")


func test_explicit_camera_arg_used() -> void:
	# Given: An active camera at (0, 0, 5) AND a non-active camera at (10, 0, 5).
	var active := _install_camera(Vector3(0, 0, 5))
	var explicit := Camera3D.new()
	explicit.current = false
	_viewport.add_child(explicit)
	explicit.global_transform = Transform3D(Basis(), Vector3(10, 0, 5))
	# When: The world origin is projected through the explicit camera.
	var screen_explicit := _map.world_to_screen(Vector3.ZERO, explicit)
	# And: Through the active camera.
	var screen_active := _map.world_to_screen(Vector3.ZERO, active)
	# Then: Both are finite, and the explicit-camera projection differs (camera offset
	# shifts the projected x-coordinate).
	assert_true(screen_explicit.is_finite())
	assert_true(screen_active.is_finite())
	assert_ne(
		screen_explicit.x,
		screen_active.x,
		"explicit camera should produce a different x"
	)


func test_off_frustum_returns_finite() -> void:
	# Given: A camera at (0, 0, 5) looking at the origin.
	_install_camera(Vector3(0, 0, 5))
	# When: A point well above the frustum (but still in front of the camera) is
	# projected. Tests the documented contract that off-screen-indicator widgets get
	# finite (clampable) coords rather than INF.
	var screen := _map.world_to_screen(Vector3(0, 1000, 0))
	# Then: The result is finite (off-screen, but not INF).
	assert_true(
		screen.is_finite(), "off-frustum-but-in-front should be finite; got %s" % screen
	)


func test_world_to_screen_direction_points_at_in_front_target() -> void:
	# Given: A camera at (0, 0, 5) and a target to its right, level with it.
	_install_camera(Vector3(0, 0, 5))
	# When: The screen-space direction toward the target is computed.
	var direction := _map.world_to_screen_direction(Vector3(100, 0, 0))
	# Then: It points straight right (the target shares the camera's height).
	assert_eq(direction, Vector2.RIGHT)


func test_world_to_screen_direction_points_at_behind_camera_target() -> void:
	# Given: A camera at (0, 0, 5) and a target behind it, to the right.
	_install_camera(Vector3(0, 0, 5))
	# When: The direction toward the behind-camera target is computed.
	var direction := _map.world_to_screen_direction(Vector3(100, 0, 10))
	# Then: It still resolves to a usable rightward bearing, not INF or ZERO.
	assert_eq(direction, Vector2.RIGHT)


func test_world_to_screen_direction_no_camera_returns_zero() -> void:
	# Given: A SubViewport with no Camera3D.
	# When: A screen-space direction is requested.
	var direction := _map.world_to_screen_direction(Vector3(100, 0, 0))
	# Then: The result is the `Vector2.ZERO` sentinel.
	assert_eq(direction, Vector2.ZERO)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	add_child_autofree(root)

	_map = partial_double(KitMap3D).new()
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


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _install_camera(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	camera.current = true
	_viewport.add_child(camera)
	camera.global_transform = Transform3D(Basis(), at)
	return camera
