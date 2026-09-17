##
## KitWorldTracker2D drives its parent `Control` to follow a `Node2D` living inside a
## `KitMap2D`'s `SubViewport` (e.g. health bars, damage numbers, name plates,
## tooltips, off-screen indicators). See `KitWorldTracker` for the tracking behavior.
##
## Expected scene layout:
##
##   KitMap2D                            (referenced via the `map` export)
##   ├── SubViewportContainer
##   │   └── SubViewport
##   │       └── ... game world ...
##   │           └── Node2D                  (target)
##   └── UI                                  (later subtree than SubViewport)
##       └── HealthBar / KitTooltip / etc.      (Control; tracker's parent)
##           └── KitWorldTracker2D
##

class_name KitWorldTracker2D
extends KitWorldTracker

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `KitMap2D` whose `SubViewport` hosts `target`.
@export var map: KitMap2D = null

## target is the `Node2D` the host follows; it must live inside `map.sub_viewport`.
## Reassigning it at runtime re-arms a stopped tracker.
@export var target: Node2D = null:
	set(value):
		target = value
		# Re-arm processing; `_process` disables itself once `target`/`map` go invalid.
		if is_instance_valid(value):
			set_process(true)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_map() -> KitMap:
	return map


func _get_target() -> Node:
	return target


func _project_target() -> Vector2:
	return map.world_to_screen(target.global_position)
