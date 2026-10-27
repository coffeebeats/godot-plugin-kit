##
## SystemInput is the global singleton scene for handling user input via action binding.
##

extends KitModule

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
const Profile := preload("../../platform/profile/profile.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_SHIM := &"system/input:shim"

## MODULE_ID is the ID the input system registers under as a `KitModule`.
const MODULE_ID := &"input"

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_sets are the game's action sets, which the settings menu's controls tab lists
## for rebinding above kit's own. The settings menu loads at runtime, out of reach of
## the scene placing this node, so it reads the value here.
@export var action_sets: Array[StdInputActionSet] = []

## focused_sound_group is the sound group used for focused UI elements.
@export var focused_sound_group: StdSoundGroup = null

## ui_navigation_cooldown is a wait period after a UI navigation press moves focus which
## must elapse before another one is accepted, so a key's repeat or a stick wavering at
## its deadzone can't race through a menu.
##
## NOTE: A press which moves no focus, such as left or right in a vertical list, starts
## no cooldown, so it can't swallow the next press.
@export var ui_navigation_cooldown: float = 0.08

# -- INITIALIZATION ------------------------------------------------------------------ #

var _cursor: StdInputCursor = null

## _ui_navigation_cooldown_end is the time, in milliseconds since launch, at which
## `ui_navigation_cooldown` ends.
var _ui_navigation_cooldown_end: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_active_device returns the currently active input device for the specified player.
func get_active_device(player_id: int = 1) -> StdInputDevice:
	var slot := StdInputSlot.for_player(player_id)
	if not slot:
		assert(false, "invalid state; missing input slot for player")
		return null

	var device := slot.get_active_device()
	assert(device, "invalid state; missing device for input slot")
	return device


## get_input_slot returns the input slot for the specified player.
func get_input_slot(player_id: int = 1) -> StdInputSlot:
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
	# NOTE: The sound group is the game's to supply. With none there is nothing to mute.
	if not focused_sound_group:
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
		if Time.get_ticks_msec() < _ui_navigation_cooldown_end:
			get_viewport().set_input_as_handled()
			return

		# NOTE: The GUI moves focus after this callback, so focus is compared once the
		# press is handled.
		var focus := get_viewport().gui_get_focus_owner()
		_start_navigation_cooldown.call_deferred(
			focus.get_instance_id() if focus else 0
		)


func _ready() -> void:
	var cursors := StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR).list_members()
	if cursors.size() != 1:
		_report_failed("found %d input cursors, expected 1" % cursors.size())
		return

	if not StdInputSlot.for_player(1):
		_report_failed("missing the first player's input slot")
		return

	_cursor = cursors[0]

	# Forward the `StdInputCursor` events.
	Signals.connect_safe(_cursor.about_to_grab_focus, about_to_grab_focus.emit)
	Signals.connect_safe(
		_cursor.cursor_visibility_changed, cursor_visibility_changed.emit
	)
	Signals.connect_safe(_cursor.focus_root_changed, focus_root_changed.emit)

	_report_loaded()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID


func _get_module_requires() -> Array[StringName]:
	return [Profile.MODULE_ID]


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _start_navigation_cooldown starts `ui_navigation_cooldown` if focus has moved off the
## control whose instance ID is `focus_id`, or `0` for none.
func _start_navigation_cooldown(focus_id: int) -> void:
	if not is_inside_tree():
		return

	var focus := get_viewport().gui_get_focus_owner()
	if (focus.get_instance_id() if focus else 0) == focus_id:
		return

	_ui_navigation_cooldown_end = (
		Time.get_ticks_msec() + roundi(ui_navigation_cooldown * 1000.0)
	)
