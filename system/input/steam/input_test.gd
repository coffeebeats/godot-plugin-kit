##
## Tests for the Steam Input implementation's scene, which wires std's Steam joypad
## monitor to kit's sets, the game's sets and the Godot joypad monitor.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const InputScene := preload("res://system/input/steam/input.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("res://system/input/input.gd")

const Menu := preload("res://system/input/actions/menu.tres")
const MenuBinding := preload("res://system/input/actions/menu_binding.tres")
const MenuOptions := preload("res://system/input/actions/menu_options.tres")
const MenuTabbed := preload("res://system/input/actions/menu_tabbed.tres")
const Splash := preload("res://system/input/actions/splash.tres")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_monitor_reads_bindings_against_kit_and_game_sets() -> void:
	# Given: A game set, and one of kit's sets the game also lists.
	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"
	var action_sets: Array[StdInputActionSet] = [gameplay, Menu]

	# When: The Steam input scene enters the tree under the input system.
	var input := _add_input(action_sets)

	# Then: Its monitor holds each of kit's sets and layers.
	var monitor: Node = input.get_node(^"JoypadMonitor")
	var kit_sets := [Menu, Splash, MenuBinding, MenuOptions, MenuTabbed]
	for action_set in kit_sets:
		assert_has(monitor.action_sets, action_set)

	# Then: It holds the game's set.
	assert_has(monitor.action_sets, gameplay)

	# Then: It holds a set both list once.
	assert_eq(monitor.action_sets.count(Menu), 1)


func test_input_monitor_holds_godot_joypad_monitor() -> void:
	# When: The Steam input scene enters the tree under the input system.
	var input := _add_input()

	# Then: Its monitor holds the Godot monitor the observer swaps in.
	var monitor: Node = input.get_node(^"JoypadMonitor")
	var observer: Node = input.get_node(^"Observers/Player1")
	assert_not_null(monitor.godot_joypad_monitor)
	assert_eq(monitor.godot_joypad_monitor, observer.godot_joypad_monitor)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_input adds a platform whose profile loaded, then the Steam input scene under an
## input system listing `action_sets`, as the system's loader places it on Steam builds.
func _add_input(action_sets: Array[StdInputActionSet] = []) -> Node:
	add_child_autofree(PlatformScene.instantiate())

	var system := SystemInput.new()
	system.action_sets = action_sets

	var input := InputScene.instantiate()
	system.add_child(input)
	add_child_autofree(system)

	# NOTE: The monitor fails to start Steam Input without the Steam client.
	assert_engine_error("SteamAPI_SteamInput")
	assert_engine_error("failed to initialize Steam Input")

	return input
