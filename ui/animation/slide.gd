##
## KitAnimationSlide specifies a slide animation that can be used to add motion to
## canvas elements.
##

class_name KitAnimationSlide
extends StdTweenCurve

# -- CONFIGURATION ------------------------------------------------------------------- #

## translation is the motion vector defining the slide animation.
##
## Here, the `x` value represents the primary axis (formed between the anchor's center
## and the tooltip's center), while the `y` value is the perpendicular axis. Values
## along the primary axis should be negative if they move towards the anchor and
## positive if they move away. Perpendicular axis values are applied directly (i.e. they
## aren't changed).
@export var translation: Vector2 = Vector2.ZERO

## use_global_position defines whether the animated node's `global_position` will be
## animated instead of its `position` property.
@export var use_global_position: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## apply_tween_property configures a slide animation on the specified `target` node
## using the provided `tween` instance. Set `parallel` to true to have this operation
## run in parallel with other tween properties on the instance.
func apply_tween_property(
	tween: Tween,
	target: CanvasItem,
	value: Vector2,
	parallel: bool = true,
) -> void:
	if parallel:
		tween.parallel()

	tween_property(
		tween,
		target,
		^"global_position" if use_global_position else ^"position",
		value,
	)
