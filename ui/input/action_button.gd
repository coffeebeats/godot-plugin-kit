##
## KitInputActionButton is a `Button` which stands for an input action. Its icon is the
## glyph of the origin bound to the action, its text is the action's translated name,
## and a click raises the action, so a key, a click and synthetic input share one
## handler. The glyph is as tall as a line of the button's text, so it follows the
## player's text size.
##
## When an active set declares the action a hold, the button shows how the player
## performs it in the mode their setting picks: `hold_text` and a fill while it's held,
## a cancel prompt and a fill after a toggle's tap, or the plain text for a press.
##
## NOTE: The handler the action reaches validates it, since a key gets there whether or
## not the button is enabled.
##

@tool
class_name KitInputActionButton
extends Button

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GlyphTypeProperty := preload(
	"res://system/setting/controls/glyph_type_property.tres"
)
const Locales := preload("../../locale/locales.gd")
const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## MSGID_ACTION_NAME is the template for the button's accessible name, which joins the
## origin's name, as `{origin}`, and the button's text, as `{action}`.
const MSGID_ACTION_NAME := &"kit_input_action_name"

## MSGID_CANCEL is the button's text while a tapped toggle runs, since a second tap, or
## a press of the hold's `cancel_action`, cancels it.
const MSGID_CANCEL := &"kit_cancel"

## MSGID_HOLD is the default `hold_text`, which formats the action's name as `{action}`.
const MSGID_HOLD := &"kit_hold"

## THEME_GLYPH_SCALE_PERCENT is the theme constant giving the glyph's height as a
## percentage of a line of the button's text, read from the button's own types and then
## `THEME_TYPE`; 100 when neither has it.
const THEME_GLYPH_SCALE_PERCENT := &"glyph_scale_percent"

## THEME_HOLD_FILL_COLOR is the theme color of the fill a running hold draws over the
## button, read as `THEME_GLYPH_SCALE_PERCENT` is; translucent white when neither type
## has it.
const THEME_HOLD_FILL_COLOR := &"hold_fill_color"

## THEME_HOLD_FILL_HEIGHT_PERCENT is the theme constant giving the fill's height as a
## percentage of the button's, rising from its bottom edge, read as
## `THEME_GLYPH_SCALE_PERCENT` is; 100, covering the button, when neither type has it.
const THEME_HOLD_FILL_HEIGHT_PERCENT := &"hold_fill_height_percent"

## THEME_TYPE is the theme type holding the button's own theme items.
const THEME_TYPE := &"KitInputActionButton"

const _HOLD_FILL_COLOR_DEFAULT := Color(1.0, 1.0, 1.0, 0.25)

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Action")

## action_set is the action set which defines `action`.
@export var action_set: StdInputActionSet = null:
	set(value):
		action_set = value
		if _glyph:
			_glyph.action_set = value
			_update_text()

## action is the input action the button stands for.
@export var action := &"":
	set(value):
		action = value
		if _glyph:
			_reset_hold()
			_update_hold()
			_update_trigger()

## binding_index is the binding (e.g. primary or secondary) whose glyph is drawn first.
## An unbound index is skipped, so the button draws the next binding instead.
@export var binding_index: int = 0:
	set(value):
		binding_index = value
		if _glyph:
			_glyph.binding_index = value

## player_id selects the player whose `StdInputSlot` supplies the bindings.
@export var player_id: int = 1:
	set(value):
		player_id = value
		if _glyph:
			_glyph.player_id = value
			_update_slot()

@export_subgroup("Behavior")

## raise_action is whether a click raises `action`, held for as long as the button is.
## Off, the button raises nothing and a game connects `pressed` as on any button.
@export var raise_action: bool = true:
	set(value):
		raise_action = value
		_update_trigger()

## use_action_text is whether `text` is the action's translated name, following the
## player's language. Off, the button keeps the `text` a game sets.
@export var use_action_text: bool = true:
	set(value):
		use_action_text = value
		_update_text()

## hold_text is the translation key of the text shown while `action` is a hold which
## the player holds, with the action's name formatted in as `{action}`, such as "Hold
## to {action}". Empty, the button shows the name alone and leaves the fill to say hold.
## It applies only while `use_action_text` is on.
@export var hold_text: StringName = MSGID_HOLD:
	set(value):
		hold_text = value
		_update_text()

## focus_anchor is whether focus navigation may land on the button when its screen
## opens. It takes effect when the button enters the tree.
@export var focus_anchor: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

## _glyph is the texture which draws the action's glyph as `icon`.
var _glyph: StdInputGlyphTexture = null

## _hold is the hold an active set declares on `action`, or `null` when it's no hold.
var _hold: StdInputActionHold = null

