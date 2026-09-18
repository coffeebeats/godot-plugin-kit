##
## Rebinder is a floating overlay which handles rebinding a configured input action.
## Uses a static instance pushed via `StdScreenManager`. Binding nodes delegate to
## `Rebinder.start_rebinding()` to initiate a rebind.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("res://addons/std/input/godot/binding.gd")
const Signals := preload("res://addons/std/event/signal.gd")
const Locales := preload("../../../locale/locales.gd")
const Screens := preload("../../../ui/menu/screens.gd")
const Rebinder := preload("rebinder.gd")
const RebinderScene := preload("rebinder.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_REBINDER := &"menu/settings:rebinder"

const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

const MSGCTXT_REBINDER_KEYBOARD := &"keyboard"
const MSGCTXT_REBINDER_GAMEPAD := &"gamepad"
const MSGID_REBINDER_TITLE := &"kit_options_controls_rebinder_title"
const MSGID_REBINDER_INSTRUCTIONS := &"kit_options_controls_rebinder_bind_or_exit"

# -- CONFIGURATION ------------------------------------------------------------------- #

## screen is the `StdScreen` describing how the `Rebinder` is pushed/popped from the
## screen stack.
@export var screen: StdScreen = null

# -- INITIALIZATION ------------------------------------------------------------------ #

# FIXME: This instance needs to be freed on game exit.
static var _instance: Rebinder = null  # gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create(&"menu/settings/rebinder")  # gdlint:ignore=class-definitions-order,max-line-length

var _action_set: StdInputActionSet = null
var _action: StringName = &""
var _binding_index := StdInputDeviceActions.BINDING_INDEX_PRIMARY
var _cursor_was_visible: bool = false
var _device: StdInputDevice = null
var _player: int = -1
var _scope: StdSettingsScope = null

@onready var _label_action: Label = %Action
@onready var _label_glyph: StdInputGlyph = %Glyph
@onready var _label_instructions_pre: Label = %InstructionsPre
@onready var _label_instructions_post: Label = %InstructionsPost

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## start_rebinding begins the rebinding process for the specified action and player,
## pushing the rebinder screen onto the given screen manager.
static func start_rebinding(
	screens: StdScreenManager,
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	action: StringName,
	binding_index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
	player: int = 1,
) -> bool:
	assert(screens is StdScreenManager, "invalid argument; missing screen manager")

	var slot := StdInputSlot.for_player(player)
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	var device := slot.get_active_device()
	if not device:
		return false

	if not _instance:
		_instance = RebinderScene.instantiate()

	_instance._cursor_was_visible = KitSystems.input().is_cursor_visible()

	_instance._scope = scope
	_instance._action_set = action_set
	_instance._action = action
	_instance._binding_index = binding_index
	_instance._player = player
	_instance._device = device

	# NOTE: The instance is reused across rebinds, so a prior `stop` may have left this
	# connected.
	Signals.ensure_connected(slot.device_activated, _instance._on_device_activated)

	screens.push(_instance.screen, _instance)

	return true


## stop terminates the rebinding process, halting input event listeners and popping the
## rebinder screen.
func stop(bound: bool = false) -> void:
	# NOTE: Restore cursor visibility *before* popping the screen. The rebind key press
	# may have triggered cursor hiding (the cursor's '_input' processes key events as
	# hide actions). Restoring here prevents focus mode from activating during the
	# screen close sequence.
	if _cursor_was_visible:
		KitSystems.input().show_cursor()

	set_process_input(false)

	(
		_logger
		. debug(
			"Stopped listening for key bindings.",
			{
				&"action": _action,
				&"action_set": _action_set.name if _action_set else &""
			},
		)
	)

	# NOTE: The rebinder defines no close action, so the screen must pop even without a
	# slot; only the disconnect depends on one.
	var slot := StdInputSlot.for_player(_player)
	assert(slot is StdInputSlot, "invalid state; missing input slot")

	if slot:
		Signals.disconnect_safe(slot.device_activated, _on_device_activated)

	_scope = null
	_action_set = null
	_action = &""
	_binding_index = StdInputDeviceActions.BINDING_INDEX_PRIMARY
	_cursor_was_visible = false
	_device = null
	_player = -1

	Screens.find_manager(self).pop(bound)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_REBINDER).remove_member(self)


func _input(event: InputEvent) -> void:
	if not event.is_action_type() or not event.is_pressed():
		return

	if not _device:
		assert(false, "invalid state; missing device")
		stop()
		return

	# FIXME: This will block valid actions.
	if event is InputEventAction:
		get_viewport().set_input_as_handled()
		return

	# NOTE: Let this event through so that the other device can be activated.
	if not _device.is_matching_event_origin(event):
		return

	if event.is_action_pressed("ui_binding_stop"):
		get_viewport().set_input_as_handled()
		stop()
		return

	if not _action_set.is_matching_event_origin(_action, event):
		get_viewport().set_input_as_handled()
		return

	(
		Bindings
		. bind_action(
			_scope,
			_action_set,
			_action,
			event,
			_device.device_category,
			_binding_index,
		)
	)

	get_viewport().set_input_as_handled()
	stop(true)


func _enter_tree() -> void:
	assert(
		StdGroup.is_empty(GROUP_REBINDER),
		"invalid state; found dangling binding prompt",
	)
	StdGroup.with_id(GROUP_REBINDER).add_member(self)

	# NOTE: On subsequent pushes _ready() won't fire again, so activate here. On the
	# first push, _ready() handles activation instead.
	if is_node_ready():
		_activate()


func _ready() -> void:
	assert(screen is StdScreen, "invalid config; missing screen")

	set_process_input(false)
	_activate()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _activate enables input processing and updates the prompt UI. Called from tree
## lifecycle methods (`_ready` on first push, `_enter_tree` on subsequent pushes).
func _activate() -> void:
	assert(not is_processing_input(), "invalid state; already processing input")
	set_process_input(true)

	_update_prompt()

	(
		_logger
		. debug(
			"Starting listening for new key binding.",
			{
				&"action": _action,
				&"action_set": _action_set.name if _action_set else &""
			},
		)
	)


## _split_placeholder splits a translated template around its `%s`, returning the text
## before and after it. A template carrying no placeholder yields the whole string and
## an empty remainder, leaving the glyph's neighbours to render what there is.
##
## NOTE: A `Control` cannot sit within a `Label`'s text, so the instructions span two
## labels with the glyph between them; only a caller placing a node needs this.
static func _split_placeholder(template: String) -> PackedStringArray:
	var parts := template.split("%s", true, 1)
	return parts if parts.size() > 1 else PackedStringArray([template, ""])


func _update_prompt() -> void:
	_label_glyph.player_id = _player
	_label_glyph.update()

	# NOTE: The title is one label, so format it; a template which lost its placeholder
	# then reports an error and renders alone, rather than silently trailing the action.
	var action_set_name := _action_set.name if _action_set else &""
	_label_action.text = (
		tr(MSGID_REBINDER_TITLE) % Locales.tr_action(action_set_name, _action)
	)

	var instructions := _split_placeholder(
		tr(
			MSGID_REBINDER_INSTRUCTIONS,
			(
				MSGCTXT_REBINDER_KEYBOARD
				if _device.device_type == DEVICE_TYPE_KEYBOARD
				else MSGCTXT_REBINDER_GAMEPAD
			),
		)
	)

	_label_instructions_pre.text = instructions[0]
	_label_instructions_post.text = instructions[1]


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_device_activated(device: StdInputDevice) -> void:
	_device = device
	_update_prompt()
