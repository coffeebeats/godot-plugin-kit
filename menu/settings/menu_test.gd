##
## Tests for the settings menu, which shows a game's own tabs beside kit's, and those of
## kit's rows and rebinding groups the game lists.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ControlsScene := preload("controls/controls.tscn")
const MenuScene := preload("menu.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SettingScene := preload("setting.tscn")
const SettingsScreen := preload("screen.tres")
const SettingsScene := preload("res://system/setting/settings.tscn")
const SettingsSystem := preload("res://system/setting/settings.gd")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ID_PATTERN matches the id a kit scene gives a settings row.
const _ID_PATTERN := '(?m)^id = &"(\\w+)"'

## _GAME_ACTIONS are the actions in kit's sets which the game binds, so kit's own input
## map lacks them.
const _GAME_ACTIONS: Array[StringName] = [
	&"ui_binding_stop", &"ui_tab_next", &"ui_tab_prev", &"ui_toggle_menu"
]

# -- INITIALIZATION ------------------------------------------------------------------ #

var _added_actions: Array[StringName] = []

## _input mounts the screen manager a test opens the settings screen on.
var _input: StdTestInput = null

## _menu is the settings menu a test added to the tree.
var _menu: Control = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_add_tabs_appends_the_game_tabs_after_kit_tabs_in_order() -> void:
	# Given: A settings menu, outside the tree since its tabs need the system scenes.
	var menu: Control = autofree(MenuScene.instantiate())
	var tab_group: Node = menu.get_node(^"%TabGroup")

	var labels: PackedStringArray = tab_group.tabs.duplicate()
	var count: int = tab_group.content.get_child_count()
	assert_eq(labels.size(), count, "kit's tab labels match its tab contents")

	# Given: Two game tabs, keyed by their labels.
	var tabs: Dictionary[String, PackedScene] = {
		"game_first": _pack_tab(&"First"),
		"game_second": _pack_tab(&"Second"),
	}

	# When: The game's tabs are added.
	menu._add_tabs(tabs)

	# Then: Both labels follow kit's, in order.
	labels.append_array(["game_first", "game_second"])
	assert_eq(tab_group.tabs, labels)

	# Then: Both contents follow kit's, in the same order as their labels.
	assert_eq(tab_group.content.get_child_count(), count + 2)
	assert_eq(tab_group.content.get_child(count).name, &"First")
	assert_eq(tab_group.content.get_child(count + 1).name, &"Second")


func test_menu_settings_names_every_kit_row_and_rebinding_group() -> void:
	# Given: The ids of every row in kit's settings tabs.
	var ids := _find_row_ids("res://menu/settings")
	assert_gt(ids.size(), 0, "precondition")

	# Given: The ids of kit's rebinding groups in both controls tabs.
	for category in [
		StdInputDevice.DEVICE_TYPE_GENERIC, StdInputDevice.DEVICE_TYPE_KEYBOARD
	]:
		var controls: Node = autofree(ControlsScene.instantiate())
		controls.device_category = category

		for group in controls.get_node(^"%ActionSets").get_children():
			ids[controls._get_bindings_id(group.action_set)] = true

	# When: The `Settings` node's table of kit's rows and groups is read.
	var named := SettingsSystem.MENU_SETTINGS.keys()

	# Then: It names each of them, and nothing else.
	for id: StringName in ids:
		assert_has(named, id)

	assert_eq(named.size(), ids.size())


func test_menu_enter_tree_removes_each_tab_left_with_no_listed_row() -> void:
	# Given: A platform and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: The settings component.
	var settings: Node = add_child_autofree(SettingsSystem.new())

	# Given: The game hides all of kit's rows but the text size and one rebinding group.
	var kept: Array[StringName] = [
		&"interface_text_scaling", &"keyboard_mouse_bindings_menu_options"
	]
	for id in SettingsSystem.MENU_SETTINGS:
		settings.menu_setting_overrides[id] = id in kept

	# When: The settings menu enters the tree.
	_menu = MenuScene.instantiate()
	add_child(_menu)
	await wait_process_frames(2)

	# Then: Only the tabs holding a listed row or group are left.
	var contents: Node = _menu.get_node(^"%TabContents")
	var names := contents.get_children().map(func(c: Node) -> StringName: return c.name)
	assert_eq(names, [&"Interface", &"KeyboardMouse"])

	# Then: Each tab left keeps its own label.
	var labels := PackedStringArray(
		["kit_options_interface", "kit_options_keyboard_mouse"]
	)
	assert_eq(_menu.get_node(^"%TabGroup").tabs, labels)

	# Then: The keyboard tab keeps the listed group and leaves out the others.
	var keyboard: Node = contents.get_node(^"KeyboardMouse")
	assert_true(keyboard.has_node(^"%MenuOptions"))
	assert_false(keyboard.has_node(^"%MenuControls"))


func test_menu_enter_tree_without_overrides_leaves_out_the_accessibility_tab() -> void:
	# Given: A platform and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: The settings component, whose game shows none of kit's hold rows.
	add_child_autofree(SettingsSystem.new())

	# When: The settings menu enters the tree.
	_menu = MenuScene.instantiate()
	add_child(_menu)
	await wait_process_frames(2)

	# Then: The Accessibility tab is left out.
	assert_false(_menu.get_node(^"%TabContents").has_node(^"Accessibility"))

	# Then: Its label is left out with it.
	assert_does_not_have(_menu.get_node(^"%TabGroup").tabs, "kit_options_accessibility")

	# Then: Kit's other tabs stay.
	assert_true(_menu.get_node(^"%TabContents").has_node(^"KeyboardMouse"))


func test_menu_reopened_returns_to_the_default_tab() -> void:
	# Given: A platform, the input scene with its slot, and the settings component.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())
	add_child_autofree(SettingsSystem.new())

	# Given: Kit's settings screen open on a screen manager.
	var manager := StdTestScreenManager.new()
	_input = await StdTestInput.mount(self, manager)
	var menu: Control = await manager.push_and_wait(SettingsScreen)

	# Given: Another tab than the default selected, with no audio system to sound it.
	menu.tab_switch_sound_event = null
	var tab_group: Node = menu.get_node(^"%TabGroup")
	var other: int = (tab_group.default_tab + 1) % tab_group.tabs.size()
	tab_group.select(other)

	# When: The screen closes and opens again.
	manager.pop(null, true)
	var reopened := await manager.push_and_wait(SettingsScreen)

	# Then: The menu, kept in the tree, opened again on its default tab.
	assert_eq(reopened, menu)
	assert_not_null(manager._cache.get_entry(SettingsScreen).overlay)
	assert_true(tab_group.content.get_child(tab_group.default_tab).visible)
	assert_false(tab_group.content.get_child(other).visible)


func test_prune_keeps_the_accessibility_tab_once_its_hold_row_shows() -> void:
	# Given: The Accessibility tab of a settings menu outside the tree.
	var accessibility := _get_tab(&"Accessibility")

	# Given: A game which shows the hold mode row.
	var settings: Node = autofree(SettingsScene.instantiate())
	settings.menu_setting_overrides[&"accessibility_holds_mode"] = true

	# When: The tab is pruned to the rows the game shows.
	var menu: Control = autofree(MenuScene.instantiate())
	var kept: bool = menu._prune(accessibility, settings.get_shown_menu_settings())

	# Then: The tab is kept.
	assert_true(kept)

	# Then: The hold mode row stays.
	assert_true(accessibility.has_node(^"Holds/Mode"))


func test_prune_leaves_out_an_unlisted_row() -> void:
	# Given: The Sound tab of a settings menu outside the tree.
	var sound := _get_tab(&"Sound")

	# When: It is pruned to every kit setting except the voice volume.
	var kept := _prune(sound, [&"sound_volume_voice"])

	# Then: The tab is kept, without the voice row.
	assert_true(kept)
	assert_false(sound.has_node(^"Volume/Voice"))

	# Then: The other volume rows stay.
	assert_true(sound.has_node(^"Volume/Master"))
	assert_true(sound.has_node(^"Volume/Music"))


func test_prune_leaves_out_a_group_with_no_listed_row() -> void:
	# Given: The Sound tab of a settings menu outside the tree.
	var sound := _get_tab(&"Sound")

	# When: It is pruned to every kit setting except the four volumes.
	var dropped: Array[StringName] = [
		&"sound_volume_master",
		&"sound_volume_sound_effects",
		&"sound_volume_music",
		&"sound_volume_voice",
	]
	var kept := _prune(sound, dropped)

	# Then: The volume group is left out.
	assert_true(kept)
	assert_false(sound.has_node(^"Volume"))

	# Then: The audio group stays.
	assert_true(sound.has_node(^"Audio"))


func test_prune_reports_a_tab_with_no_listed_row() -> void:
	# Given: The Display tab of a settings menu outside the tree.
	var display := _get_tab(&"Display")

	# When: It is pruned to every kit setting except the display's four.
	var dropped: Array[StringName] = [
		&"display_video_fullscreen",
		&"display_video_borderless",
		&"display_video_fps_limit",
		&"display_video_vsync",
	]
	var kept := _prune(display, dropped)

	# Then: The tab is reported as left with nothing.
	assert_false(kept)


func test_prune_anchors_focus_on_the_first_listed_row() -> void:
	# Given: The Sound tab of a settings menu outside the tree.
	var sound := _get_tab(&"Sound")

	# When: It is pruned without its first row, which focus lands on.
	_prune(sound, [&"sound_volume_master"])

	# Then: The next row takes focus ahead of the one below it.
	var effects: StdInputCursorFocusHandler = sound.get_node(
		^"Volume/Effects/Slider/HSlider/FocusHandler"
	)
	var music: StdInputCursorFocusHandler = sound.get_node(
		^"Volume/Music/Slider/HSlider/FocusHandler"
	)
	assert_true(effects.use_as_anchor)
	assert_gt(effects.priority, music.priority)


func test_prune_leaves_a_game_tab_alone() -> void:
	# Given: A game tab holding a row with no id.
	var tab: Node = autofree(VBoxContainer.new())
	tab.add_child(SettingScene.instantiate())

	# When: It is pruned to an empty list.
	var menu: Control = autofree(MenuScene.instantiate())
	var kept: bool = menu._prune(tab, [] as Array[StringName])

	# Then: The tab and its row are kept.
	assert_true(kept)
	assert_eq(tab.get_child_count(), 1)


func test_prune_keeps_a_row_with_an_id_kit_does_not_name() -> void:
	# Given: A game tab holding a row with the game's own id.
	var tab: Node = autofree(VBoxContainer.new())
	var row: Node = SettingScene.instantiate()
	row.id = &"game_row"
	tab.add_child(row)

	# When: It is pruned to an empty list.
	var menu: Control = autofree(MenuScene.instantiate())
	var kept: bool = menu._prune(tab, [] as Array[StringName])

	# Then: The tab and its row are kept.
	assert_true(kept)
	assert_eq(tab.get_child_count(), 1)


func test_prune_leaves_a_game_tab_focus_alone() -> void:
	# Given: A game tab holding a row with the game's own id.
	var tab: Node = autofree(VBoxContainer.new())
	var row: Node = SettingScene.instantiate()
	row.id = &"game_row"
	tab.add_child(row)

	# Given: A focus handler in the tab which is no anchor.
	var handler := StdInputCursorFocusHandler.new()
	tab.add_child(handler)

	# When: It is pruned to an empty list.
	var menu: Control = autofree(MenuScene.instantiate())
	menu._prune(tab, [] as Array[StringName])

	# Then: No focus handler is made an anchor.
	assert_false(handler.use_as_anchor)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _added_actions:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)

	_added_actions.clear()


