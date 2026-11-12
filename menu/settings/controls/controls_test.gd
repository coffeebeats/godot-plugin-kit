##
## Tests for the controls tab, which lists one category of device's bindings and
## settings, and a game's action sets beside kit's own.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Binding := preload("binding.gd")
const Bindings := preload("res://addons/std/input/godot/binding.gd")
const BindingsScope := preload("res://system/input/unknown/bindings_scope.tres")
const ControlsScene := preload("controls.tscn")
const MenuOptions := preload("res://system/input/actions/menu_options.tres")
const MenuScene := preload("res://menu/settings/menu.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const Rebinder := preload("rebinder.gd")
const Reset := preload("reset.gd")
const SettingsScene := preload("res://system/setting/settings.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _JOYPAD is the device ID of the test joypad.
const _JOYPAD := 0

## _CONTROLLER is the device category of controllers.
const _CONTROLLER := StdInputDevice.DEVICE_TYPE_GENERIC

## _KEYBOARD is the device category of the keyboard and mouse.
const _KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

## _GAME_ACTIONS are the actions in kit's sets which the game binds, so kit's own input
## map lacks them.
const _GAME_ACTIONS: Array[StringName] = [
	&"ui_binding_stop", &"ui_tab_next", &"ui_tab_prev", &"ui_toggle_menu"
]

# -- INITIALIZATION ------------------------------------------------------------------ #

var _added_actions: Array[StringName] = []

## _game_options is the game's options layer over its own set, carrying pause.
var _game_options: StdInputActionSetLayer = null

## _game_shop is a game layer over the same set carrying none of kit's options actions.
var _game_shop: StdInputActionSetLayer = null

## _input drives the tab `_mount_controls` mounted.
var _input: StdTestInput = null

var _translations: Array[Translation] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_add_action_sets_lists_the_game_sets_above_kit_sets_in_order() -> void:
	# Given: A controller tab, outside the tree since its bindings need an input slot.
	var controls: VBoxContainer = autofree(ControlsScene.instantiate())
	controls.device_category = _CONTROLLER

	# Given: Two game action sets.
	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"

	var options := StdInputActionSetLayer.new()
	options.name = &"GameplayOptions"

	var action_sets: Array[StdInputActionSet] = [gameplay, options]

	# When: The game's action sets are added.
	controls._add_action_sets(action_sets)

	# Then: Both are listed, in order, directly above kit's first action set.
	var groups: Node = controls.get_node(^"%ActionSets")
	var index := controls.get_node(^"%MenuControls").get_index()
	assert_eq(groups.get_child(index - 2).action_set, gameplay)
	assert_eq(groups.get_child(index - 1).action_set, options)

	# Then: Both store their bindings in the tab's scope.
	assert_not_null(controls.scope)
	assert_eq(groups.get_child(index - 2).scope, controls.scope)
	assert_eq(groups.get_child(index - 1).scope, controls.scope)

	# Then: Both list the tab's device's bindings.
	assert_eq(groups.get_child(index - 2).device_category, _CONTROLLER)
	assert_eq(groups.get_child(index - 1).device_category, _CONTROLLER)


func test_controls_keyboard_tab_lists_only_keyboard_bindings_and_settings() -> void:
	# Given: A connected joypad, made active by a press of `ui_accept`.
	await _activate_joypad()

	# When: A keyboard and mouse tab enters the tree.
	var controls := await _add_controls(_KEYBOARD)

	# Then: It keeps the mouse settings and drops the controller's.
	assert_true(controls.has_node(^"%Keyboard"))
	assert_false(controls.has_node(^"%Controller"))

	# Then: Each binding shows and rebinds the keyboard's, though the joypad is active.
	var bindings := _list_bindings(controls)
	assert_gt(bindings.size(), 0, "kit's sets have bindings")

	for binding in bindings:
		assert_eq(binding.device_category, _KEYBOARD)
		assert_eq(_get_shown_category(binding), _KEYBOARD)
		assert_false(binding.button.disabled)


func test_controls_keyboard_tab_anchors_focus_on_its_first_setting() -> void:
	# When: A keyboard and mouse tab enters the tree.
	var controls := await _add_controls(_KEYBOARD)

	# Then: Focus-based navigation lands on the tab's first setting.
	assert_eq(
		StdInputCursorFocusHandler.get_focus_target(controls),
		controls.get_node(^"Keyboard/Mouse/ConfineCursor/Checkbox"),
	)


func test_controls_controller_tab_lists_only_controller_bindings_and_settings() -> void:
	# Given: A connected joypad, with the keyboard active.
	_connect_joypad()

	# When: A controller tab enters the tree.
	var controls := await _add_controls(_CONTROLLER)

	# Then: It keeps the controller settings and drops the mouse's.
	assert_true(controls.has_node(^"%Controller"))
	assert_false(controls.has_node(^"%Keyboard"))

	# Then: Each binding shows and rebinds the joypad's, though the keyboard is active.
	var bindings := _list_bindings(controls)
	assert_gt(bindings.size(), 0, "kit's sets have bindings")

	for binding in bindings:
		assert_eq(binding.device_category, _CONTROLLER)
		assert_eq(_get_shown_category(binding), _CONTROLLER)
		assert_false(binding.button.disabled)

	# Then: No note asks for a controller.
	assert_false(controls.get_node(^"%Disconnected").visible)


func test_controls_tab_names_its_rebinding_groups_by_device() -> void:
	# When: A controller tab enters the tree.
	var controls := await _add_controls(_CONTROLLER)

	# Then: Its options group is named for the controller tab.
	var group: Node = controls.get_node(^"%MenuOptions")
	assert_eq(group.id, &"controller_bindings_menu_options")


func test_controls_tab_pruned_by_the_menu_keeps_the_game_sets() -> void:
	# Given: A keyboard and mouse tab.
	var controls: VBoxContainer = ControlsScene.instantiate()
	controls.device_category = _KEYBOARD

	# Given: A game action set, which the tab lists for rebinding.
	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"
	KitSystems.input().action_sets = [gameplay] as Array[StdInputActionSet]

	# Given: The game lists neither the cursor setting nor kit's first rebinding group.
	var shown: Array[StringName] = [&"keyboard_mouse_bindings_menu_options"]

	# Given: The settings menu prunes the tab as it enters.
	var menu: Control = autofree(MenuScene.instantiate())
	controls.tree_entered.connect(menu._prune.bind(controls, shown), CONNECT_ONE_SHOT)

	# When: The tab enters the tree.
	add_child_autofree(controls)
	await wait_process_frames(2)

	# Then: The mouse group and kit's unlisted rebinding groups are left out.
	assert_false(controls.has_node(^"Keyboard/Mouse"))
	assert_false(controls.has_node(^"%MenuControls"))
	assert_true(controls.has_node(^"%MenuOptions"))

	# Then: The game's sets are still listed, above kit's.
	var groups := controls.get_node(^"%ActionSets")
	assert_eq(groups.get_child(0).action_set.name, &"Gameplay")

	# Then: Focus lands on a control in the tab.
	assert_not_null(StdInputCursorFocusHandler.get_focus_target(controls))


func test_controls_controller_tab_pruned_of_its_settings_anchors_a_binding() -> void:
	# Given: A connected joypad, so the controller tab's bindings take focus.
	_connect_joypad()

	# Given: A controller tab.
	var controls: VBoxContainer = ControlsScene.instantiate()
	controls.device_category = _CONTROLLER

	# Given: The game lists none of the gamepad settings, without Steam Input.
	var dropped: Array[StringName] = [
		&"controller_button_prompt",
		&"controller_disable_vibration",
		&"controller_vibration_strength",
	]
	var settings: Node = autofree(SettingsScene.instantiate())
	for id in dropped:
		settings.menu_setting_overrides[id] = false

	var shown: Array[StringName] = settings.get_shown_menu_settings()

	# Given: The settings menu prunes the tab as it enters.
	var menu: Control = autofree(MenuScene.instantiate())
	controls.tree_entered.connect(menu._prune.bind(controls, shown), CONNECT_ONE_SHOT)

	# When: The tab enters the tree.
	add_child_autofree(controls)
	await wait_process_frames(2)

	# Then: Focus lands on a binding, past the hidden Steam configurator.
	var target := StdInputCursorFocusHandler.get_focus_target(controls)
	assert_not_null(target)
	assert_true(controls.get_node(^"%ActionSets").is_ancestor_of(target))


func test_controls_controller_tab_without_a_joypad_disables_rebinding() -> void:
	# Given: A controller tab in the tree, with no joypad connected.
	var controls := await _add_controls(_CONTROLLER)

	# Then: A note asks for a controller, and no binding can be rebound.
	assert_true(controls.get_node(^"%Disconnected").visible)
	for binding in _list_bindings(controls):
		assert_true(binding.button.disabled)

	# When: A joypad connects.
	_connect_joypad()
	await wait_process_frames(1)

	# Then: The note hides, and each binding can be rebound.
	assert_false(controls.get_node(^"%Disconnected").visible)
	for binding in _list_bindings(controls):
		assert_false(binding.button.disabled)


func test_controls_controller_tab_out_of_the_tree_ignores_the_slot_leaving() -> void:
	# Given: A controller tab in the tree.
	var controls := await _add_controls(_CONTROLLER)

	# Given: The tab leaves the tree, as the main scene does first when the game quits.
	remove_child(controls)

	# When: The input scene leaves the tree, where its slot disconnects each device.
	remove_child(KitSystems.input())

	# Then: The tab handles none of them, so nothing fails.
	assert_engine_error_count(0)


func test_controls_controller_tab_outliving_the_slot_asks_for_a_controller() -> void:
	# Given: A connected joypad.
	_connect_joypad()

	# Given: A controller tab in the tree, with no note asking for a controller.
	var controls := await _add_controls(_CONTROLLER)
	assert_false(controls.get_node(^"%Disconnected").visible, "precondition")

	# When: The input scene leaves the tree, where its slot disconnects each device.
	remove_child(KitSystems.input())

	# Then: The note asks for a controller.
	assert_true(controls.get_node(^"%Disconnected").visible)


func test_controls_controller_tab_reentering_the_tree_asks_for_a_lost_joypad() -> void:
	# Given: A connected joypad.
	_connect_joypad()

	# Given: A controller tab which left the tree, as a cached settings menu does.
	var controls := await _add_controls(_CONTROLLER)
	assert_false(controls.get_node(^"%Disconnected").visible, "precondition")
	remove_child(controls)

	# When: The joypad disconnects.
	_disconnect_joypad()

	# When: The tab re-enters the tree.
	add_child(controls)

	# Then: The note asks for a controller.
	assert_true(controls.get_node(^"%Disconnected").visible)


func test_controls_menu_options_rebind_writes_each_game_layer_declaring_it() -> void:
	# Given: The game lists its options layer and its shop layer for kit's options.
	_list_game_layers()

	# Given: A keyboard and mouse tab, shown in a screen.
	var controls := await _mount_controls()
	var row: Binding = _list_bindings(controls.get_node(^"%MenuOptions"))[0]

	# When: The pause action's primary binding is clicked.
	await _click(row.button)
	assert_true(_is_rebinder_open(), "precondition")

	# When: P is pressed.
	_input.press_key(KEY_P)
	_input.release_key(KEY_P)
	await wait_process_frames(2)

	# Then: Kit's options layer and the game's both bind pause to P.
	assert_eq(_bound_keycode(MenuOptions), KEY_P)
	assert_eq(_bound_keycode(_game_options), KEY_P)

	# Then: The game layer which lacks the action is untouched.
	assert_false(
		Bindings.category_has_user_override(BindingsScope, _game_shop, _KEYBOARD)
	)


func test_controls_menu_options_row_reset_resets_each_game_layer_declaring_it() -> void:
	# Given: The game lists its options layer and its shop layer for kit's options.
	_list_game_layers()

	# Given: Pause bound to P in kit's options layer and the game's.
	for action_set: StdInputActionSet in [MenuOptions, _game_options]:
		Bindings.bind_action(
			BindingsScope, action_set, &"ui_toggle_menu", _key(KEY_P), _KEYBOARD
		)

	# Given: A keyboard and mouse tab, shown in a screen.
	var controls := await _mount_controls()
	var row: Binding = _list_bindings(controls.get_node(^"%MenuOptions"))[0]

	# When: The pause action's reset is clicked.
	await _click(_find_reset(row).get_node(^"Prompt"))

	# Then: Neither layer overrides pause any longer.
	assert_false(_has_user_override(MenuOptions))
	assert_false(_has_user_override(_game_options))


func test_controls_menu_options_group_reset_resets_each_game_layer() -> void:
	# Given: The game lists its options layer and its shop layer for kit's options.
	_list_game_layers()

	# Given: Pause bound to P in kit's options layer and the game's.
	for action_set: StdInputActionSet in [MenuOptions, _game_options]:
		Bindings.bind_action(
			BindingsScope, action_set, &"ui_toggle_menu", _key(KEY_P), _KEYBOARD
		)

	# Given: A keyboard and mouse tab, shown in a screen.
	var controls := await _mount_controls()

	# When: The options group's reset is clicked.
	var group := controls.get_node(^"%MenuOptions")
	await _click(group.get_node(^"%Reset").get_node(^"Prompt"))

	# Then: Neither layer overrides pause any longer.
	assert_false(_has_user_override(MenuOptions))
	assert_false(_has_user_override(_game_options))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _added_actions:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)

	_added_actions.clear()

	for translation in _translations:
		TranslationServer.remove_translation(translation)

	_translations.clear()


func after_each() -> void:
	# NOTE: The game frees its main scene before the input autoload, so the mounted tab
	# goes first here too, while the slot its bindings watch still exists.
	if is_instance_valid(_input):
		_input.free()

	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())

	# NOTE: The tab's scope is a shared resource, so a rebind would outlive the test.
	for action_set: StdInputActionSet in [MenuOptions, _game_options, _game_shop]:
		Bindings.reset_all_actions(BindingsScope, action_set, _KEYBOARD)

	# NOTE: The rebinder reuses one instance, which the screen manager freed with itself,
	# so a later test must not find the freed one.
	Rebinder._instance = null


