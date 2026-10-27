##
## Tests for the controls tab, which lists one category of device's bindings and
## settings, and a game's action sets beside kit's own.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Binding := preload("binding.gd")
const ControlsScene := preload("controls.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SteamInputEnabled := preload(
	"res://system/input/steam_input_enabled_property.tres"
)
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
		assert_true(binding.glyph.always_show_kbm)
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
		assert_true(binding.glyph.always_show_joy)
		assert_false(binding.button.disabled)

	# Then: No note asks for a controller.
	assert_false(controls.get_node(^"%Disconnected").visible)


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


func test_controls_controller_tab_with_steam_input_shows_the_configurator() -> void:
	# Given: Steam Input drives controllers.
	SteamInputEnabled.set_value(true)

	# When: A controller tab enters the tree.
	var controls := await _add_controls(_CONTROLLER)

	# Then: Steam's configurator shows in place of the bindings.
	var steam_input := controls.get_node(^"Controller/SteamInput")
	assert_true(steam_input.visible)
	assert_false(controls.get_node(^"%ActionSets").visible)

	# Then: The configurator opens from the configurator setting's button.
	var configurator := controls.get_node(
		^"Controller/Steam/StdConditionParent/SteamConfigurator"
	)
	assert_true(configurator.is_inside_tree())
	assert_eq(configurator.button, steam_input.get_node(^"Configurator/Prompt"))

	# When: Steam Input stops driving controllers.
	SteamInputEnabled.set_value(false)
	await wait_process_frames(1)

	# Then: The bindings show in place of the configurator.
	assert_false(steam_input.visible)
	assert_true(controls.get_node(^"%ActionSets").visible)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _added_actions:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)

	_added_actions.clear()


func after_each() -> void:
	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())

	SteamInputEnabled.scope.config.erase(
		SteamInputEnabled.category, SteamInputEnabled.name
	)


func before_all() -> void:
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


func _connect_joypad() -> void:
	StdInputSlot.for_player(1).joypad_monitor.joy_connected.emit(
		_JOYPAD, StdInputDevice.DEVICE_TYPE_XBOX_ONE
	)


func _list_bindings(controls: Node) -> Array[Binding]:
	var bindings: Array[Binding] = []
	for node in controls.find_children("*", "", true, false):
		if node is Binding:
			bindings.append(node)

	return bindings