## _hold_mode is the mode `_hold` runs in, or `MODE_PRESS` when there's no hold.
var _hold_mode := StdInputActionHold.MODE_PRESS

## _hold_progress is how far the running hold has filled, which the fill draws.
var _hold_progress: float = 0.0

## _hold_tapped is whether a tap started a toggle which still runs, so the button shows
## how to cancel it.
var _hold_tapped: bool = false

## _mode_properties are the settings properties which choose `_hold_mode`, connected so
## a change made while no hold runs, which the slot doesn't report, reaches the button.
var _mode_properties: Array[StdSettingsPropertyInt] = []

## _slot is the slot of `player_id`, whose holds the button shows.
var _slot: StdInputSlot = null

## _trigger raises `action` on a click while `raise_action` is on.
var _trigger: StdInputActionTrigger = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_glyph returns the texture which draws the action's glyph as `icon`.
func get_glyph() -> StdInputGlyphTexture:
	return _glyph


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _draw() -> void:
	if _hold_progress <= 0.0:
		return

	var percent := clampi(_get_theme_int(THEME_HOLD_FILL_HEIGHT_PERCENT, 100), 0, 100)
	var fill := Vector2(size.x * _hold_progress, size.y * percent / 100.0)
	var x := size.x - fill.x if is_layout_rtl() else 0.0

	draw_rect(
		Rect2(Vector2(x, size.y - fill.y), fill),
		_get_theme_color(THEME_HOLD_FILL_COLOR, _HOLD_FILL_COLOR_DEFAULT),
	)


func _enter_tree() -> void:
	# NOTE: The handler registers as an anchor when it enters the tree, just after this.
	var handler := get_node_or_null(^"FocusHandler") as StdInputCursorFocusHandler
	if handler:
		handler.use_as_anchor = focus_anchor

	if _glyph:
		_update_slot()


func _exit_tree() -> void:
	if _glyph:
		_set_slot(null)


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
	_glyph.device_type_override = GlyphTypeProperty
	_glyph.changed.connect(_update_accessibility_name)
	icon = _glyph


func _notification(what: int) -> void:
	if not _glyph:
		return

	match what:
		NOTIFICATION_THEME_CHANGED:
			_update_size()
		NOTIFICATION_TRANSLATION_CHANGED:
			_update_text()
		NOTIFICATION_ACCESSIBILITY_UPDATE:
			# NOTE: A game's own `text` reaches the name here, which Godot sends only while
			# assistive tech is listening.
			_update_accessibility_name()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_update_text()
	_update_trigger()

	# NOTE: This binds the texture to the player's slot and draws it.
	_glyph.update()


func _validate_property(property: Dictionary) -> void:
	# NOTE: The glyph is the icon, so an icon set in a scene would only be replaced.
	if property[&"name"] == &"icon":
		property[&"usage"] = PROPERTY_USAGE_NONE


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_theme_color returns the theme color `item` from the button's own types, then
## `THEME_TYPE`, or `default` when neither has it.
func _get_theme_color(item: StringName, default: Color) -> Color:
	for theme_type in [&"", THEME_TYPE]:
		if has_theme_color(item, theme_type):
			return get_theme_color(item, theme_type)

	return default


## _get_theme_int returns the theme constant `item` from the button's own types, then
## `THEME_TYPE`, or `default` when neither has it.
func _get_theme_int(item: StringName, default: int) -> int:
	for theme_type in [&"", THEME_TYPE]:
		if has_theme_constant(item, theme_type):
			return get_theme_constant(item, theme_type)

	return default


## _reset_hold clears the display of a hold which ended.
func _reset_hold() -> void:
	_hold_progress = 0.0
	_hold_tapped = false

	_update_glyph_action()
	_update_text()
	queue_redraw()


## _set_mode_properties connects the button to `properties`, the settings properties
## which choose the hold's mode, in place of those it was connected to.
func _set_mode_properties(properties: Array[StdSettingsPropertyInt]) -> void:
	for property in _mode_properties:
		Signals.disconnect_safe(property.value_changed, _on_mode_property_value_changed)

	_mode_properties = properties

	for property in _mode_properties:
		Signals.connect_safe(property.value_changed, _on_mode_property_value_changed)


## _set_slot connects the button to the hold signals of `slot`, in place of the slot it
## was connected to, and shows that slot's hold.
func _set_slot(slot: StdInputSlot) -> void:
	if slot == _slot:
		return

	# NOTE: A slot freed before the button, as a tree is freed, has no signals left.
	if is_instance_valid(_slot):
		_set_slot_connected(_slot, false)

	_slot = slot

	if _slot:
		_set_slot_connected(_slot, true)

	_reset_hold()
	_update_hold()


