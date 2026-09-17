##
## KitAnimationFade specifies a fade animation that can be applied to canvas elements.
## Note that this resource can be used for both fade in or fade out animations.
##

class_name KitAnimationFade
extends StdTweenCurve

# -- CONFIGURATION ------------------------------------------------------------------- #

## value is the target alpha for the animation.
@export_range(0.0, 1.0) var value: float = 1.0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## apply_tween_property configures a fade animation on the specified `target` node using
## the provided `tween` instance. Set `parallel` to true to have this operation run in
## parallel with other tween properties on the instance.
func apply_tween_property(
	tween: Tween,
	target: CanvasItem,
	parallel: bool = true,
) -> void:
	if parallel:
		tween.parallel()

	tween_property(tween, target, ^"modulate:a", value)
