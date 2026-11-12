##
## Tests for the alert shown over gameplay, opened over kit's 2D map template on a
## screen manager and driven with real keys and clicks.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ButtonScene := preload("res://ui/input/button.tscn")
const DialogScene := preload("res://ui/menu/alert_gameplay.tscn")
const MapScene := preload("res://map/2d/scene.tscn")
const Menu := preload("res://system/input/actions/menu.tres")
const MenuOptions := preload("res://system/input/actions/menu_options.tres")
const PauseScreen := preload("res://menu/pause/screen.tres")
const PlatformScene := preload("res://premade/platform.tscn")
const SettingsSystem := preload("res://system/setting/settings.gd")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _GAME_ACTIONS are the actions in kit's sets which the game binds, so kit's own input
## map lacks them. The pause screen builds the settings menu, whose rows read them.
const _GAME_ACTIONS: Array[StringName] = [
	&"ui_binding_stop", &"ui_tab_next", &"ui_tab_prev"
]

## _TIMEOUT is how long, in seconds, a test waits for a screen to finish entering or
## leaving.
const _TIMEOUT := 5.0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _actions: Array[KitAlertDialog.Action] = []
var _dialog: KitAlertDialog = null
var _gameplay: StdInputActionSet = null
var _hud: Button = null
var _input: StdTestInput = null
var _manager: StdTestScreenManager = null

## _preparation holds what opening the alert needs loaded, as a game holds it, so the
## alert opens at once.
var _preparation: StdScreenManager.Preparation = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_alert_gameplay_open_shows_the_outcome_and_primary_closes_it() -> void:
	# Given: An alert open over a map, with the cursor hidden.
	await _open()
	var slot := StdInputSlot.for_player(1)

	# Then: Its outcome and message show, and its primary action holds focus.
	assert_eq(_dialog.get_node(^"%Title").text, "Victory")
	assert_eq(_dialog.get_node(^"%Message").text, "Score: 100")
	assert_eq(_focus_owner(), _dialog.get_node(^"%Primary"))

	# Then: Kit's menu set is loaded with its options layer.
	assert_eq(slot.actions.get_action_set(slot.device_id), Menu)
	assert_has(slot.list_action_set_layers(), MenuOptions)

	# When: Enter is pressed.
	_press(KEY_ENTER)
	await wait_until(func() -> bool: return not _actions.is_empty(), _TIMEOUT)

	# Then: It closes with its primary action, and the map's set is loaded again.
	assert_eq(_actions, [KitAlertDialog.Action.PRIMARY] as Array[KitAlertDialog.Action])
	assert_eq(slot.actions.get_action_set(slot.device_id), _gameplay)


func test_alert_gameplay_key_during_its_entrance_does_not_press_it() -> void:
	# Given: An alert opened over a map, with the cursor hidden.
	await _mount()
	var screen := _dialog.screen
	_dialog.open(_manager)

	# Given: Its fade-in held where it starts, however slowly frames arrive.
	var tweens := get_tree().get_processed_tweens()
	for tween in tweens:
		tween.pause()

	await wait_process_frames(1)

	# Given: The alert is still entering, with its primary action focused.
	assert_signal_not_emitted(screen, "entered")
	assert_eq(_focus_owner(), _dialog.get_node(^"%Primary"))

	# When: Enter is pressed.
	_press(KEY_ENTER)

	# When: The fade-in runs to its end.
	for tween in tweens:
		tween.play()

	await wait_for_signal(screen.entered, _TIMEOUT)

	# Then: The alert stays open.
	assert_true(_manager.is_current(screen))
	assert_signal_not_emitted(screen, "exiting")


