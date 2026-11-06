##
## Glyph is an opinionated implementation of a dynamic origin icon which updates its
## contents based on what the action is currently bound to and which device the player
## is currently using.
##

@tool
class_name KitInputGlyph
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## glyph_updated is emitted after each redraw with whether the glyph shows anything. It
## may fire when nothing changed.
signal glyph_updated(has_contents: bool)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const KeycapTexture := preload("res://addons/std/input/godot/keycap_texture.gd")
const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DeviceType := StdInputDevice.DeviceType  # gdlint:ignore=constant-name
const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Action")

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null

## action is the input action whose binding the glyph shows.
@export var action := &""

## binding_index is the index/rank (e.g. primary or secondary) of the action binding.
@export var binding_index: int = 0

## cycle_interval is the time (in seconds) each origin bound to the action is shown
## before the glyph advances to the next one, starting over from `binding_index`, so a
## player sees every binding. `0` shows `binding_index` alone.
@export var cycle_interval: float = 0.0:
	set(value):
		if value == cycle_interval:
			return

		cycle_interval = value

		if Engine.is_editor_hint() or not is_node_ready():
			return

		# NOTE: A change restarts the cycle, since the origin count is only fetched while
		# cycling, and starts or stops the processing which drives it.
		_cycle_offset = 0
		_cycle_time = 0.0
		set_process(cycle_interval > 0.0)
		_handle_update()

@export_subgroup("Player")

## player_id selects the player whose `StdInputSlot` supplies the bindings. That slot
## must be in the scene tree when the glyph enters it.
@export var player_id: int = 1

@export_subgroup("Device")

## device_type_override is an optional setting that locks which device's glyphs draw,
## while every device stays accepted. `DEVICE_TYPE_UNKNOWN` follows the active device,
## `DEVICE_TYPE_GENERIC` the connected joypads' family, and any other value that type.
@export var device_type_override: StdSettingsPropertyInt = null

@export_group("Display")

## restrict_glyph_type_to_device_category controls whether the displayed glyph type
## should be constrained to the active device's category. Effectively, this means that
## glyph type overrides will be ignored if they don't pertain to the active device
## category (i.e. keyboard vs. joypad).
@export var restrict_glyph_type_to_device_category: bool = false

@export_subgroup("Device type")

## always_show_kbm forcibly shows glyph information for keyboard and mouse devices. When
## enabled, `device_type_override` will be ignored.
##
## NOTE: Only one of `always_show_kbm` and `always_show_joy` may be `true`. If neither
## are enabled then either the active device's type is used or the
## `device_type_override` if it's set.
@export var always_show_kbm: bool = false:
	set(value):
		always_show_kbm = value
		if value and always_show_joy:
			always_show_joy = false

## always_show_joy forcibly shows glyph information for joypad devices. When enabled,
## `device_type_override` will be ignored.
##
## NOTE: Only one of `always_show_joy` and `always_show_kbm` may be `true`. If neither
## are enabled then either the active device's type is used or the
## `device_type_override` if it's set.
@export var always_show_joy: bool = false:
	set(value):
		always_show_joy = value
		if value and always_show_kbm:
			always_show_kbm = false

@export_subgroup("Force hide")

## hide_if_cursor_visible controls whether this glyph is hidden while the cursor is
## visible and the keyboard and mouse are active. This is to enable keyboard and
## mouse-only glyphs being shown only when the game is using "focus" mode navigation.
##
## NOTE: A cursor revealed while a joypad stays active keeps the glyph shown, since the
## joypad's binding is still the one the player would press.
@export var hide_if_cursor_visible: bool = false

## hide_if_kbm_active controls whether this glyph is displayed when the active device is
## a keyboard and mouse. Note that this applies regardless of whether `always_show_kbm`
## is selected.
@export var hide_if_kbm_active: bool = false

## hide_if_joy_active controls whether this glyph is displayed when the active device is
## a joypad. Note that this applies regardless of whether `always_show_joy`
## is selected.
@export var hide_if_joy_active: bool = false

@export_subgroup("Labels")

## show_origin_label_as_fallback_kbm controls whether to show the origin display name if
## there's no glyph icon available for the keyboard and mouse device.
@export var show_origin_label_as_fallback_kbm: bool = true

## show_origin_label_as_fallback_joy controls whether to show the origin display name if
## there's no glyph icon available for joypad devices.
@export var show_origin_label_as_fallback_joy: bool = false

## origin_label_overrides is a lookup table of overrides for the origin label returned
## by the input system. Use this to customize output (e.g. "Esc" instead of "Escape").
##
## See https://github.com/godotengine/godot/blob/master/core/os/keyboard.cpp for a list
## of key labels.
##
## TODO: Replace this system with translations once localization of keys is supported;
## see https://github.com/godotengine/godot-proposals/issues/10350.
@export var origin_label_overrides: Dictionary = {}

