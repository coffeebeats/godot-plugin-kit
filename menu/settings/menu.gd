##
## SettingsMenu is a full settings menu with the ability to read and write user/game
## preferences. Designed as a standalone Control pushed via StdScreenManager.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const TabGroup := preload("../../ui/menu/tab_group.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Feedback")

## tab_switch_sound_event is a sound event which will be played when switching tabs.
@export var tab_switch_sound_event: StdSoundEvent1D = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _tab_switch_muted: bool = false

@onready var _tab_group: TabGroup = %TabGroup

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if not is_node_ready():
		return  # First enter; _ready() handles initial state.

	# A re-entry pushes a cached instance, so reset to the default tab without its sound.
	_tab_switch_muted = true
	_tab_group.select(_tab_group.default_tab)
	(func() -> void: _tab_switch_muted = false).call_deferred()


func _ready() -> void:
	assert(_tab_group is TabGroup, "invalid state; missing control node")

	Signals.connect_safe(_tab_group.tab_changed, _on_tab_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_next"):
		_tab_group.select_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_prev"):
		_tab_group.select_previous()
		get_viewport().set_input_as_handled()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_tab_changed(_index: int) -> void:
	if not KitSystems.input().is_cursor_visible():
		KitSystems.input().mute_next_focus_sound()

	if not _tab_switch_muted and tab_switch_sound_event:
		KitSystems.audio().play(tab_switch_sound_event)