func before_all() -> void:
	# NOTE: The rebinder's title formats a translated template, and kit's project lists
	# no catalogues, so this loads the shipped ones the way a game's settings would.
	for path in DirAccess.get_files_at("res://locale"):
		if not path.ends_with(".mo"):
			continue

		var translation: Translation = load("res://locale".path_join(path))
		TranslationServer.add_translation(translation)
		_translations.append(translation)

	# NOTE: std reads an action's defaults from the project settings, so each action is
	# added there as well as to the input map, as a game's project defines it.
	for action in _GAME_ACTIONS:
		if ProjectSettings.has_setting(&"input/" + action):
			continue

		ProjectSettings.set_setting(&"input/" + action, {"deadzone": 0.5, "events": []})
		InputMap.add_action(action)
		_added_actions.append(action)


func before_each() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"

	_game_options = StdInputActionSetLayer.new()
	_game_options.name = &"GameplayOptions"
	_game_options.parent = gameplay
	_game_options.actions_digital = [&"ui_toggle_menu"] as Array[StringName]

	_game_shop = StdInputActionSetLayer.new()
	_game_shop.name = &"GameplayShop"
	_game_shop.parent = gameplay
	_game_shop.actions_digital = [&"ui_accept"] as Array[StringName]


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _activate_joypad connects an Xbox joypad and makes it active with a press of
## `ui_accept`, which the engine binds to its A button.
func _activate_joypad() -> void:
	_connect_joypad()

	var event := InputEventJoypadButton.new()
	event.device = _JOYPAD
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await wait_process_frames(2)

	var release: InputEventJoypadButton = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await wait_process_frames(2)

	var device := StdInputSlot.for_player(1).get_active_device()
	assert_eq(device.device_category, _CONTROLLER, "precondition")


