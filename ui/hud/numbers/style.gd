##
## KitHudNumberStyle carries how a floating number moves and reads. It is what makes
## damage, a critical hit and a heal three instances of one element rather than three
## branches inside it: each `KitHudNumbers` in a group points at its own style, and the
## game picks which one to call.
##
## Colors and fonts are not here beyond naming a theme type variation, because the theme
## system already expresses them.
##

class_name KitHudNumberStyle
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## format is applied to the value to produce the text.
@export var format: String = "%d"

## theme_variation is the theme type variation the label uses, which is where its font
## and color live. See `hud_number` in the game's theme.
@export var theme_variation: StringName = &"hud_number"

@export_group("Motion")

## travel is how far, and in which direction, the number drifts over its life.
@export var travel: Vector2 = Vector2(0, -40)

## spread_degrees randomly rotates `travel` by up to half this angle either way, so a
## burst of numbers fans out instead of stacking into an unreadable column.
@export var spread_degrees: float = 40.0

## duration is how long the number lives, in seconds.
@export var duration: float = 0.7

## motion is the curve the drift follows. Without one the drift is linear.
@export var motion: StdTweenCurve = null

## fade is the curve the alpha follows. Without one the fade is linear over `duration`.
@export var fade: StdTweenCurve = null

## punch scales the number up by this fraction on spawn and settles it back, which is
## what makes a critical hit land harder than a bigger font alone would.
@export_range(0.0, 2.0, 0.05) var punch: float = 0.0
