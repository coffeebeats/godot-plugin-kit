##
## system/input/steam/observer.gd
##
## SteamInputObserver is a `StdSettingsObserver` which handles swapping out input device
## components based on changes to Steam Input. This node only handles a single input
## slot, so multiple may be required for local multiplayer support.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## slot is the player slot which will have its components swapped.
@export var slot: StdInputSlot = null

## steam_input_enabled_property is a settings property that tracks whether Steam Input
## is currently enabled.
@export var steam_input_enabled_property: StdSettingsPropertyBool = null

## Components are a group of properties related to `StdInputDevice` components for
## *joypad* devices.
@export_group("Components")

@export_subgroup("Godot")

@export var godot_joypad_monitor: StdInputSlot.JoypadMonitor = null

## godot_device_actions is the Godot-backed device actions component.
@export var godot_device_actions: StdInputDeviceActions = null

## godot_device_glyphs is the Godot-backed device glyphs component.
@export var godot_device_glyphs: StdInputDeviceGlyphs = null

## godot_device_haptics is the Godot-backed device haptics component.
@export var godot_device_haptics: StdInputDeviceHaptics = null

@export_subgroup("Steam")

@export var steam_joypad_monitor: StdInputSlot.JoypadMonitor = null

## steam_device_actions is the Steam-backed device actions component.
@export var steam_device_actions: StdInputDeviceActions = null

## steam_device_glyphs is the Steam-backed device glyphs component.
@export var steam_device_glyphs: StdInputDeviceGlyphs = null

## steam_device_haptics is the Steam-backed device haptics component.
@export var steam_device_haptics: StdInputDeviceHaptics = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create("system/input/steam/observer").with_process_frame()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [steam_input_enabled_property]


func _handle_value_change(property: StdSettingsProperty, value: bool) -> void:
	if not property == steam_input_enabled_property:
		assert(false, "invalid state; wrong property")
		return

	if not slot:
		assert(false, "invalid config; missing player slot")
		return

	_logger.debug(
		"Swapped device components for input slot.",
		{&"player": slot.player_id, &"storefront": "steam" if value else "unknown"}
	)

	(
		slot
		. swap_joypad_components(
			steam_joypad_monitor if value else godot_joypad_monitor,
			steam_device_actions if value else godot_device_actions,
			steam_device_glyphs if value else godot_device_glyphs,
			steam_device_haptics if value else godot_device_haptics,
		)
	)
