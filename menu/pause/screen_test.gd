##
## Tests for the pause screen, which a gameplay screen lists under its
## `dependency_screens` so that mounting the gameplay screen builds the settings menu,
## parked, and leaves the pause menu to build when it opens.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PauseScreen := preload("screen.tres")
const PlatformScene := preload("res://premade/platform.tscn")
const SettingsScreen := preload("res://menu/settings/screen.tres")
const SettingsSystem := preload("res://system/setting/settings.gd")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _GAME_ACTIONS are the actions in kit's sets which the game binds, so kit's own input
## map lacks them. The settings menu the pause screen builds has rows which read them.
const _GAME_ACTIONS: Array[StringName] = [
	&"ui_binding_stop", &"ui_tab_next", &"ui_tab_prev", &"ui_toggle_menu"
]

# -- INITIALIZATION ------------------------------------------------------------------ #

var _added_actions: Array[StringName] = []

## _input mounts the screen manager a test pushes its gameplay screen on.
var _input: StdTestInput = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_pause_screen_listed_by_gameplay_parks_the_settings_menu_at_mount() -> void:
	# Given: A gameplay screen which lists the pause screen under its dependencies.
	var gameplay := StdScreen.new()
	gameplay.dependency_screens = [PauseScreen]

	# Given: A screen manager in the tree.
	var manager := StdTestScreenManager.new()
	_input = await StdTestInput.mount(self, manager)

	# When: The gameplay screen is pushed and mounts.
	await manager.push_and_wait(gameplay, Control.new(), StdTransition.new())

	# Then: The settings menu was built.
	var settings := manager._cache.get_entry(SettingsScreen)
	assert_not_null(settings)
	if settings == null:
		return

	# Then: It waits in the tree, parked and hidden.
	assert_true(settings.parked)
	assert_true(settings.scene.is_inside_tree())
	assert_false(settings.overlay.visible)

	# Then: The pause menu itself is left unbuilt.
	assert_null(manager._cache.get_entry(PauseScreen))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _added_actions:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)

	_added_actions.clear()


func after_each() -> void:
	# NOTE: The game frees its main scene before the system scenes, so the manager goes
	# first here too, with the menu it parked, while the slot the menu watches exists.
	if is_instance_valid(_input):
		_input.free()

	# NOTE: The slot outlives the test, so leave an empty set behind rather than a set
	# whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


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
	# Given: A platform and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: The settings component the settings menu reads.
	add_child_autofree(SettingsSystem.new())
