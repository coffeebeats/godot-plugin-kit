##
## KitHudLayer2D is the HUD plane for a `KitMap2D`. See `KitHudLayer` for the behavior;
## this supplies the 2D-typed map and the tracker wiring that goes with it.
##

@tool
class_name KitHudLayer2D
extends KitHudLayer

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `KitMap2D` this layer draws over.
@export var map: KitMap2D = null

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func project_world(world_position: Variant) -> Vector2:
	if not map:
		return Vector2.INF

	var p: Vector2 = world_position
	return map.world_to_screen(p)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not map:
		warnings.append("Missing property: 'map'")

	return warnings


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _configure_tracker(tracker: KitWorldTracker, anchor: KitHudAnchor) -> void:
	var tracker_2d := tracker as KitWorldTracker2D
	assert(tracker_2d, "invalid config; group tracker must be a 'KitWorldTracker2D'")
	if not tracker_2d:
		return

	var target := anchor.get_target() as Node2D
	assert(target, "invalid config; anchor has no 'Node2D' target")

	tracker_2d.map = map
	tracker_2d.target = target


func _get_map() -> KitMap:
	return map
