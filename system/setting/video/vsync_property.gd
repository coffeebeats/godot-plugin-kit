##
## system/setting/property/video/vsync_property.gd
##
## VsyncModeProperty is a boolean settings property that stores configuration values
## as an integer `VSyncMode`.
##

extends StdSettingsPropertyBool

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	var mode := config.get_int(category, name, _get_vsync_mode(default))

	return mode == DisplayServer.VSYNC_ADAPTIVE


func _set_value_on_config(config: Config, value: bool) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_int(category, name, _get_vsync_mode(value))


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_vsync_mode(value: bool) -> DisplayServer.VSyncMode:
	return DisplayServer.VSYNC_ADAPTIVE if value else DisplayServer.VSYNC_DISABLED