## _add_controls adds a controls tab listing `device_category`'s bindings, as the
## settings menu places it.
func _add_controls(device_category: StdInputDevice.DeviceType) -> VBoxContainer:
	var controls: VBoxContainer = ControlsScene.instantiate()
	controls.device_category = device_category
	add_child_autofree(controls)
	await wait_process_frames(2)

	return controls


func _bound_keycode(action_set: StdInputActionSet) -> Key:
	var binding := (
		Bindings
		. get_action_binding(
			BindingsScope,
			action_set,
			&"ui_toggle_menu",
			_KEYBOARD,
			StdInputDeviceActions.BINDING_INDEX_PRIMARY,
		)
	)
	return (binding as InputEventKey).keycode if binding is InputEventKey else KEY_NONE


## _click clicks `control` and lets the frames pass which open or close a screen.
func _click(control: Control) -> void:
	_input.click(control)
	await wait_process_frames(2)


func _connect_joypad() -> void:
	StdInputSlot.for_player(1).joypad_monitor.joy_connected.emit(
		_JOYPAD, StdInputDevice.DEVICE_TYPE_XBOX_ONE
	)


func _disconnect_joypad() -> void:
	StdInputSlot.for_player(1).joypad_monitor.joy_disconnected.emit(_JOYPAD)


