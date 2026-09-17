##
## KitHudBarStyle carries a `KitHudBar`'s timing and behavior, so a game tunes how bars
## feel by editing a resource rather than a script, and shares one setting across every
## entity that uses it.
##
## Colors, fonts and box art are *not* here. Those are theme type variations - `hud_bar`
## and `hud_bar_ghost` in the game's theme - because the theme system already
## expresses them. This resource carries only what a theme cannot: timing and motion.
##

class_name KitHudBarStyle
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## drain animates the ghost bar down to a newly lowered value. Its `delay` is how long
## the ghost holds at the old value first, which is what reads as the damage taken.
@export var drain: StdTweenCurve = null

## hide_at_full hides the bar while the value is at its maximum, to keep undamaged
## entities uncluttered.
@export var hide_at_full: bool = false
