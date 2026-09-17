##
## KitHudBar shows a value against a maximum, with a trailing "ghost" bar that holds at
## the previous value and then drains, which is what makes a hit read as damage taken
## rather than as a number changing.
##
## It owns everything about that behavior. The HUD layer neither knows nor routes it,
## since a game calls `set_value` on the bar itself.
##
##     _hud.health.set_value(health, max_health)
##
## Timing comes from its `KitHudBarStyle`; colors come from the `hud_bar` and
## `hud_bar_ghost` theme type variations.
##

class_name KitHudBar
extends Control

# -- CONFIGURATION ------------------------------------------------------------------- #

## style carries the drain timing and the hide-at-full behavior. Without one the ghost
## snaps instead of draining, which is a usable default rather than an error.
@export var style: KitHudBarStyle = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _drain: Tween = null
var _max_value: float = 1.0

# NOTE: Full, not empty. A bar mounted for an entity that has not been damaged yet is
# never told a value, and an empty bar reads as a dead entity rather than a healthy one.
var _value: float = 1.0

@onready var _fill: ProgressBar = $Fill
@onready var _ghost: ProgressBar = $Ghost

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_value returns the value last set.
func get_value() -> float:
	return _value


## get_max_value returns the maximum last set.
func get_max_value() -> float:
	return _max_value


## set_value updates the bar. The fill moves at once; a decrease leaves the ghost behind
## to hold and then drain, and an increase snaps both.
##
## NOTE: Safe to call before the bar is ready; the value is applied when it is.
func set_value(value: float, max_value: float) -> void:
	assert(max_value > 0.0, "invalid argument: 'max_value' must be positive")
	if max_value <= 0.0:
		return

	var previous := _value

	_max_value = max_value
	_value = clampf(value, 0.0, max_value)

	if is_node_ready():
		_apply(previous)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	# NOTE: No trailing ghost on the first paint, so a bar that starts damaged does not
	# animate down from full the moment it appears.
	_apply(_value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _apply pushes the current value into both bars, starting or stopping the ghost drain
## against the value held before this update.
func _apply(previous: float) -> void:
	_fill.max_value = _max_value
	_fill.value = _value
	_ghost.max_value = _max_value

	if _value >= previous or _ghost.value <= _value:
		# Gained, unchanged, or the ghost has already drained past this value, so nothing
		# trails.
		_stop_drain()
		_ghost.value = _value
	else:
		# A loss leaves the ghost where it is and drains it from there, so repeated hits
		# extend one trail rather than restarting it from full.
		_start_drain()

	_update_visibility()


func _start_drain() -> void:
	_stop_drain()

	var curve := style.drain if style else null
	if not curve:
		_ghost.value = _value
		return

	_drain = create_tween()
	curve.tween_property(_drain, _ghost, ^"value", _value)


func _stop_drain() -> void:
	if _drain and _drain.is_valid():
		_drain.kill()

	_drain = null


func _update_visibility() -> void:
	var hide_at_full := style.hide_at_full if style else false
	visible = not (hide_at_full and _value >= _max_value)