## _find_reset returns the reset button in `binding`'s row.
func _find_reset(binding: Binding) -> Reset:
	for node in binding.get_parent().get_children():
		if node is Reset:
			return node

	return null


## _get_shown_category returns the category of the device whose origin `binding` shows.
func _get_shown_category(binding: Binding) -> StdInputDevice.DeviceType:
	var device_type: StdInputDevice.DeviceType = binding._get_device_type(
		StdInputSlot.for_player(1)
	)
	return StdInputDevice.get_device_category(device_type)


func _has_user_override(action_set: StdInputActionSet) -> bool:
	return Bindings.action_has_user_override(
		BindingsScope, action_set, &"ui_toggle_menu", _KEYBOARD
	)


func _is_rebinder_open() -> bool:
	return not StdGroup.is_empty(Rebinder.GROUP_REBINDER)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


## _list_game_layers lists the game's options and shop layers in the input system's
## `menu_options_layers`, as a game sets them on its `Input` instance.
func _list_game_layers() -> void:
	KitSystems.input().menu_options_layers = (
		[_game_options, _game_shop] as Array[StdInputActionSetLayer]
	)


func _list_bindings(controls: Node) -> Array[Binding]:
	var bindings: Array[Binding] = []
	for node in controls.find_children("*", "", true, false):
		if node is Binding:
			bindings.append(node)

	return bindings


## _mount_controls mounts a keyboard and mouse tab in a screen, as the settings menu
## shows it, so its rows can open the rebinder over it, and returns the tab.
func _mount_controls() -> VBoxContainer:
	var manager := StdScreenManager.new()
	_input = await StdTestInput.mount(self, manager)

	var controls: VBoxContainer = ControlsScene.instantiate()
	controls.device_category = _KEYBOARD
	manager.push(StdScreen.new(), controls)
	await wait_process_frames(2)

	return controls
