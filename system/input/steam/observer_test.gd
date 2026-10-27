##
## Unit tests for the Steam Input observer.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const SteamInputEnabled := preload(
	"res://system/input/steam_input_enabled_property.tres"
)
const SystemInput := preload("res://system/input/input.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _INPUT_SCENE_PATH is the Steam input scene, loaded in `before_all` rather than
## preloaded, since its monitor can't be parsed without the `Steam` singleton the
## GodotSteam extension registers and `should_skip_script` skips this script without it.
const _INPUT_SCENE_PATH := "res://system/input/steam/input.tscn"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _input_scene: PackedScene = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_observer_unbinds_joypads_from_godot_actions_while_steam_input_runs() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The Steam input scene under the input system.
	#
	# NOTE: Its monitor fails to start Steam Input without the Steam client.
	var system := SystemInput.new()
	var input := _input_scene.instantiate()
	system.add_child(input)
	add_child_autofree(system)
	assert_engine_error("SteamAPI_SteamInput")
	assert_engine_error("failed to initialize Steam Input")

	# Given: The observer's Godot actions component, serving the keyboard and joypads.
	var observer: Node = input.get_node(^"Observers/Player1")
	var slot: StdInputSlot = input.get_node(^"Godot/InputSlots/Player1")
	var actions: StdInputDeviceActions = observer.godot_device_actions
	assert_eq(actions, slot.actions_kbm, "precondition: keyboard's component")
	assert_eq(actions, slot.actions_joy, "precondition: joypads' component")
	assert_true(actions.claim_joy_input, "precondition: joypads bound")

	# When: Steam Input starts driving joypads.
	observer._handle_value_change(SteamInputEnabled, true)

	# Then: The slot's joypads use Steam's actions component.
	assert_eq(slot.actions_joy, observer.steam_device_actions)

	# Then: The Godot actions component stops binding joypad origins.
	assert_false(actions.claim_joy_input)

	# When: Steam Input stops.
	observer._handle_value_change(SteamInputEnabled, false)

	# Then: The slot's joypads use the Godot actions component again.
	assert_eq(slot.actions_joy, actions)

	# Then: It binds joypad origins again.
	assert_true(actions.claim_joy_input)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	_input_scene = load(_INPUT_SCENE_PATH)


func should_skip_script():
	if not ClassDB.class_exists(&"Steam"):
		return "the GodotSteam extension isn't available on this platform"

	return false
