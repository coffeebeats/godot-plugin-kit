##
## KitHudNumbers spawns floating combat numbers. It owns every decision about them:
## where they start, how they arc, how they fade and when they are freed. The HUD layer
## neither knows nor routes any of it; a game calls this element directly.
##
##     _hud.damage.pop(12.0)
##     _hud.crit.pop(40.0)
##
## Those are two instances of this element in one group, each with its own style, which
## is why "critical" is configuration rather than a branch in the code.
##
## Numbers are parented to the layer rather than to the group, so they stay where they
## were spawned instead of following the entity that produced them.
##

class_name KitHudNumbers
extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const NUMBER := preload("number.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

## style carries the motion, timing and theme variation of the numbers this element
## spawns.
@export var style: KitHudNumberStyle = null

## number_scene overrides the scene spawned per number. It must have a `KitHudNumber`
## root.
@export var number_scene: PackedScene = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## pop spawns one floating number showing `value`.
##
## NOTE: There is no pool. A prototype spawning more than about twenty per second is the
## trigger to add one.
func pop(value: float) -> void:
	assert(style, "invalid config; missing 'style'")
	if not style:
		return

	var layer := KitHudLayer.of(self)
	assert(layer, "invalid state; no HUD layer found")
	if not layer:
		return

	var scene: PackedScene = number_scene if number_scene else NUMBER
	var number := scene.instantiate() as KitHudNumber
	assert(number, "invalid config; 'number_scene' root must be a 'KitHudNumber'")
	if not number:
		return

	layer.add_child(number)
	number.play(value, style, _make_origin())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_origin returns a callable giving the screen position a number drifts from.
##
## Inside a group it freezes the entity's *world* position and re-projects it, so the
## number holds its place in the world while the camera pans. Standing alone, with no
## group to ask, it freezes the current screen position instead.
func _make_origin() -> Callable:
	var group := KitHudGroup.of(self)
	var origin := group.make_world_origin() if group else Callable()

	if origin.is_valid():
		return origin

	var frozen := global_position
	return func() -> Vector2: return frozen
