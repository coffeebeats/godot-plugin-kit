##
## system/setting/audio/volume/observer.gd
##
## VolumeObserver is a `StdSettingsObserver` that applies the volume changes configured
## within a settings scope.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## bus is the name of the audio bus to modify. This should correspond to the property
## being observed.
@export var bus: StringName = ""

## property is a `StdSettingsPropertyFloatRange` defining the volume property to
## observe. Note that the value should be a linear value, not exponential (e.g. dB).
@export var property: StdSettingsPropertyFloatRange = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"system/setting/audio-volume")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [property]


func _handle_value_change(_property: StdSettingsProperty, value: float) -> void:
	assert(_property == property, "invalid argument: wrong property")

	var bus_index := AudioServer.get_bus_index(bus)
	assert(bus_index != -1, "invalid config: missing audio bus")
	if bus_index == -1:
		return  # Bus is not added; nothing to do.

	var volume := linear_to_db(
		clampf((value - property.minimum) / (property.maximum - property.minimum), 0, 1)
	)

	AudioServer.set_bus_volume_db(bus_index, volume)

	(
		_logger
		. debug(
			"Adjusted audio bus volume.",
			{&"bus": bus, &"volume": AudioServer.get_bus_volume_db(bus_index)},
		)
	)
