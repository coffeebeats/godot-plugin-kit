##
## KitAlertDialog is a reusable confirmation or acknowledgment modal that manages its
## own screen lifecycle. Call `open()` to push the dialog onto the screen stack and
## await `closed` for the result.
##

@tool
class_name KitAlertDialog
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## closed is emitted after the dialog's screen is popped, carrying which button role the
## user selected.
@warning_ignore("unused_signal")
signal closed(action: KitAlertDialog.Action)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## TR_CONTEXT is the translation context for all alert dialog button labels.
const TR_CONTEXT := &"alert"

## Action identifies how the user closed the dialog.
enum Action {  # gdlint:ignore=class-definitions-order
	DISMISS,
	PRIMARY,
	SECONDARY,
}

# -- CONFIGURATION ------------------------------------------------------------------- #

## screen is the screen resource used when this dialog is pushed. Configure transitions
## and dependencies on this resource.
@export var screen: StdScreen

## title is the locale key for the title label. Hidden when empty.
@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_set_title(title)

## message is the locale key for the message label. Hidden when empty.
@export var message: String = "":
	set(value):
		message = value
		if is_node_ready():
			_set_message(message)

@export_group("Buttons")

## dismissable controls whether `ui_cancel` closes the dialog.
@export var dismissable: bool = true:
	set(value):
		dismissable = value
		if is_node_ready():
			set_process_unhandled_input(not Engine.is_editor_hint() and dismissable)

## primary_label is the locale key for the primary button.
@export var primary_label: String = "kit_alert_okay":
	set(value):
		primary_label = value
		if is_node_ready():
			_translate_buttons()

## secondary_label is the locale key for the secondary button. Hidden
## when empty.
@export var secondary_label: String = "kit_alert_cancel":
	set(value):
		secondary_label = value
		if is_node_ready():
			_translate_buttons()

# -- INITIALIZATION ------------------------------------------------------------------ #

## _screens is the screen manager this dialog was pushed onto.
var _screens: StdScreenManager = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## open pushes this dialog onto `screens`, which pops it again once the user answers.
func open(screens: StdScreenManager) -> void:
	assert(screen is StdScreen, "invalid config; missing screen")
	assert(screens is StdScreenManager, "invalid argument; missing screen manager")

	_screens = screens
	_screens.push(screen, self)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not screen is StdScreen:
		warnings.append("KitAlertDialog requires a StdScreen resource.")
	return warnings


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_translate_buttons()

	# Re-translate on tree entry in case locale changed while off-tree. Guard with
	# `is_node_ready()` to skip first entry (handled by `_ready`).
	if what == NOTIFICATION_ENTER_TREE and is_node_ready():
		_translate_buttons()


func _ready() -> void:
	assert(%Title is Label, "invalid state; missing %%Title node")
	assert(%Message is Label, "invalid state; missing %%Message node")

	set_process_unhandled_input(not Engine.is_editor_hint() and dismissable)

	%Primary.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	%Secondary.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED

	_set_title(title)
	_set_message(message)
	_translate_buttons()

	if Engine.is_editor_hint():
		return

	Signals.connect_safe(%Primary.pressed, _on_button_pressed.bind(Action.PRIMARY))
	Signals.connect_safe(%Secondary.pressed, _on_button_pressed.bind(Action.SECONDARY))
	Signals.connect_safe(screen.popped, _on_screen_popped)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_button_pressed(Action.DISMISS)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _set_message(text: String) -> void:
	%Message.text = text
	%Message.visible = text != ""


func _set_title(text: String) -> void:
	%Title.text = text
	%Title.visible = text != ""


func _translate_buttons() -> void:
	%Primary.text = tr(primary_label, TR_CONTEXT)

	var has_secondary := secondary_label != ""
	%Secondary.text = tr(secondary_label, TR_CONTEXT) if has_secondary else ""
	%Secondary.visible = has_secondary


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_button_pressed(action: Action) -> void:
	assert(
		_screens.is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	_screens.pop(action, true)


func _on_screen_popped(result: Variant) -> void:
	closed.emit(result if result != null else Action.DISMISS)
