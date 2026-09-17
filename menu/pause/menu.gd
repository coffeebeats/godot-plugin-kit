##
## KitPauseMenu is a modal pause menu shown during gameplay. It provides options to
## resume, open settings, return to the main menu, or quit the game.
##
## Returning to the main menu is the game's own flow, so the game sets it once on
## `return_to_main_menu`; until then, the menu hides that option. Quitting calls
## `Lifecycle.shutdown`, so a game saves its progress on `shutdown_requested`.
##

class_name KitPauseMenu
extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Screens := preload("../../ui/menu/screens.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## return_to_main_menu is the game's flow for leaving gameplay for its main menu, called
## once the player confirms. The menu shows its return option only while this is valid.
static var return_to_main_menu: Callable = Callable()

## confirm_quit_scene is the confirmation dialog shown before quitting the application.
@export var confirm_quit_scene: PackedScene

## confirm_return_scene is the confirmation dialog shown before returning to the main
## menu.
@export var confirm_return_scene: PackedScene

## settings_screen is the screen resource for the settings menu.
@export var settings_screen: StdScreen

# -- INITIALIZATION ------------------------------------------------------------------ #

var _confirm_quit: KitAlertDialog
var _confirm_return: KitAlertDialog
@onready var _options: Button = %Options
@onready var _quit: Button = %Quit
@onready var _resume: Button = %Resume
@onready var _return: Button = %Return

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(_confirm_quit):
			_confirm_quit.free()
			_confirm_quit = null
		if is_instance_valid(_confirm_return):
			_confirm_return.free()
			_confirm_return = null


func _ready() -> void:
	_confirm_quit = confirm_quit_scene.instantiate()
	_confirm_return = confirm_return_scene.instantiate()

	Signals.connect_safe(_options.pressed, _on_options_pressed)
	Signals.connect_safe(_quit.pressed, _on_quit_pressed)
	Signals.connect_safe(_resume.pressed, _on_resume_pressed)
	Signals.connect_safe(_return.pressed, _on_return_pressed)

	_return.visible = return_to_main_menu.is_valid()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_options_pressed() -> void:
	Screens.find_manager(self).push(settings_screen)


func _on_quit_pressed() -> void:
	_confirm_quit.open(Screens.find_manager(self))
	var action: KitAlertDialog.Action = await _confirm_quit.closed
	if action != KitAlertDialog.Action.PRIMARY:
		return

	# NOTE: Defer shutdown so the screen manager finishes its pop operation first.
	Lifecycle.shutdown.call_deferred()


func _on_resume_pressed() -> void:
	var screens := Screens.find_manager(self)
	assert(screens.get_scene() == self, "invalid state; this scene is not topmost")
	screens.pop()


func _on_return_pressed() -> void:
	_confirm_return.open(Screens.find_manager(self))
	var action: KitAlertDialog.Action = await _confirm_return.closed
	if action != KitAlertDialog.Action.PRIMARY:
		return

	return_to_main_menu.call()
