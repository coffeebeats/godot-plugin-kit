##
## KitInputGlyph is a `TextureRect` which draws the glyph of the origin bound to an
## action, following its player's active device, bindings and keyboard layout. The glyph
## is as tall as a line of the theme's text, times `glyph_scale`, so it follows the
## player's text size.
##

@tool
class_name KitInputGlyph
extends TextureRect

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Action")

## action_set is the action set which defines `action`.
@export var action_set: StdInputActionSet = null:
	set(value):
		action_set = value
		if _glyph:
			_glyph.action_set = value

## action is the input action whose binding the glyph shows.
@export var action := &"":
	set(value):
		action = value
		if _glyph:
			_glyph.action = value

## binding_index is the binding (e.g. primary or secondary) drawn first. An unbound
## index is skipped, so the glyph draws the next binding instead.
@export var binding_index: int = 0:
	set(value):
		binding_index = value
		if _glyph:
			_glyph.binding_index = value

## cycle_interval is the time in seconds each origin bound to the action is shown before
## the glyph advances to the next, starting over from `binding_index`, so a player sees
## every binding; `0` shows the first alone.
@export var cycle_interval: float = 0.0:
	set(value):
		cycle_interval = value
		if _glyph:
			_glyph.cycle_interval = value

@export_subgroup("Player")

## player_id selects the player whose `StdInputSlot` supplies the bindings.
@export var player_id: int = 1:
	set(value):
		player_id = value
		if _glyph:
			_glyph.player_id = value

@export_subgroup("Device")

## device_type_override is the player's setting for the device type whose glyphs draw.
## `DEVICE_TYPE_UNKNOWN` follows the active device, `DEVICE_TYPE_GENERIC` the connected
## joypads' family, and any other value that type.
@export var device_type_override: StdSettingsPropertyInt = null:
	set(value):
		device_type_override = value
		if _glyph:
			_glyph.device_type_override = value

@export_group("Display")

## glyph_scale is the glyph's height in lines of the theme's text.
@export var glyph_scale: float = 1.0:
	set(value):
		glyph_scale = value
		_update_size()

## restrict_glyph_type_to_device_category ignores a `device_type_override` outside the
## active device's category (i.e. keyboard vs. joypad).
@export var restrict_glyph_type_to_device_category: bool = false:
	set(value):
		restrict_glyph_type_to_device_category = value
		if _glyph:
			_glyph.restrict_to_device_category = value

@export_subgroup("Device type")

## always_show_kbm draws the keyboard and mouse binding whichever device is active,
## ignoring `device_type_override`.
##
## NOTE: Only one of `always_show_kbm` and `always_show_joy` may be `true`.
@export var always_show_kbm: bool = false:
	set(value):
		always_show_kbm = value
		if value and always_show_joy:
			always_show_joy = false

		_update_device_type()

## always_show_joy draws the controller binding whichever device is active, in the
## family `device_type_override` names, else the connected joypads'.
##
## NOTE: Only one of `always_show_joy` and `always_show_kbm` may be `true`.
@export var always_show_joy: bool = false:
	set(value):
		always_show_joy = value
		if value and always_show_kbm:
			always_show_kbm = false

		_update_device_type()

@export_subgroup("Force hide")

## hide_if_cursor_visible hides the glyph while the cursor is visible and the keyboard
## and mouse are active, so a keyboard glyph shows only in focus navigation.
##
## NOTE: A cursor revealed while a joypad stays active keeps the glyph shown, since the
## joypad's binding is still the one the player would press.
@export var hide_if_cursor_visible: bool = false:
	set(value):
		hide_if_cursor_visible = value
		_update_shown()

## hide_if_kbm_active hides the glyph while the keyboard and mouse are active, whatever
## `always_show_kbm` says.
@export var hide_if_kbm_active: bool = false:
	set(value):
		hide_if_kbm_active = value
		_update_shown()

## hide_if_joy_active hides the glyph while a joypad is active, whatever
## `always_show_joy` says.
@export var hide_if_joy_active: bool = false:
	set(value):
		hide_if_joy_active = value
		_update_shown()

# -- INITIALIZATION ------------------------------------------------------------------ #

## _glyph is the texture which draws the glyph, shown as `texture` unless hidden.
var _glyph: StdInputGlyphTexture = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_glyph returns the texture which draws the glyph, also while the glyph is hidden.
func get_glyph() -> StdInputGlyphTexture:
	return _glyph


## update redraws the glyph and restarts its cycle from `binding_index`. Call it after
## changing the action's bindings outside the input system.
func update() -> void:
	if _glyph:
		_glyph.update()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not action_set is StdInputActionSet:
		warnings.append("missing action set")

	elif not action:
		warnings.append("missing action")

	elif action not in action_set.list_action_names():
		warnings.append("invalid action; not in action set")

	return warnings


func _init() -> void:
	if Engine.is_editor_hint():
		return

	_glyph = StdInputGlyphTexture.new()
	_glyph.changed.connect(_update_shown)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_update_size()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# NOTE: This binds the texture to the player's slot and draws it, so `texture` is set
	# before the parent's `_ready`.
	_glyph.update()


func _validate_property(property: Dictionary) -> void:
	# NOTE: The glyph is the texture, so a texture set in a scene would only be replaced.
	if property[&"name"] == &"texture":
		property[&"usage"] = PROPERTY_USAGE_NONE


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _is_hidden returns whether one of the `hide_if_*` conditions holds for the player's
## active device.
func _is_hidden() -> bool:
	var slot := StdInputSlot.for_player(player_id)
	if not slot:
		return false

	if hide_if_kbm_active and slot.device_type == DEVICE_TYPE_KEYBOARD:
		return true

	if hide_if_joy_active and slot.device_category == DEVICE_TYPE_GENERIC:
		return true

	return (
		hide_if_cursor_visible
		and slot.device_type == DEVICE_TYPE_KEYBOARD
		and slot.cursor is StdInputCursor
		and slot.cursor.get_is_visible()
	)


## _update_device_type locks the texture to the keyboard or to a controller as
## `always_show_kbm` and `always_show_joy` ask, else lets it follow the active device.
func _update_device_type() -> void:
	if not _glyph:
		return

	_glyph.device_type = (
		DEVICE_TYPE_KEYBOARD
		if always_show_kbm
		else DEVICE_TYPE_GENERIC if always_show_joy else DEVICE_TYPE_UNKNOWN
	)


## _update_shown shows the glyph, or hides it while a `hide_if_*` condition holds. A
## hidden glyph keeps only its `custom_minimum_size`.
func _update_shown() -> void:
	if not _glyph or not is_inside_tree():
		return

	texture = null if _is_hidden() else _glyph


## _update_size sets the glyph's height to a line of the theme's text at its font size,
## times `glyph_scale`.
func _update_size() -> void:
	if not _glyph:
		return

	var line := get_theme_default_font().get_height(get_theme_default_font_size())
	_glyph.size = roundi(line * glyph_scale)
