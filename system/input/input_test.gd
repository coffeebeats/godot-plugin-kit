##
## Unit tests for `SystemInput`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const AlertScene := preload("res://ui/menu/alert.tscn")
const Menu := preload("res://system/input/actions/menu.tres")
const MenuOptions := preload("res://system/input/actions/menu_options.tres")
const PauseMenuScene := preload("res://menu/pause/menu.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("input.gd")
const SystemInputScene := preload("input.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_kit_menus_over_a_map_restore_its_set_through_a_pop() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())
	var slot := StdInputSlot.for_player(1)

	# Given: A map's loader holding the game's set with kit's options layer over it.
	var map := StdInputActionSetLoader.new()
	map.action_set = StdInputActionSet.new()
	map.action_set.name = &"Gameplay"
	map.action_set_layers = [MenuOptions] as Array[StdInputActionSetLayer]
	add_child_autofree(map)
	await wait_idle_frames(1)
	assert_has(slot.list_action_set_layers(), MenuOptions)

	# When: The pause menu covers the map, and an alert then covers the pause menu.
	map.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var pause: Node = add_child_autofree(PauseMenuScene.instantiate())
	await wait_idle_frames(1)
	pause.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var alert: Node = add_child_autofree(AlertScene.instantiate())
	await wait_idle_frames(1)

	# Then: The alert's menu set is loaded, without the pause menu's options layer.
	assert_eq(slot.actions.get_action_set(slot.device_id), Menu)
	assert_does_not_have(slot.list_action_set_layers(), MenuOptions)

	# When: Each is popped the way the screen manager pops, uncovering the screen
	# below before tearing the popped one down.
	pause.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(alert)
	map.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(pause)

	# Then: The map's set is loaded with its options layer.
	assert_eq(slot.actions.get_action_set(slot.device_id), map.action_set)
	assert_has(slot.list_action_set_layers(), MenuOptions)


func test_input_ready_with_implementation_loads_module() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The input scene, whose loader places the default implementation.
	var input := SystemInputScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(input)

	# Then: Its module loaded.
	assert_true(KitModule.is_loaded(SystemInput.MODULE_ID))


func test_input_ready_without_cursor_fails_module() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The input system alone, without the implementation that places its cursor.
	var input := SystemInput.new()

	# When: It enters the scene tree.
	add_child_autofree(input)

	# Then: Its module failed.
	assert_eq(KitModule.get_status(SystemInput.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_input_get_input_slot_without_player_returns_first_players_slot() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The input scene in the scene tree.
	var input: SystemInput = SystemInputScene.instantiate()
	add_child_autofree(input)

	# When: The input slot is requested without naming a player.
	var got := input.get_input_slot()

	# Then: It is the first player's slot.
	assert_same(got, StdInputSlot.for_player(1))


func test_input_get_active_device_without_player_returns_first_players_device() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The input scene in the scene tree.
	var input: SystemInput = SystemInputScene.instantiate()
	add_child_autofree(input)

	# When: The active device is requested without naming a player.
	var got := input.get_active_device()

	# Then: It is the first player's active device.
	assert_same(got, StdInputSlot.for_player(1).get_active_device())


func test_input_navigation_press_moving_focus_swallows_the_next_press() -> void:
	# Given: The input scene, whose cooldown outlasts the test.
	add_child_autofree(PlatformScene.instantiate())
	var input: SystemInput = add_child_autofree(SystemInputScene.instantiate())
	input.ui_navigation_cooldown = 60.0

	# Given: A vertical list of two buttons, the first focused.
	var buttons := _add_vertical_list()
	buttons[0].grab_focus()

	# When: A down press moves focus to the second button.
	await _press(&"ui_down")

	# When: An up press follows at once.
	await _press(&"ui_up")

	# Then: The up press was swallowed, so the second button keeps focus.
	assert_true(buttons[1].has_focus())


func test_input_navigation_press_moving_no_focus_keeps_the_next_press() -> void:
	# Given: The input scene, whose cooldown outlasts the test.
	add_child_autofree(PlatformScene.instantiate())
	var input: SystemInput = add_child_autofree(SystemInputScene.instantiate())
	input.ui_navigation_cooldown = 60.0

	# Given: A vertical list of two buttons, the first focused.
	var buttons := _add_vertical_list()
	buttons[0].grab_focus()

	# When: A left press moves no focus in the list.
	await _press(&"ui_left")

	# When: A down press follows at once.
	await _press(&"ui_down")

	# Then: The down press moved focus to the second button.
	assert_true(buttons[1].has_focus())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	InputMap.erase_action(&"ui_toggle_menu")
	ProjectSettings.set_setting(&"input/ui_toggle_menu", null)


func after_each() -> void:
	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


func before_all() -> void:
	# NOTE: Kit's own project defines no actions, and the options layer names this one;
	# a game defines it with a default binding, which the Godot backend reads here.
	InputMap.add_action(&"ui_toggle_menu")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	ProjectSettings.set_setting(
		&"input/ui_toggle_menu", {"deadzone": 0.5, "events": [escape]}
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_vertical_list adds a vertical list of two buttons and returns them in order.
func _add_vertical_list() -> Array[Button]:
	var list: VBoxContainer = add_child_autofree(VBoxContainer.new())
	var buttons: Array[Button] = [Button.new(), Button.new()]
	for button in buttons:
		list.add_child(button)

	return buttons


## _press presses and releases `action`, letting the frames pass which deliver each to
## the scene's input callbacks.
func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await wait_process_frames(2)

	var release: InputEventAction = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await wait_process_frames(2)
