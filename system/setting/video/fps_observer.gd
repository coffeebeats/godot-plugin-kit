##
## FpsObserver is a `StdSettingsObserver` that handles updating frame limit-related
## settings like Vsync and frame limit caps.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## vsync_property is a `StdSettingsPropertyBool` defining the vsync property to observe.
@export var vsync_property: StdSettingsPropertyBool = null

## frame_limit_property is a `StdSettingsPropertyFloat` defining the maximum frame limit
## property to observe.
@export var frame_limit_property: StdSettingsPropertyFloat = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(
		vsync_property is StdSettingsPropertyBool, "invalid config: missing property"
	)
	assert(
		frame_limit_property is StdSettingsPropertyFloat,
		"invalid config: missing property"
	)

	return [vsync_property, frame_limit_property]


func _handle_value_change(property: StdSettingsProperty, value: Variant) -> void:
	if property == vsync_property:
		if KitFeature.is_web_platform():
			return  # VSync is not supported on the Web platform.

		var current_mode := DisplayServer.window_get_vsync_mode()

		if value and current_mode != DisplayServer.VSYNC_ADAPTIVE:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		elif not value and current_mode != DisplayServer.VSYNC_DISABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	elif property == frame_limit_property:
		Engine.max_fps = value
