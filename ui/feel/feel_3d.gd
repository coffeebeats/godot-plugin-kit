##
## KitFeelLayer3D is the feel layer for a `KitMap3D`. See `KitFeelLayer` for the
## behavior; this supplies the 3D camera and the offset it owns.
##
## NOTE: `Camera3D.h_offset` and `v_offset` translate the camera along its own right and
## up axes, in metres. That makes them a camera-plane displacement, which is why the
## same `Vector2` API drives both dimensions rather than 3D needing one of its own. The
## vertical sign is flipped here, since screen down is world up.
##

@tool
class_name KitFeelLayer3D
extends KitFeelLayer

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `KitMap3D` this layer draws over.
@export var map: KitMap3D = null

## camera is the camera to disturb. When unset the `SubViewport`'s active camera is
## used, which is the common case; set it to aim feel at a dedicated shake pivot.
@export var camera: Camera3D = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not map:
		warnings.append("Missing property: 'map'")

	return warnings


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_map() -> KitMap:
	return map


func _read_offset() -> Vector2:
	var target := _resolve_camera()
	return Vector2(target.h_offset, -target.v_offset) if target else Vector2.ZERO


func _read_roll() -> float:
	var target := _resolve_camera()
	return target.rotation.z if target else 0.0


func _write_offset(offset: Vector2, roll: float) -> void:
	var target := _resolve_camera()
	if not target:
		return

	target.h_offset = offset.x
	target.v_offset = -offset.y

	# NOTE: Only written when a config asked for roll, since rolling the camera fights a
	# controller that writes its own transform.
	if _owns_roll:
		target.rotation.z = roll


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _resolve_camera returns the camera to disturb: the export when set, and the
## `SubViewport`'s active camera otherwise.
func _resolve_camera() -> Camera3D:
	if camera and is_instance_valid(camera):
		return camera

	if not map or not map.sub_viewport:
		return null

	return map.sub_viewport.get_camera_3d()
