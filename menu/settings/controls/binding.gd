##
## Binding is a button node which allows a user to rebind an action. It shows, resets
## and rebinds one category of device's binding, regardless of the active device, and
## its button is disabled while no device of that category is connected.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Bindings := preload("res://addons/std/input/godot/binding.gd")
const Rebinder := preload("rebinder.gd")
const Screens := preload("../../../ui/menu/screens.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

## device_category is the category of device whose binding this shows, resets and
## rebinds, either `DEVICE_TYPE_KEYBOARD` for the keyboard and mouse or
## `DEVICE_TYPE_GENERIC` for controllers.
@export var device_category: StdInputDevice.DeviceType = DEVICE_TYPE_KEYBOARD

@export_subgroup("Components")

## glyph is the `KitInputGlyph` node which displays the current origin binding.
@export var glyph: KitInputGlyph = null

## button is the `Button` node which, when pressed, will open the `Rebinder` panel.
@export var button: Button = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## has_user_override returns whether the input binding has a user-specified value (i.e.
## a non-default origin).
func has_user_override() -> bool:
	return (
		Bindings
		. action_has_user_override(
			scope,
			glyph.action_set,
			glyph.action,
			device_category,
			glyph.binding_index,
		)
	)


## reset returns the input binding back to its default value.
func reset() -> void:
	(
		Bindings
		. reset_action(
			scope,
			glyph.action_set,
			glyph.action,
			device_category,
			glyph.binding_index,
		)
	)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(glyph is KitInputGlyph, "invalid state; missing node")
	assert(button is Button, "invalid state; missing node")
	assert(scope is StdSettingsScope, "invalid config; missing scope")
	assert(
		device_category in [DEVICE_TYPE_KEYBOARD, DEVICE_TYPE_GENERIC],
		"invalid config; unsupported device category",
	)

	glyph.always_show_kbm = device_category == DEVICE_TYPE_KEYBOARD
	glyph.always_show_joy = device_category == DEVICE_TYPE_GENERIC

	Signals.connect_safe(button.pressed, _on_button_pressed)
	Signals.connect_safe(scope.config.changed, _on_bindings_changed)

	var slot := StdInputSlot.for_player(glyph.player_id)
	assert(slot is StdInputSlot, "invalid state; missing player slot")

	Signals.connect_safe(slot.device_connected, _on_device_connection_changed)
	Signals.connect_safe(slot.device_disconnected, _on_device_connection_changed)

	_update_button()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _update_button disables the button while no device of `device_category` is connected,
## since a rebind would have nothing to listen to.
func _update_button() -> void:
	var slot := StdInputSlot.for_player(glyph.player_id)
	button.disabled = not Rebinder.find_device(slot, device_category)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_bindings_changed(category: StringName, key: StringName) -> void:
	if category != Bindings.get_action_set_category(glyph.action_set, device_category):
		return

	if key != Bindings.get_action_key(glyph.action, glyph.binding_index):
		return

	glyph.update()


func _on_button_pressed() -> void:
	(
		Rebinder
		. start_rebinding(
			Screens.find_manager(self),
			scope,
			glyph.action_set,
			glyph.action,
			device_category,
			glyph.binding_index,
			glyph.player_id,
		)
	)


func _on_device_connection_changed(_device: StdInputDevice) -> void:
	_update_button()
