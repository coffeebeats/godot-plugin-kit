##
## KitInputActionButton is a `Button` which stands for an input action. Its icon is the
## glyph of the origin bound to the action, its text is the action's translated name,
## and a click raises the action, so a key, a click and synthetic input share one
## handler. The glyph is as tall as a line of the button's text, so it follows the
## player's text size.
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

# -- DEFINITIONS --------------------------------------------------------------------- #

## MSGID_ACTION_NAME is the template for the button's accessible name, which joins the
## origin's name, as `{origin}`, and the button's text, as `{action}`.
const MSGID_ACTION_NAME := &"kit_input_action_name"

## THEME_GLYPH_SCALE_PERCENT is the theme constant giving the glyph's height as a
## percentage of a line of the button's text, read from the button's own types and then
## `THEME_TYPE`; 100 when neither has it.
const THEME_GLYPH_SCALE_PERCENT := &"glyph_scale_percent"

## THEME_TYPE is the theme type holding the button's own theme items.
const THEME_TYPE := &"KitInputActionButton"

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
			_glyph.action = value
			_update_text()
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

## focus_anchor is whether focus navigation may land on the button when its screen
## opens. It takes effect when the button enters the tree.
@export var focus_anchor: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

## _glyph is the texture which draws the action's glyph as `icon`.
var _glyph: StdInputGlyphTexture = null

## _trigger raises `action` on a click while `raise_action` is on.
var _trigger: StdInputActionTrigger = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_glyph returns the texture which draws the action's glyph as `icon`.
func get_glyph() -> StdInputGlyphTexture:
	return _glyph


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# NOTE: The handler registers as an anchor when it enters the tree, just after this.
	var handler := get_node_or_null(^"FocusHandler") as StdInputCursorFocusHandler
	if handler:
		handler.use_as_anchor = focus_anchor


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


## _get_glyph_scale returns the glyph's height in lines of the button's text.
func _get_glyph_scale() -> float:
	for theme_type in [&"", THEME_TYPE]:
		if has_theme_constant(THEME_GLYPH_SCALE_PERCENT, theme_type):
			return get_theme_constant(THEME_GLYPH_SCALE_PERCENT, theme_type) / 100.0

	return 1.0


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


## _update_size sets the glyph's height to a line of the button's text, times the
## theme's `THEME_GLYPH_SCALE_PERCENT`.
func _update_size() -> void:
	var line := get_theme_font(&"font").get_height(get_theme_font_size(&"font_size"))
	_glyph.size = roundi(line * _get_glyph_scale())


## _update_text sets `text` to the action's translated name while `use_action_text` is
## on. It waits for the tree, so a scene's own `text` and `use_action_text` load first,
## and a button built in code has no text until it enters the tree.
func _update_text() -> void:
	if not _glyph or not is_inside_tree():
		return

	if not use_action_text or not action_set or not action:
		return

	text = Locales.tr_action(action_set.name, action)
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
