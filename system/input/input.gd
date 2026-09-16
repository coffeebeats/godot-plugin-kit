##
## system/input/input.gd
##
## SystemInput is the global singleton scene for handling user input via action binding.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

signal about_to_grab_focus(node: Control, trigger: StringName)

## cursor_visibility_changed is emitted when the visibility of the application's cursor
## changes.
signal cursor_visibility_changed(visible: bool)

## focus_root_changed is emitted when the focus root changes. Note that `root` may be
## `null` if the root focus was cleared.
signal focus_root_changed(root: Control)

# -- DEPENDENCIES -------------------------------------------------------------------- #

# NOTE: Shadowing this variable prevents an error observed when returning this type from
# a function. The error, "ERROR: Condition "p_elem->_root != this" is true.", is only
# seen during tests and re-importing project resources.
@warning_ignore("SHADOWED_GLOBAL_IDENTIFIER")
const StdInputDevice := preload("res://addons/std/input/device.gd")
const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_SHIM := &"system/input:shim"

# -- CONFIGURATION ------------------------------------------------------------------- #

## focused_sound_group is the sound group used for focused UI elements.
@export var focused_sound_group: StdSoundGroup = null

## ui_navigation_cooldown is a wait period after inputting a UI navigation action that
## must elapse prior to another one being accepted.
@export var ui_navigation_cooldown: float = 0.08

# -- INITIALIZATION ------------------------------------------------------------------ #

var _cursor: StdInputCursor = null
var _ui_navigation_cooldown: float = 0.0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_active_device returns the currently active input device for the specified player.
func get_active_device(player_id: int = 0) -> StdInputDevice:
	var slot := StdInputSlot.for_player(player_id)
	if not slot:
		assert(false, "invalid state; missing input slot for player")
		return null

	var device := slot.get_active_device()
	assert(device, "invalid state; missing device for input slot")
	return device


## get_input_slot returns the input slot for the specified player.
func get_input_slot(player_id: int = 0) -> StdInputSlot:
	return StdInputSlot.for_player(player_id)


## is_cursor_visible returns whether the cursor is currently visible. This can be used
## to check whether focus-based navigation is in effect.
func is_cursor_visible() -> bool:
	return _cursor.get_is_visible()


## is_using_focus_ui_navigation returns whether the game is currently using focus-based
## UI navigation (i.e. the mouse cursor is hidden).
func is_using_focus_ui_navigation() -> bool:
	return not _cursor.get_is_visible()


## mute_next_focus_sound suppresses the next focus or hover sound event. The sound group
## is unmuted after the first focus change settles; a `process_frame` fallback
## guarantees cleanup if no focus change occurs (e.g. cursor mode).
func mute_next_focus_sound() -> void:
	if not focused_sound_group:
		assert(false, "invalid config; missing focused sound group")
		return

	focused_sound_group.mute()

	var is_unmuted := [false]
	var unmute := func() -> void:
		if not is_unmuted[0]:
			is_unmuted[0] = true
			focused_sound_group.unmute()

	var on_focus_changed := func(_node: Control) -> void: unmute.call_deferred()

	var gui_focus_changed := get_viewport().gui_focus_changed
	Signals.connect_safe(gui_focus_changed, on_focus_changed, CONNECT_ONE_SHOT)

	# Unmute at the next idle frame if the one-shot hasn't fired. By `process_frame`,
	# all deferred calls from the muting frame have flushed.
	Signals.connect_safe(
		get_tree().process_frame,
		func() -> void:
			Signals.disconnect_safe(gui_focus_changed, on_focus_changed)
			unmute.call_deferred(),
		CONNECT_ONE_SHOT,
	)


## set_focus_root restricts UI focus to be under the scene subtree rooted at `root`.
## Call this with `null` to unset the focus root.
func set_focus_root(root: Control = null) -> void:
	_cursor.set_focus_root(root)


## show_cursor reveals the cursor and transitions to mouse-based navigation. If the
## cursor is already visible, then nothing happens.
func show_cursor() -> void:
	_cursor.show_cursor()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_INPUT_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_INPUT_SHIM).add_member(self)

	set_process(false)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_SHIM).remove_member(self)


func _input(event: InputEvent) -> void:
	if not event.is_action_type():
		return

	if (
		event.is_action_pressed(&"ui_up", true)
		or event.is_action_pressed(&"ui_right", true)
		or event.is_action_pressed(&"ui_down", true)
		or event.is_action_pressed(&"ui_left", true)
	):
		if is_processing():
			get_viewport().set_input_as_handled()
			return

		_ui_navigation_cooldown = ui_navigation_cooldown
		set_process(true)


func _process(delta: float) -> void:
	# Try to normalize the rate of UI inputs by treating anything below one frame
	# as successfully completed.
	if _ui_navigation_cooldown < (1.0 / Engine.get_frames_per_second() / 2.0):
		set_process(false)
		return

	_ui_navigation_cooldown -= delta


func _ready() -> void:
	_cursor = StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is StdInputCursor, "invalid state; missing input cursor")

	# Forward the `StdInputCursor` events.
	Signals.connect_safe(_cursor.about_to_grab_focus, about_to_grab_focus.emit)
	Signals.connect_safe(
		_cursor.cursor_visibility_changed, cursor_visibility_changed.emit
	)
	Signals.connect_safe(_cursor.focus_root_changed, focus_root_changed.emit)
