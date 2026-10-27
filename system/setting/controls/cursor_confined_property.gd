##
## CursorConfinedProperty is a boolean settings property deciding whether the cursor is
## confined to the window. Until the player sets it, it takes `fullscreen`'s value, so
## the cursor is confined in fullscreen and free to leave a window, which players
## typing on an on-screen keyboard need.
##

extends StdSettingsPropertyBool

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## fullscreen is the property whose value this one takes until the player sets it.
@export var fullscreen: StdSettingsPropertyBool = null:
	set(value):
		if fullscreen:
			Signals.disconnect_safe(fullscreen.value_changed, _on_fullscreen_changed)

		fullscreen = value

		if value:
			Signals.connect_safe(value.value_changed, _on_fullscreen_changed)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	return config.get_bool(
		category, name, fullscreen.get_value() if fullscreen else default
	)


func _set_value_on_config(config: Config, value: bool) -> bool:
	# NOTE: The player's choice is stored even when it matches the window mode, so it
	# holds once the mode changes.
	return config.set_bool(category, name, value)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_fullscreen_changed(_value: Variant) -> void:
	if not scope.config.has_bool(category, name):
		value_changed.emit(get_value())
