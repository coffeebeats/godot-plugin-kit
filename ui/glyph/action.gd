##
## KitInputActionPrompt is a UI element which displays a glyph with an action label,
## acting as a prompt for an action that a user can also click to execute.
##

@tool
class_name KitInputActionPrompt
extends PanelContainer

# -- SIGNALS ------------------------------------------------------------------------- #

## pressed is emitted when this action prompt is pressed. This will be emitted just
## prior to the action being sent to the scene tree if `trigger_action_on_press` is set.
signal pressed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Locales := preload("../../locale/locales.gd")
const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set is an input action set for the `Glyph`.
@export var action_set: StdInputActionSet = null:
	set(value):
		action_set = value
		if _glyph:
			_glyph.action_set = value

## action is an action within the action set for the `Glyph`.
@export var action: StringName = "":
	set(value):
		action = value
		if _glyph:
			_glyph.action = value

## action_text overrides the text used for the action's label. When empty, `action` is
## used as the label text instead.
@export var action_text: StringName = ""

## binding_index is the index of the binding to show for the `Glyph`.
@export var binding_index: int = 0:
	set(value):
		binding_index = value
		if _glyph:
			_glyph.binding_index = value

## player_id is the player for which to show the origin binding for.
@export var player_id: int = 1:
	set(value):
		player_id = value
		if _glyph:
			_glyph.player_id = value

@export_subgroup("Behavior")

## trigger_action_on_press controls whether the configured action will be emitted to the
## scene tree upon click. The `button_mask` property can be used to select which mouse
## buttons can be used to click this action prompt.
##
## NOTE: If `button_mask` is empty, this property will be ignored.
@export var trigger_action_on_press: bool = false

## button_mask is a bitfield of `MouseButtonMask` values which, when the action prompt
## is clicked with one of the matching mouse buttons, will cause the action to be
## emitted.
##
## NOTE: This property is dependent on the action prompt receiving input (i.e. the
## `mouse_filter` property must not be `MOUSE_FILTER_IGNORE`).
@export_flags("Left:1", "Right:2", "Middle:4", "Extra1:128", "Extra2:256")
var button_mask: int = MOUSE_BUTTON_MASK_LEFT:
	set(value):
		if value <= 0 and trigger_action_on_press:
			trigger_action_on_press = false

		button_mask = value

@export_group("Animation")

@export_subgroup("Border Fade")

## border_fade_in is an incoming fade animation to apply to the node's border. The
## border color will be faded from transparent *to* the color set on the node's
## `StyleboxFlat` theme override.
##
## NOTE: This property will have no effect if the `panel`'s stylebox is not a
## `StyleboxFlat`. Additionally, the `color` property will override the stylebox's.
@export var border_fade_in: KitAnimationBorderFade = null

## border_fade_out is an outgoing fade animation to apply to the node's border. The
## border color will be faded from the color set on the node's `StyleboxFlat` theme
## override *to* transparent.
##
## NOTE: This property will have no effect if the `panel`'s stylebox is not a
## `StyleboxFlat`. Additionally, the `color` property will override the stylebox's.
@export var border_fade_out: KitAnimationBorderFade = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _border_color: Color = Color.TRANSPARENT
var _hovered: bool = false
var _tween: Tween = null

@onready var _glyph: KitInputGlyph = %Glyph
@onready var _label: Label = %Label

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or get_viewport().is_input_handled():
		return

	# See https://github.com/godotengine/godot/issues/84466.
	if not _hovered:
		return

	var event_button_mask: int = 1 << (event.button_index - 1)
	if event_button_mask & button_mask:
		get_viewport().set_input_as_handled()

		if event.is_released():
			pressed.emit()

			if trigger_action_on_press:
				StdInputEvent.trigger_action(action, event.device)


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Set these properties on the scene's `Glyph` node.
	action_set = action_set
	action = action
	binding_index = binding_index
	player_id = player_id

	assert(_label is Label, "invalid state; missing label node")
	var text := action_text if action_text else action
	_label.text = Locales.tr_action(action_set.name, text)

	var stylebox: StyleBoxFlat = get_theme_stylebox(&"panel")
	if stylebox is StyleBoxFlat and (border_fade_in or border_fade_out):
		_border_color = stylebox.border_color

		Signals.connect_safe(mouse_entered, _on_mouse_state_changed.bind(true))
		Signals.connect_safe(mouse_exited, _on_mouse_state_changed.bind(false))

		if border_fade_out:
			stylebox.border_color = border_fade_out.color


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_mouse_state_changed(hovered: bool) -> void:
	_hovered = hovered

	if _tween:
		_tween.kill()
		_tween = null

	var stylebox: StyleBoxFlat = get_theme_stylebox(&"panel")
	assert(stylebox is StyleBoxFlat, "invalid state; missing stylebox")

	if hovered and border_fade_in:
		_tween = create_tween()
		border_fade_in.apply_tween_property(_tween, stylebox)
		return

	if not hovered and border_fade_out:
		_tween = create_tween()
		border_fade_out.apply_tween_property(_tween, stylebox)
		return

	stylebox.border_color = _border_color
