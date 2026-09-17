##
## KitFeelLayer2D is the feel layer for a `KitMap2D`. See `KitFeelLayer` for the
## behavior; this supplies the 2D camera and the offset it owns.
##

@tool
class_name KitFeelLayer2D
extends KitFeelLayer

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `KitMap2D` this layer draws over.
@export var map: KitMap2D = null

## camera is the camera to disturb. When unset the `SubViewport`'s active camera is
## used, which is the common case; set it to aim feel at a dedicated shake pivot.
@export var camera: Camera2D = null

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
	return target.offset if target else Vector2.ZERO


func _read_roll() -> float:
	var target := _resolve_camera()
	return target.rotation if target else 0.0


func _write_offset(offset: Vector2, roll: float) -> void:
	var target := _resolve_camera()
	if not target:
		return

	target.offset = offset

	# NOTE: Only written when a config asked for roll. `Camera2D.ignore_rotation`
	# defaults to true, so this does nothing until a prototype turns that off, and
	# writing it unasked would fight a camera that rotates itself.
	if _owns_roll:
		target.rotation = roll


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _resolve_camera returns the camera to disturb: the export when set, and the
## `SubViewport`'s active camera otherwise.
func _resolve_camera() -> Camera2D:
	if camera and is_instance_valid(camera):
		return camera

	if not map or not map.sub_viewport:
		return null

	return map.sub_viewport.get_camera_2d()
