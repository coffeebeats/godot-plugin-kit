##
## Base scene for 3D games. Renders the game world in a `SubViewport` with Forward+
## rendering. Settings observers on the scene apply render quality and anti-aliasing
## configuration to the viewport.
##

@tool
class_name KitMap3D
extends KitMap

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## world_to_screen projects a 3D world position to screen-space coordinates, using
## `camera` or `sub_viewport`'s active `Camera3D` if `camera` is null. Returns
## `Vector2.INF` when no camera is available or `p` is behind it; off-frustum
## positions in front of the camera still project to finite, clampable coords — by
## design, for off-screen indicators.
func world_to_screen(
	p: Vector3,
	camera: Camera3D = null,
) -> Vector2:
	if not sub_viewport:
		return Vector2.INF

	if not camera:
		camera = sub_viewport.get_camera_3d()
	if not camera:
		return Vector2.INF

	assert(
		sub_viewport.is_ancestor_of(camera),
		"'camera' must be a descendant of 'sub_viewport'"
	)

	if camera.is_position_behind(p):
		return Vector2.INF

	return viewport_to_screen(camera.unproject_position(p))


## world_to_screen_direction returns a unit screen-space direction from the viewport
## center toward `p`, valid even when `p` is behind the camera. Returns `Vector2.ZERO`
## when no camera is available or `p` lies on the camera's optical axis.
func world_to_screen_direction(p: Vector3, camera: Camera3D = null) -> Vector2:
	if not sub_viewport:
		return Vector2.ZERO

	if not camera:
		camera = sub_viewport.get_camera_3d()
	if not camera:
		return Vector2.ZERO

	assert(
		sub_viewport.is_ancestor_of(camera),
		"'camera' must be a descendant of 'sub_viewport'"
	)

	# Mirror points behind the camera to the front: a behind-camera position has no
	# projection, but its front mirror shares the same screen bearing from center.
	var local := camera.global_transform.affine_inverse() * p
	if local.z > 0.0:
		local.z = -local.z

	var mirrored := camera.global_transform * local
	var center := viewport_to_screen(Vector2(sub_viewport.size) / 2.0)
	var screen_position := viewport_to_screen(camera.unproject_position(mirrored))
	return (screen_position - center).normalized()