func after_each() -> void:
	# NOTE: The game frees its main scene before the system scenes, so the menu goes
	# first here too, while the slot its tabs watch still exists.
	if is_instance_valid(_menu):
		_menu.free()

	if is_instance_valid(_input):
		_input.free()

	# NOTE: The menu loaded kit's menu set into the slot, which outlives the test, so
	# leave an empty one behind rather than a set whose actions a later test lacks.
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


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _find_row_ids returns the set of row ids named in the scenes under `path`.
func _find_row_ids(path: String) -> Dictionary:
	var pattern := RegEx.create_from_string(_ID_PATTERN)
	var found := {}

	for directory in DirAccess.get_directories_at(path):
		found.merge(_find_row_ids(path.path_join(directory)))

	for file in DirAccess.get_files_at(path):
		if file.get_extension() != "tscn":
			continue

		var text := FileAccess.get_file_as_string(path.path_join(file))
		for match in pattern.search_all(text):
			found[StringName(match.get_string(1))] = true

	return found


## _get_tab returns the tab content named `tab_name` of a menu outside the tree.
func _get_tab(tab_name: StringName) -> Node:
	var menu: Control = autofree(MenuScene.instantiate())
	return menu.get_node(^"%TabContents").get_node(NodePath(tab_name))


## _prune prunes `tab` as the settings menu does once the game hides `dropped`, and
## returns whether the tab is kept.
func _prune(tab: Node, dropped: Array[StringName]) -> bool:
	var settings: Node = autofree(SettingsScene.instantiate())
	for id in dropped:
		settings.menu_setting_overrides[id] = false

	var shown: Array[StringName] = settings.get_shown_menu_settings()

	var menu: Control = autofree(MenuScene.instantiate())
	return menu._prune(tab, shown)


func _pack_tab(tab_name: StringName) -> PackedScene:
	var tab := VBoxContainer.new()
	tab.name = tab_name

	var scene := PackedScene.new()
	assert_eq(scene.pack(tab), OK)

	tab.free()

	return scene
