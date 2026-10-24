##
## Unit tests for the Steam Input observer.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const InputScene := preload("res://system/input/unknown/input.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SteamInputEnabled := preload(
	"res://system/input/steam_input_enabled_property.tres"
)
const SteamInputObserver := preload("observer.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_observer_unbinds_joypads_from_godot_actions_while_steam_input_runs() -> void:
	# Given: A platform whose profile loaded, and the Godot input scene, whose actions
	# component serves both the keyboard and joypads.
	add_child_autofree(PlatformScene.instantiate())
	var input: Node = add_child_autofree(InputScene.instantiate())
	var actions: StdInputDeviceActions = input.get_node(^"Godot/Components/Actions")
	assert_true(actions.claim_joy_input, "precondition: joypads bound")

	# Given: An observer of the slot, with the Godot components standing in for Steam's,
	# whose monitor needs Steam Input.
	var observer: Node = autofree(SteamInputObserver.new())
	observer.slot = StdInputSlot.for_player(1)
	observer.steam_input_enabled_property = SteamInputEnabled
	observer.godot_joypad_monitor = input.get_node(^"Godot/JoypadMonitor")
	observer.godot_device_actions = actions
	observer.godot_device_glyphs = input.get_node(^"Godot/Components/Glyphs")
	observer.godot_device_haptics = input.get_node(^"Godot/Components/Haptics")
	observer.steam_joypad_monitor = observer.godot_joypad_monitor
	observer.steam_device_actions = observer.godot_device_actions
	observer.steam_device_glyphs = observer.godot_device_glyphs
	observer.steam_device_haptics = observer.godot_device_haptics

	# When: Steam Input starts driving joypads.
	observer._handle_value_change(SteamInputEnabled, true)

	# Then: The Godot actions component stops binding joypad origins.
	assert_false(actions.claim_joy_input)

	# When: Steam Input stops.
	observer._handle_value_change(SteamInputEnabled, false)

	# Then: It binds them again.
	assert_true(actions.claim_joy_input)
