##
## KitHudAnchor2D binds a `Node2D` entity to a HUD group. See `KitHudAnchor` for the
## behavior; this adds the 2D-typed target.
##
## Expected scene layout:
##
##   Enemy                    (Node2D, inside a KitMap2D's SubViewport)
##   └── KitHudAnchor2D          group_scene = enemy_hud.tscn
##

@tool
class_name KitHudAnchor2D
extends KitHudAnchor

# -- CONFIGURATION ------------------------------------------------------------------- #

## target is the `Node2D` the group follows. When unset the anchor's parent is used,
## which is the common case; set it to follow a `Marker2D` offset from the entity.
@export var target: Node2D = null

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func get_world_position() -> Variant:
	var node := get_target() as Node2D
	if not node:
		return null

	return node.global_position


func get_target() -> Node:
	return target if target else get_parent() as Node2D
