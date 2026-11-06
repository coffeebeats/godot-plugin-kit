##
## Tests for the menu rows scene, holding action buttons inside a panel placed in the UI
## of kit's 2D map template over the input system, and driven with real keys.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ActionButtonScene := preload("res://ui/input/action_button.tscn")
const MapScene := preload("res://map/2d/scene.tscn")
const Menu := preload("res://system/input/actions/menu.tres")
const MenuRowsScene := preload("res://ui/panel/menu_rows.tscn")
const PanelScene := preload("res://ui/panel/panel.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTIONS are the actions the rows stand for, in order.
const _ACTIONS: Array[StringName] = [&"ui_accept", &"ui_focus_next", &"ui_focus_prev"]

# -- INITIALIZATION ------------------------------------------------------------------ #

var _gameplay: StdInputActionSet = null
var _input: StdTestInput = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_menu_rows_open_focuses_the_first_row_and_cancel_closes_it() -> void:
	# Given: A closed panel of rows over a map.
	var panel := await _mount()
	var rows := _list_rows(panel)
	var slot := StdInputSlot.for_player(1)

	# Given: The cursor is hidden, as after a key press.
	slot.cursor.hide_cursor()

	# When: The panel is opened.
	_open(panel)
	await wait_process_frames(1)

	# Then: The first row holds focus.
	assert_eq(_focus_owner(), rows[0])

	# When: Down is pressed twice.
	_press(KEY_DOWN)
	_press(KEY_DOWN)

	# Then: Focus moves to the last row.
	assert_eq(_focus_owner(), rows[2])

	# When: Escape is pressed.
	_press(KEY_ESCAPE)
	await wait_process_frames(1)

	# Then: The panel is closed, and the map's set is loaded again.
	assert_false(panel.visible)
	assert_eq(slot.actions.get_action_set(slot.device_id), _gameplay)


func test_menu_rows_disabled_first_row_passes_focus_to_the_next() -> void:
	# Given: A closed panel of rows over a map.
	var panel := await _mount()
	var rows := _list_rows(panel)

	# Given: The first row is disabled, as an item the player can't afford.
	rows[0].disabled = true

	# Given: The cursor is hidden, as after a key press.
	StdInputSlot.for_player(1).cursor.hide_cursor()

	# When: The panel is opened.
	_open(panel)
	await wait_process_frames(1)

	# Then: The second row holds focus.
	assert_eq(_focus_owner(), rows[1])


func test_menu_rows_rebuilt_rows_give_focus_to_the_new_first_row() -> void:
	# Given: A closed panel of rows over a map.
	var panel := await _mount()
	var rows: Node = panel.get_node(^"MenuRows")

	# Given: Every control that takes focus is recorded.
	var visits: Array[int] = []
	var record := func(control: Control) -> void:
		visits.append(control.get_instance_id())
	get_viewport().gui_focus_changed.connect(record)

	# Given: The rows are replaced by two new ones, as a context menu's for a new target.
	var old_ids: Array[int] = []
	for row in rows.get_children():
		old_ids.append(row.get_instance_id())
		row.queue_free()
	var first := _make_row(_ACTIONS[1])
	rows.add_child(first)
	rows.add_child(_make_row(_ACTIONS[2]))

	# Given: The cursor is hidden, as after a key press.
	StdInputSlot.for_player(1).cursor.hide_cursor()

	# When: The panel is opened in the same frame.
	_open(panel)
	await wait_process_frames(2)
	get_viewport().gui_focus_changed.disconnect(record)

	# Then: Focus never visited an old row, and the first new row holds it.
	assert_true(visits.filter(func(id: int) -> bool: return id in old_ids).is_empty())
	assert_eq(_focus_owner(), first)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	# NOTE: The game frees its main scene before the input autoload, so the mounted map
	# goes first here too, while the slot its loaders hold still exists.
	if is_instance_valid(_input):
		_input.free()

	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


func before_each() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	_gameplay = StdInputActionSet.new()
	_gameplay.name = &"Gameplay"


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _focus_owner returns the control holding focus.
func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


## _list_rows returns the rows inside `panel`, in order.
func _list_rows(panel: Control) -> Array[Node]:
	return panel.get_node(^"MenuRows").get_children()


## _make_row returns an action button for `action`, a row of kit's `Menu` set.
func _make_row(action: StringName) -> KitInputActionButton:
	var row: KitInputActionButton = ActionButtonScene.instantiate()
	row.action_set = Menu
	row.action = action
	row.custom_minimum_size = Vector2(160, 40)
	return row


## _mount mounts a map holding the game's set, with a closed panel in its UI holding
## the menu rows scene with a row per action in `_ACTIONS`, and returns the panel once
## the map's loader has synced.
func _mount() -> PanelContainer:
	var map: KitMap2D = MapScene.instantiate()
	map.action_set = _gameplay

	var rows: VBoxContainer = MenuRowsScene.instantiate()
	for action in _ACTIONS:
		rows.add_child(_make_row(action))

	var panel: PanelContainer = PanelScene.instantiate()
	panel.add_child(rows)
	panel.position = Vector2(400, 200)
	map.get_node(^"UI").add_child(panel)

	_input = await StdTestInput.mount(self, map)
	await wait_process_frames(1)

	return panel


## _open opens `panel` through its `StdPanel` node.
func _open(panel: Control) -> void:
	(panel.get_node(^"StdPanel") as StdPanel).open()


## _press presses and releases `keycode`.
func _press(keycode: Key) -> void:
	_input.press_key(keycode)
	_input.release_key(keycode)
