##
## system/setting/audio/mute/background_observer.gd
##
## BackgroundPropertyObserver is a `StdSettingsObserver` that handles muting the game,
## both globally and in the background.
##
## NOTE: The global audio output bus name is fixed to "Master". Because this observer
## handles global audio mutes, there's no need to customize which bus this observer
## operates on.
##

extends StdSettingsObserver

# -- DEFINITIONS --------------------------------------------------------------------- #

const BUS_NAME := &"Master"

# -- CONFIGURATION ------------------------------------------------------------------- #

## background_property is a `StdSettingsPropertyBool` defining the mute-in-background
## property to observe.
@export var background_property: StdSettingsPropertyBool = null

## global_property is a `StdSettingsPropertyBool` defining the global mute property to
## observe.
@export var global_property: StdSettingsPropertyBool = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_out: bool = false
var _logger := StdLogger.create(&"system/setting/audio-mute")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


# NOTE: Some operating systems may produce 'NOTIFICATION_APPLICATION_FOCUS_OUT'
# multiple times on the same focus loss event. As a result, the handler must be
# idempotent.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if not _is_out:
				return

			_is_out = false

			if not global_property.get_value():
				_logger.debug("Unmuting sound.")

				AudioServer.set_bus_mute(_get_audio_bus_index(), false)

		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _is_out:
				return

			_is_out = true

			if background_property.get_value():
				_logger.debug("Muting sound in background.")

				AudioServer.set_bus_mute(_get_audio_bus_index(), true)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(
		background_property is StdSettingsPropertyBool,
		"invalid config: missing property"
	)
	assert(
		global_property is StdSettingsPropertyBool, "invalid config: missing property"
	)

	return [background_property, global_property]


func _handle_value_change(property: StdSettingsProperty, value: bool) -> void:
	if property == background_property:
		_logger.debug("Updating background mute state.", {&"state": value})

		# If currently in the background and there isn't a global mute overriding this
		# setting, then update the current mute status.
		if _is_out and not global_property.get_value():
			AudioServer.set_bus_mute(_get_audio_bus_index(), value)

	elif property == global_property:
		_logger.debug("Setting global mute state.", {&"state": value})

		if not _is_out:
			AudioServer.set_bus_mute(_get_audio_bus_index(), value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_audio_bus_index() -> int:
	var index := AudioServer.get_bus_index(BUS_NAME)
	assert(index > -1, "invalid state; missing bus")

	return index
