##
## SystemInput is the global singleton scene for handling user input via action binding.
##

extends KitModule

# -- SIGNALS ------------------------------------------------------------------------- #

## about_to_grab_focus is emitted when `node` is about to grab focus, with `trigger` the
## input action that caused it, or empty if no action did.
signal about_to_grab_focus(node: Control, trigger: StringName)

## cursor_visibility_changed is emitted when the visibility of the application's cursor
## changes.
signal cursor_visibility_changed(visible: bool)

## focus_root_changed is emitted when the focus root changes, with `root` as `null` if
## the focus root was cleared.
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

## GROUP_INPUT_SHIM is the group holding the one input system node in the tree.
const GROUP_INPUT_SHIM := &"system/input:shim"

## MODULE_ID is the ID the input system registers under as a `KitModule`.
const MODULE_ID := &"input"

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_sets are the game's action sets, which the settings menu's controls tabs list
## for rebinding above kit's own. The settings menu loads at runtime, out of reach of
## the scene placing this node, so it reads the value here.
##
## NOTE: On Steam builds the Steam joypad monitor also reads a controller's binding
## against these, and a controller binding only a left-out set's actions looks opted out
## of the Steam Input API.
@export var action_sets: Array[StdInputActionSet] = []

## menu_options_layers are the game's layers over its own sets which carry kit's
## `MenuOptions` actions, such as `ui_toggle_menu` for the pause and settings pushers.
## A rebind in the controls tabs' `MenuOptions` group writes to each one declaring it,
## so list them here and not in `action_sets`.
@export var menu_options_layers: Array[StdInputActionSetLayer] = []

## kit_action_sets are kit's own sets and layers, those of its menus and splash screens,
## validated with the game's. Kit's scene sets them.
##
## NOTE: Stored in the scene but hidden from the inspector, so a game doesn't add its
## own sets here; those belong in `action_sets` or `menu_options_layers`.
@export_storage var kit_action_sets: Array[StdInputActionSet] = []

## focused_sound_group is the sound group used for focused UI elements.
@export var focused_sound_group: StdSoundGroup = null

## glyph_sets are the glyph sets prompts draw origins from, searched in order for the
## first matching set with art for an origin, so a game's set placed ahead of kit's
## replaces part of a family.
##
## NOTE: They're read once, when the input implementation loads. On Steam builds they
## draw only the keyboard and the joypads Steam Input isn't driving.
@export var glyph_sets: Array[StdInputGlyphSet] = []

## origin_names are the translation keys naming each origin, which a screen reader reads
## for a prompt, searched as `glyph_sets` are, so a game's names placed ahead of kit's
## replace part of a family. Each value must be a key with a translation, not the text.
##
## NOTE: They're read once, when the input implementation loads. On Steam builds they
## name only the keyboard and the joypads Steam Input isn't driving.
@export var origin_names: Array[StdInputOriginNames] = []

## unknown_glyph is the glyph prompts draw for a bound origin with no art, in the glyph
## sets or in Steam Input. A prompt showing origin names shows the name instead where
## the origin has one. Left empty, such a prompt shows its label instead.
##
## NOTE: It's read once, when the input implementation loads.
@export var unknown_glyph: Texture2D = null

## ui_navigation_cooldown is a wait period after a UI navigation press moves focus which
## must elapse before another one is accepted, so a key's repeat or a stick wavering at
## its deadzone can't race through a menu.
##
## NOTE: A press which moves no focus, such as left or right in a vertical list, starts
## no cooldown, so it can't swallow the next press.
@export var ui_navigation_cooldown: float = 0.08

# -- INITIALIZATION ------------------------------------------------------------------ #

## _cursor is the scene's one input cursor, found once the node is ready.
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


## is_cursor_visible returns whether the cursor is currently visible, so it tells
## whether focus-based navigation is in effect.
func is_cursor_visible() -> bool:
	return _cursor.get_is_visible()


## is_using_focus_ui_navigation returns whether the game is currently using focus-based
## UI navigation, which it does while the mouse cursor is hidden.
func is_using_focus_ui_navigation() -> bool:
	return not _cursor.get_is_visible()


## mute_next_focus_sound suppresses the next focus or hover sound event. The sound group
## unmutes once that focus change settles, or by the next frame if focus never moves.
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

	if not StdInputActionSet.validate(_list_action_sets()):
		_report_failed("invalid action sets")
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


## _list_action_sets returns kit's sets and layers followed by the game's, each listed
## once.
func _list_action_sets() -> Array[StdInputActionSet]:
	var listed: Array[StdInputActionSet] = []

	for action_set in kit_action_sets + action_sets + menu_options_layers:
		if action_set not in listed:
			listed.append(action_set)

	return listed


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