## label_stylebox is an optional stylebox to display the origin label within. If set,
## this will override the default stylebox for the label's `PanelContainer`.
##
## NOTE: Both this stylebox and the default one set on `panel_container` will *only* be
## shown when an origin label is set.
@export var label_stylebox: StyleBox = null

## show_keys_as_labels controls whether a drawn key shows its keycap's label in `label`,
## inside `label_stylebox`, in place of the keycap. A key drawn as an icon, such as an
## arrow, keeps its keycap.
@export var show_keys_as_labels: bool = false

## Fallback properties apply when neither a glyph or a label (if configured) are found
## for the configured action. When fallbacks are used, *both* of the label and textures
## are used if set.
@export_subgroup("Fallback")

## fallback_label is a label to display when no glyph or label is found.
@export var fallback_label: String = ""

## fallback_texture is a texture to display when no glyph or label is found.
@export var fallback_texture: Texture2D = null

@export_group("Components")

## label is the `Label` node which origin display names will be rendered in.
@export var label: Label = null

## panel_container is the `PanelContainer` node in which keyboard labels will be shown.
@export var panel_container: PanelContainer = null

## texture_rect is the `TextureRect` node which the origin glyph icon will be rendered
## in.
@export var texture_rect: TextureRect = null

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _stylebox_empty := StyleBoxEmpty.new()

var _custom_minimum_size: Vector2 = Vector2.ZERO
var _cycle_offset: int = 0
var _cycle_time: float = 0.0
var _origin_count: int = 0
var _slot: StdInputSlot = null
var _stylebox: StyleBox = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_binding_index returns the index of the origin to display: `binding_index`, moved
## along by cycling.
func get_binding_index() -> int:
	return binding_index + _cycle_offset


## update redraws the glyph and restarts its cycle from `binding_index`. Call it after
## changing the action configuration.
func update() -> void:
	_cycle_offset = 0
	_cycle_time = 0.0
	_handle_update()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_slot = StdInputSlot.for_player(player_id)
	assert(_slot is StdInputSlot, "invalid state; missing player slot")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not action_set is StdInputActionSet:
		warnings.append("missing action set")

	elif not action:
		warnings.append("missing action")

	elif not (
		action in action_set.actions_analog_1d
		or action in action_set.actions_analog_2d
		or action in action_set.actions_digital
		or action == action_set.action_absolute_mouse
	):
		warnings.append("invalid action; not in action set")

	elif player_id < 0:
		warnings.append("invalid action; missing player")

	return warnings


func _process(delta: float) -> void:
	if cycle_interval <= 0.0 or _get_cycle_length() < 2:
		return

	_cycle_time += delta
	if _cycle_time < cycle_interval:
		return

	# NOTE: A frame longer than the interval advances the glyph once and drops the
	# surplus, rather than catching up a step per frame afterwards.
	_cycle_time = fmod(_cycle_time, cycle_interval)
	_cycle_offset = (_cycle_offset + 1) % _get_cycle_length()
	_handle_update()


func _ready() -> void:
	_custom_minimum_size = custom_minimum_size

	if Engine.is_editor_hint():
		set_process(false)
		return

	assert(label is Label, "invalid state; missing node")
	assert(panel_container is PanelContainer, "invalid state; missing node")
	assert(texture_rect is TextureRect, "invalid state; missing node")

	_stylebox = (
		label_stylebox
		if label_stylebox
		else panel_container.get_theme_stylebox(&"panel")
	)

	set_process(cycle_interval > 0.0)

	Signals.connect_safe(_slot.action_configuration_changed, _on_actions_changed)
	Signals.connect_safe(_slot.cursor_visibility_changed, _on_slot_changed)
	Signals.connect_safe(_slot.device_activated, _on_device_activated)
	Signals.connect_safe(_slot.origin_labels_changed, _handle_update)

	# NOTE: A controller glyph locked by a `DEVICE_TYPE_GENERIC` override follows the
	# connected joypads, so a connect or disconnect can change its family.
	Signals.connect_safe(_slot.device_connected, _on_slot_changed)
	Signals.connect_safe(_slot.device_disconnected, _on_slot_changed)

	if device_type_override is StdSettingsPropertyInt:
		Signals.connect_safe(device_type_override.value_changed, _on_slot_changed)

	# NOTE: Deferred so a parent can configure the glyph in its own `_ready` first.
	_handle_update.call_deferred()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_cycle_length() -> int:
	return _origin_count - binding_index