## _set_slot_connected connects the button to the signals of `slot` which change its
## hold, or disconnects it from them.
func _set_slot_connected(slot: StdInputSlot, connected: bool) -> void:
	for pair in [
		[slot.action_configuration_changed, _update_hold],
		[slot.action_hold_cancelled, _on_slot_action_hold_ended],
		[slot.action_hold_progress_changed, _on_slot_action_hold_progress_changed],
		[slot.action_hold_started, _on_slot_action_hold_started],
		[slot.action_hold_triggered, _on_slot_action_hold_ended],
	]:
		if connected:
			Signals.connect_safe(pair[0], pair[1])
		else:
			Signals.disconnect_safe(pair[0], pair[1])


## _update_accessibility_name names the button by the origin bound to the action and
## its text, such as "Cross, Sell". With no origin it clears the name, so assistive tech
## reads the text alone.
func _update_accessibility_name() -> void:
	var origin := _glyph.get_origin_label()

	if not origin:
		accessibility_name = ""
	elif not text:
		accessibility_name = origin
	else:
		accessibility_name = tr(MSGID_ACTION_NAME).format(
			{&"origin": origin, &"action": text}
		)


## _update_glyph_action draws the glyph of the hold's `cancel_action` while a tapped
## toggle runs, and of `action` otherwise.
func _update_glyph_action() -> void:
	var drawn := action
	if _hold_tapped and _hold and _hold.cancel_action:
		drawn = _hold.cancel_action

	if _glyph.action != drawn:
		_glyph.action = drawn


## _update_hold reads the hold the slot runs on `action` and the mode it runs in, and
## shows them.
func _update_hold() -> void:
	_hold = _slot.get_action_hold(action) if _slot and action else null
	_hold_mode = StdInputActionHold.MODE_PRESS

	var properties: Array[StdSettingsPropertyInt] = []
	if _hold:
		_hold_mode = _slot.get_action_hold_mode(action)

		for property in [_slot.hold_mode_property, _hold.mode_override]:
			if property:
				properties.append(property)

	_set_mode_properties(properties)

	_update_glyph_action()
	_update_text()


## _update_size sets the glyph's height to a line of the button's text, times the
## theme's `THEME_GLYPH_SCALE_PERCENT`.
func _update_size() -> void:
	var line := get_theme_font(&"font").get_height(get_theme_font_size(&"font_size"))
	_glyph.size = roundi(line * _get_theme_int(THEME_GLYPH_SCALE_PERCENT, 100) / 100.0)


## _update_slot connects the button to the slot of `player_id` while it's in the tree.
func _update_slot() -> void:
	_set_slot(StdInputSlot.for_player(player_id) if is_inside_tree() else null)


## _update_text sets `text` while `use_action_text` is on, to the action's translated
## name or the prompt its hold's mode shows. It waits for the tree, so a scene's own
## `text` and `use_action_text` load first, and a button built in code has no text until
## it enters the tree.
func _update_text() -> void:
	if not _glyph or not is_inside_tree():
		return

	if not use_action_text or not action_set or not action:
		return

	var action_text := Locales.tr_action(action_set.name, action)

	if _hold_tapped:
		text = tr(MSGID_CANCEL)
	elif _hold_mode == StdInputActionHold.MODE_HOLD and hold_text:
		text = tr(hold_text).format({&"action": action_text})
	else:
		text = action_text

	_update_accessibility_name()


## _update_trigger adds the trigger which raises `action` while `raise_action` is on,
## and removes it otherwise. A trigger removed while held releases the action.
func _update_trigger() -> void:
	if not _glyph or not is_inside_tree():
		return

	var wanted := raise_action and action != &""

	if _trigger and (not wanted or _trigger.action != action):
		_trigger.free()
		_trigger = null

	if wanted and not _trigger:
		_trigger = StdInputActionTrigger.new()
		_trigger.action = action
		add_child(_trigger, false, INTERNAL_MODE_BACK)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_mode_property_value_changed(_value: Variant) -> void:
	_update_hold()


func _on_slot_action_hold_ended(hold_action: StringName) -> void:
	if hold_action == action:
		_reset_hold()


func _on_slot_action_hold_progress_changed(
	hold_action: StringName, progress: float
) -> void:
	if hold_action != action:
		return

	_hold_progress = progress
	queue_redraw()


func _on_slot_action_hold_started(hold_action: StringName) -> void:
	if hold_action != action or _hold_mode != StdInputActionHold.MODE_TOGGLE:
		return

	_hold_tapped = true

	_update_glyph_action()
	_update_text()
