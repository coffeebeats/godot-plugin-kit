##
## A `StdSettingsObserver` which applies the 3D render scale and MSAA quality to a
## `SubViewport`.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## sub_viewport is the `SubViewport` to apply rendering settings to.
@export var sub_viewport: SubViewport = null

@export_group("Properties")

## render_scale_property controls the 3D rendering resolution as a fraction of the
## viewport size (e.g. 0.75 = 75% resolution).
@export var render_scale_property: StdSettingsPropertyFloat = null

## msaa_3d_property controls the multisample anti-aliasing quality for 3D rendering.
## Values map to `Viewport.MSAA` enum: 0=Disabled, 1=2x, 2=4x, 3=8x.
@export var msaa_3d_property: StdSettingsPropertyInt = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	var properties: Array[StdSettingsProperty] = []

	if render_scale_property:
		properties.append(render_scale_property)
	if msaa_3d_property:
		properties.append(msaa_3d_property)

	return properties


func _handle_value_change(property: StdSettingsProperty, value: Variant) -> void:
	if not sub_viewport:
		return

	if property == render_scale_property:
		sub_viewport.scaling_3d_scale = value
	elif property == msaa_3d_property:
		sub_viewport.msaa_3d = value as Viewport.MSAA