func test_alert_gameplay_escape_pushes_the_pause_menu_over_it() -> void:
	# Given: An alert open over a map.
	await _open()

	# When: Escape is pressed.
	_press(KEY_ESCAPE)
	await wait_until(_manager.is_current.bind(PauseScreen), _TIMEOUT)

	# Then: The pause menu covers the alert, which stays open.
	assert_true(_manager.is_current(PauseScreen))
	assert_signal_not_emitted(_dialog.screen, "exiting")

	# When: Escape is pressed again.
	_press(KEY_ESCAPE)
	await wait_until(_manager.is_current.bind(_dialog.screen), _TIMEOUT)

	# Then: The pause menu closes over the alert, which stays open.
	assert_true(_manager.is_current(_dialog.screen))
	assert_signal_not_emitted(_dialog.screen, "exiting")


func test_alert_gameplay_cancel_or_a_click_on_the_hud_leaves_it_open() -> void:
	# Given: An alert open over a map, with a HUD button under it.
	await _open()
	var presses := [0]
	_hud.pressed.connect(func() -> void: presses[0] += 1)

	# When: Cancel is pressed, as a gamepad's back button does.
	_input.press_action(&"ui_cancel")
	_input.release_action(&"ui_cancel")
	await wait_process_frames(1)

	# Then: The alert stays open.
	assert_signal_not_emitted(_dialog.screen, "exiting")

	# When: The HUD button is clicked.
	_input.click(_hud)

	# Then: The button isn't pressed, and the alert stays open.
	assert_eq(presses[0], 0)
	assert_signal_not_emitted(_dialog.screen, "exiting")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action: StringName in _GAME_ACTIONS + [&"ui_toggle_menu"]:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)


func after_each() -> void:
	# NOTE: The game frees its main scene before the input autoload, so the mounted
	# manager goes first here too, while the slot its loaders hold still exists.
	if is_instance_valid(_input):
		_input.free()

	_preparation = null

	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


func before_all() -> void:
	# NOTE: std reads an action's defaults from the project settings, so each action is
	# added there as well as to the input map, as a game's project defines it.
	for action in _GAME_ACTIONS:
		ProjectSettings.set_setting(&"input/" + action, {"deadzone": 0.5, "events": []})
		InputMap.add_action(action)

	# NOTE: Kit's own project defines no actions, and the options layer names this one;
	# a game defines it with a default binding, which the Godot backend reads here.
	InputMap.add_action(&"ui_toggle_menu")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	ProjectSettings.set_setting(
		&"input/ui_toggle_menu", {"deadzone": 0.5, "events": [escape]}
	)


func before_each() -> void:
	# Given: A platform whose profile loaded, the input scene with its slot, and the
	# settings the pause screen's settings menu reads.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())
	add_child_autofree(SettingsSystem.new())

	_actions.clear()

	_gameplay = StdInputActionSet.new()
	_gameplay.name = &"Gameplay"


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _focus_owner returns the control holding focus.
func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


## _mount pushes a map holding the game's set, with a HUD button in its UI, onto a
## screen manager, hides the cursor, and readies an alert the game has set up.
func _mount() -> void:
	var map: KitMap2D = MapScene.instantiate()
	map.action_set = _gameplay

	_hud = ButtonScene.instantiate()
	_hud.custom_minimum_size = Vector2(160, 40)
	_hud.position = Vector2(20, 20)
	map.get_node(^"UI").add_child(_hud)

	_manager = StdTestScreenManager.new()
	_input = await StdTestInput.mount(self, _manager)
	await _manager.push_and_wait(StdScreen.new(), map, StdTransition.new())

	StdInputSlot.for_player(1).cursor.hide_cursor()

	_dialog = DialogScene.instantiate()
	_dialog.title = "Victory"
	_dialog.message = "Score: 100"
	_dialog.secondary_label = "kit_alert_cancel"
	_dialog.closed.connect(_actions.append)
	watch_signals(_dialog.screen)

	_preparation = _manager.load_screen(_dialog.screen)
	if not _preparation.is_done():
		await _preparation.done


## _open mounts a map and returns once the alert has entered over it.
func _open() -> void:
	await _mount()
	_dialog.open(_manager)
	await wait_for_signal(_dialog.screen.entered, _TIMEOUT)
	await wait_process_frames(1)


## _press presses and releases `keycode`.
func _press(keycode: Key) -> void:
	_input.press_key(keycode)
	_input.release_key(keycode)
