##
## KitAnimationBorderFade specifies a fade animation that can be applied to
## `StyleboxFlat` resources. Note that this resource can be used for both fade in or
## fade out animations.
##

class_name KitAnimationBorderFade
extends StdTweenCurve

# -- CONFIGURATION ------------------------------------------------------------------- #

## color is the target color for the animation.
@export var color: Color = Color.TRANSPARENT

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## apply_tween_property configures a border fade animation on the specified `target`
## node using the provided `tween` instance. Set `parallel` to true to have this
## operation run in parallel with other tween properties on the instance.
func apply_tween_property(
	tween: Tween,
	target: StyleBoxFlat,
	parallel: bool = true,
) -> void:
	if parallel:
		tween.parallel()

	tween_property(tween, target, ^"border_color", color)
