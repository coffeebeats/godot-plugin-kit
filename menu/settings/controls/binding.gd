##
## Binding is a button node which allows a user to rebind an action. It shows, resets
## and rebinds one category of device's binding at one binding index, regardless of the
## active device, and its button is disabled while no device of that category is
## connected. A key with a label shows it as text, an unbound index says so, and any
## other origin draws its glyph.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Bindings := preload("res://addons/std/input/godot/binding.gd")
const KeycapTexture := preload("res://addons/std/input/godot/keycap_texture.gd")
const Rebinder := preload("rebinder.gd")
const Screens := preload("../../../ui/menu/screens.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DeviceType := StdInputDevice.DeviceType  # gdlint:ignore=constant-name
const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

## MSGID_UNBOUND is the text shown for a binding index with no origin bound.
const MSGID_UNBOUND := &"kit_options_controls_unbound"

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

## device_category is the category of device whose binding this shows, resets and
## rebinds, either `DEVICE_TYPE_KEYBOARD` for the keyboard and mouse or
## `DEVICE_TYPE_GENERIC` for controllers.
@export var device_category: DeviceType = DEVICE_TYPE_KEYBOARD

## linked_layers are layers over other sets which also declare `action`, saving its
## binding under their own names. A rebind or reset writes to each of them as well as to
## `action_set`, whose binding this shows.
@export var linked_layers: Array[StdInputActionSetLayer] = []

@export_subgroup("Action")

## action_set is the action set which defines `action`.
@export var action_set: StdInputActionSet = null

## action is the input action whose binding this shows.
@export var action := &""

## binding_index is the binding (e.g. primary or secondary) this shows. It shows this
## index alone, so an unbound index reads as unbound rather than as the next binding.
@export var binding_index: int = StdInputDeviceActions.BINDING_INDEX_PRIMARY

## player_id selects the player whose `StdInputSlot` supplies the bindings.
@export var player_id: int = 1

@export_subgroup("Display")

## device_type_override is the player's setting for the device type whose glyphs draw.
## A controller binding draws the family it names, else the connected joypads'.
@export var device_type_override: StdSettingsPropertyInt = null

## glyph_scale is a glyph's height in lines of the theme's `Label` text.
@export var glyph_scale: float = 1.0

@export_subgroup("Components")

## button is the `Button` node which, when pressed, will open the `Rebinder` panel.
@export var button: Button = null

## glyph is the `TextureRect` node which draws an origin's glyph.
@export var glyph: TextureRect = null

## label is the `Label` node which shows a key's label, or that nothing is bound.
@export var label: Label = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## has_user_override returns whether the input binding has a user-specified value (i.e.
## a non-default origin).
func has_user_override() -> bool:
	return (
		Bindings
		. action_has_user_override(
			scope,
			action_set,
			action,
			device_category,
			binding_index,
		)
	)


## reset returns the input binding back to its default value.
func reset() -> void:
	for target: StdInputActionSet in [action_set] + linked_layers:
		Bindings.reset_action(scope, target, action, device_category, binding_index)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_TRANSLATION_CHANGED:
			if is_node_ready():
				_update_origin()


func _ready() -> void:
	assert(button is Button, "invalid state; missing node")
	assert(glyph is TextureRect, "invalid state; missing node")
	assert(label is Label, "invalid state; missing node")
	assert(scope is StdSettingsScope, "invalid config; missing scope")
	assert(action_set is StdInputActionSet, "invalid config; missing action set")
	assert(action, "invalid config; missing action")
	assert(
		device_category in [DEVICE_TYPE_KEYBOARD, DEVICE_TYPE_GENERIC],
		"invalid config; unsupported device category",
	)

	Signals.connect_safe(button.pressed, _on_button_pressed)
	Signals.connect_safe(scope.config.changed, _on_bindings_changed)

	var slot := StdInputSlot.for_player(player_id)
	assert(slot is StdInputSlot, "invalid state; missing player slot")

	Signals.connect_safe(slot.action_configuration_changed, _update_origin)
	Signals.connect_safe(slot.origin_labels_changed, _update_origin)
	Signals.connect_safe(slot.device_connected, _on_device_connection_changed)
	Signals.connect_safe(slot.device_disconnected, _on_device_connection_changed)

	if device_type_override:
		Signals.connect_safe(device_type_override.value_changed, _on_setting_changed)

	_update_button()
	_update_origin()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_device_type returns the device type whose origin this shows, which is the
## keyboard's, or the controller family the player chose, else the connected joypads'.
func _get_device_type(slot: StdInputSlot) -> DeviceType:
	if device_category == DEVICE_TYPE_KEYBOARD:
		return DEVICE_TYPE_KEYBOARD

	if device_type_override:
		var setting: DeviceType = device_type_override.get_value()
		if (
			setting != DEVICE_TYPE_GENERIC
			and StdInputDevice.get_device_category(setting) == DEVICE_TYPE_GENERIC
		):
			return setting

	return slot.get_joypad_device_type()


## _update_button disables the button while no device of `device_category` is connected,
## since a rebind would have nothing to listen to.
func _update_button() -> void:
	var slot := StdInputSlot.for_player(player_id)
	button.disabled = not Rebinder.find_device(slot, device_category)


## _update_origin shows the origin bound at `binding_index`. A labelled key shows as
## text, an unbound index as `MSGID_UNBOUND`, and anything else as its glyph.
func _update_origin() -> void:
	var slot := StdInputSlot.for_player(player_id)

	# NOTE: This reads `Label`'s font through the row, since `label` refreshes its own
	# theme only after the row handles a theme change.
	var font := get_theme_font(&"font", &"Label")
	var height := roundi(
		font.get_height(get_theme_font_size(&"font_size", &"Label")) * glyph_scale
	)

	var texture := slot.get_action_glyph(
		action_set, action, binding_index, Vector2(0, height), _get_device_type(slot)
	)

	var keycap := texture as KeycapTexture
	if keycap and not keycap.icon:
		texture = null
		label.text = keycap.label
	else:
		label.text = "" if texture else tr(MSGID_UNBOUND)

	glyph.texture = texture
	glyph.custom_minimum_size = (
		Vector2(height * texture.get_size().aspect(), height)
		if texture
		else Vector2.ZERO
	)

	glyph.visible = texture != null
	label.visible = texture == null


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_bindings_changed(category: StringName, key: StringName) -> void:
	if category != Bindings.get_action_set_category(action_set, device_category):
		return

	if key != Bindings.get_action_key(action, binding_index):
		return

	_update_origin()


func _on_button_pressed() -> void:
	(
		Rebinder
		. start_rebinding(
			Screens.find_manager(self),
			scope,
			action_set,
			action,
			device_category,
			binding_index,
			player_id,
			linked_layers,
		)
	)


func _on_device_connection_changed(_device: StdInputDevice) -> void:
	# NOTE: A slot leaving the tree disconnects its devices on the way out.
	if not StdInputSlot.for_player(player_id):
		return

	_update_button()
	_update_origin()


func _on_setting_changed(_value: Variant) -> void:
	_update_origin()
