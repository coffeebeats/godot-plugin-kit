##
## KitHudLayer3D is the HUD plane for a `KitMap3D`. See `KitHudLayer` for the behavior;
## this supplies the 3D-typed map and the tracker wiring that goes with it.
##

@tool
class_name KitHudLayer3D
extends KitHudLayer

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `KitMap3D` this layer draws over.
@export var map: KitMap3D = null

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func project_world(world_position: Variant) -> Vector2:
	if not map:
		return Vector2.INF

	var p: Vector3 = world_position
	return map.world_to_screen(p)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not map:
		warnings.append("Missing property: 'map'")

	return warnings


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _configure_tracker(tracker: KitWorldTracker, anchor: KitHudAnchor) -> void:
	var tracker_3d := tracker as KitWorldTracker3D
	assert(tracker_3d, "invalid config; group tracker must be a 'KitWorldTracker3D'")
	if not tracker_3d:
		return

	var target := anchor.get_target() as Node3D
	assert(target, "invalid config; anchor has no 'Node3D' target")

	tracker_3d.map = map
	tracker_3d.target = target


func _get_map() -> KitMap:
	return map
