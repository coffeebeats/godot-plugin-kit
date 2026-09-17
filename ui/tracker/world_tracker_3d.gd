##
## KitWorldTracker3D drives its parent `Control` to follow a `Node3D` living inside a
## `KitMap3D`'s `SubViewport` (e.g. health bars, damage numbers, name plates,
## tooltips, off-screen indicators). See `KitWorldTracker` for the tracking behavior.
##
## Off-screen includes positions behind the camera; `target_exited_view` fires when the
## target passes a viewport edge or moves behind the camera.
##
## Expected scene layout:
##
##   KitMap3D                            (referenced via the `map` export)
##   ├── SubViewportContainer
##   │   └── SubViewport
##   │       ├── Camera3D
##   │       └── ... game world ...
##   │           └── Node3D                  (target)
##   └── UI                                  (later subtree than SubViewport)
##       └── HealthBar / KitTooltip / etc.      (Control; tracker's parent)
##           └── KitWorldTracker3D
##

class_name KitWorldTracker3D
extends KitWorldTracker

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `KitMap3D` whose `SubViewport` hosts `target`.
@export var map: KitMap3D = null

## target is the `Node3D` the host follows; it must live inside `map.sub_viewport`.
## Reassigning it at runtime re-arms a stopped tracker.
@export var target: Node3D = null:
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


func _offscreen_direction(screen_position: Vector2, center: Vector2) -> Vector2:
	if screen_position.is_finite():
		return screen_position - center
	return map.world_to_screen_direction(target.global_position)


func _project_target() -> Vector2:
	return map.world_to_screen(target.global_position)
