##
## Base scene for standard 2D games. Renders the game world in a `SubViewport` at native
## resolution with linear filtering.
##

@tool
class_name KitMap2D
extends KitMap

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## world_to_screen projects a 2D world position to screen-space coordinates. Must
## be called from `_process` (before `frame_pre_draw`) and from a tree position
## greater than `sub_viewport`; otherwise the read of `canvas_transform` is one
## frame stale.
func world_to_screen(p: Vector2) -> Vector2:
	p = (sub_viewport.canvas_transform * p) if sub_viewport else p
	return viewport_to_screen(p)
