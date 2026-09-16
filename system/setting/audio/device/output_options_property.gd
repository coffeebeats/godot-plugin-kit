##
## system/setting/audio/device/output_options_property.gd
##
## StdSettingsPropertyAudioDeviceOptions is a read-only settings property that
## provides a list of sound device options based on connected devices.
##

extends StdSettingsPropertyStringList

# -- CONFIGURATION ------------------------------------------------------------------- #

## include_input_devices controls whether input sound devices are included.
@export var include_input_devices: bool = false

## include_output_devices controls whether output sound devices are included.
@export var include_output_devices: bool = true

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _can_modify() -> bool:
	return false


func _get_value_from_config(_config: Config) -> Variant:
	var devices := PackedStringArray()

	if include_input_devices:
		devices.append_array(AudioServer.get_input_device_list())
	if include_output_devices:
		devices.append_array(AudioServer.get_output_device_list())

	return devices
