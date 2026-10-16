##
## Unit tests for `SystemInput`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const AlertScene := preload("res://ui/menu/alert.tscn")
const MenuNavigation := preload("res://system/input/actions/menu_navigation.tres")
const MenuOptions := preload("res://system/input/actions/menu_options.tres")
const PauseMenuScene := preload("res://menu/pause/menu.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("input.gd")
const SystemInputScene := preload("input.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_kit_menus_keep_a_shared_layer_through_a_pop() -> void:
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

	# Then: Both menus hold the navigation layer, and only the pause menu the options.
	assert_has(slot.list_action_set_layers(), MenuNavigation)
	assert_does_not_have(slot.list_action_set_layers(), MenuOptions)

	# When: Each is popped the way the screen manager pops, uncovering the screen
	# below before tearing the popped one down.
	pause.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(alert)
	map.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(pause)

	# Then: The map's set is loaded with its options layer, and navigation is off.
	assert_eq(slot.actions.get_action_set(slot.device_id), map.action_set)
	assert_has(slot.list_action_set_layers(), MenuOptions)
	assert_does_not_have(slot.list_action_set_layers(), MenuNavigation)


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