func _get_device_type() -> DeviceType:
	if always_show_kbm:
		return DeviceType.KEYBOARD

	var property_value: DeviceType = DEVICE_TYPE_UNKNOWN
	if device_type_override is StdSettingsPropertyInt:
		property_value = device_type_override.get_value()

	# NOTE: A `DEVICE_TYPE_GENERIC` override stands for the connected joypads' own type,
	# as std's glyph resolves it.
	if property_value == DEVICE_TYPE_GENERIC:
		property_value = _slot.get_joypad_device_type()

	if always_show_joy:
		# When showing joypad glyphs, still check if an override was set in settings,
		# but only use it if a joypad type is selected.
		if (
			property_value != DEVICE_TYPE_UNKNOWN
			and property_value != DEVICE_TYPE_KEYBOARD
		):
			return property_value

		return _slot.get_joypad_device_type()

	if restrict_glyph_type_to_device_category:
		match _slot.device_category:
			DEVICE_TYPE_UNKNOWN, DEVICE_TYPE_KEYBOARD:
				return _slot.device_type  # Both categories only have one type.
			DEVICE_TYPE_GENERIC:
				var property_category := StdInputDevice.get_device_category(
					property_value
				)
				return (
					property_value
					if property_category == DEVICE_TYPE_GENERIC
					else _slot.device_type
				)

	# gdlint:ignore=max-returns
	return (
		property_value if property_value != DEVICE_TYPE_UNKNOWN else _slot.device_type
	)


func _handle_update() -> void:
	assert(action, "invalid config; missing action")
	assert(action_set is StdInputActionSet, "invalid config; missing action set")

	var device_type := _get_device_type()

	_origin_count = (
		_slot.get_action_origin_count(action_set, action, device_type)
		if cycle_interval > 0.0
		else 0
	)
	if _cycle_offset >= maxi(_get_cycle_length(), 1):
		_cycle_offset = 0

	var has_contents: bool = _update_glyph(device_type, get_binding_index())

	glyph_updated.emit(has_contents)


func _update_glyph(device_type: DeviceType, index: int) -> bool:
	var label_prev: String = label.text
	label.text = ""

	var texture_prev: Texture = texture_rect.texture
	texture_rect.texture = null

	var should_hide := (
		(hide_if_kbm_active and _slot.device_type == DEVICE_TYPE_KEYBOARD)
		or (hide_if_joy_active and _slot.device_category == DEVICE_TYPE_GENERIC)
		or (
			hide_if_cursor_visible
			and _slot.device_type == DEVICE_TYPE_KEYBOARD
			and _slot.cursor is StdInputCursor
			and _slot.cursor.get_is_visible()
		)
	)

	if not should_hide:
		texture_rect.texture = (
			_slot
			. get_action_glyph(
				action_set,
				action,
				index,
				custom_minimum_size,
				device_type,
			)
		)

		var keycap := texture_rect.texture as KeycapTexture
		if show_keys_as_labels and keycap and not keycap.icon:
			texture_rect.texture = null
			label.text = keycap.label

		if (
			texture_rect.texture == null
			and label.text == ""
			and (
				(
					show_origin_label_as_fallback_kbm
					and device_type == DEVICE_TYPE_KEYBOARD
				)
				or (
					show_origin_label_as_fallback_joy
					and device_type != DEVICE_TYPE_KEYBOARD
					and device_type != DEVICE_TYPE_UNKNOWN
				)
			)
		):
			var origin_label := (
				_slot
				. get_action_origin_label(
					action_set,
					action,
					index,
					device_type,
				)
			)

			label.text = origin_label_overrides.get(origin_label, origin_label)

	if not should_hide and texture_rect.texture == null and label.text == "":
		label.text = fallback_label
		texture_rect.texture = fallback_texture

	if label.text == "":
		panel_container.add_theme_stylebox_override(&"panel", _stylebox_empty)
	elif _stylebox:
		panel_container.add_theme_stylebox_override(&"panel", _stylebox)
	else:
		panel_container.remove_theme_stylebox_override(&"panel")

	texture_rect.visible = texture_rect.texture != null
	label.visible = label.text != ""

	var minimum_size := _custom_minimum_size

	if texture_rect.visible:
		minimum_size = minimum_size.max(texture_rect.get_combined_minimum_size())

	# NOTE: The panel's size includes its stylebox and margins around the label, so a
	# label's box stays inside the glyph's rect and a container's separation holds.
	if label.visible:
		minimum_size = minimum_size.max(panel_container.get_combined_minimum_size())

	custom_minimum_size = minimum_size

	return texture_rect.texture != texture_prev or label.text != label_prev


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_actions_changed() -> void:
	update()


func _on_device_activated(_device: StdInputDevice) -> void:
	update()


func _on_slot_changed(_value: Variant) -> void:
	_handle_update()
