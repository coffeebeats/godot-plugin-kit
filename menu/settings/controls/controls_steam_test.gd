##
## Tests for the controller tab while Steam Input drives controllers, which need the
## GodotSteam extension.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ControlsScene := preload("controls.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SteamInputEnabled := preload(
	"res://system/input/steam_input_enabled_property.tres"
)
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _CONTROLLER is the device category of controllers.
const _CONTROLLER := StdInputDevice.DEVICE_TYPE_GENERIC

## _GAME_ACTIONS are the actions in kit's sets which the game binds, so kit's own input
## map lacks them.
const _GAME_ACTIONS: Array[StringName] = [
	&"ui_binding_stop", &"ui_tab_next", &"ui_tab_prev", &"ui_toggle_menu"
]

# -- INITIALIZATION ------------------------------------------------------------------ #

var _added_actions: Array[StringName] = []

# -- TEST METHODS -------------------------------------------------------------------- #


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


func should_skip_script():
	if not ClassDB.class_exists(&"Steam"):
		return "the GodotSteam extension isn't available on this platform"

	return false


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_controls adds a controls tab listing `device_category`'s bindings, as the
## settings menu places it.
func _add_controls(device_category: StdInputDevice.DeviceType) -> VBoxContainer:
	var controls: VBoxContainer = ControlsScene.instantiate()
	controls.device_category = device_category
	add_child_autofree(controls)
	await wait_process_frames(2)

	return controls
