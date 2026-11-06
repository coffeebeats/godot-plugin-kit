##
## Tests for the panel scenes, placed in the UI of kit's 2D map template over the input
## system and driven with real keys and clicks.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ButtonScene := preload("res://ui/input/button.tscn")
const MapScene := preload("res://map/2d/scene.tscn")
const Menu := preload("res://system/input/actions/menu.tres")
const PanelScene := preload("res://ui/panel/panel.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")
const WorldPanelScene := preload("res://ui/panel/world_panel_2d.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _PANEL_POSITION is where a panel that follows nothing sits.
const _PANEL_POSITION := Vector2(400, 200)

## _WORLD_POSITION is a point on the map's world, clear of the HUD button and the panel.
const _WORLD_POSITION := Vector2(900, 600)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _gameplay: StdInputActionSet = null
var _hud: Button = null
var _input: StdTestInput = null
var _map: KitMap2D = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_panel_open_takes_input_and_cancel_returns_it() -> void:
	# Given: A closed panel over a map.
	var panel := await _mount(PanelScene.instantiate())
	var slot := StdInputSlot.for_player(1)

	# Given: The cursor is hidden, as after a key press.
	slot.cursor.hide_cursor()

	# When: The panel is opened.
	_std_panel(panel).open()
	await wait_process_frames(1)

	# Then: Kit's menu set is loaded, and the panel's first button holds focus.
	var buttons := _list_buttons(panel)
	assert_eq(slot.actions.get_action_set(slot.device_id), Menu)
	assert_eq(_focus_owner(), buttons[0])

	# When: Down is pressed.
	_press(KEY_DOWN)

	# Then: Focus moves to the panel's second button.
	assert_eq(_focus_owner(), buttons[1])

	# When: Escape is pressed.
	_press(KEY_ESCAPE)
	await wait_process_frames(1)

	# Then: The panel is closed, and the map's set is loaded again.
	assert_false(panel.visible)
	assert_eq(slot.actions.get_action_set(slot.device_id), _gameplay)


func test_panel_click_outside_closes_it() -> void:
	# Given: An open panel over a map.
	var panel := await _mount(PanelScene.instantiate())
	_std_panel(panel).open()
	await wait_process_frames(1)

	# When: A button inside the panel is clicked.
	_input.click(_list_buttons(panel)[1])

	# Then: The panel stays open.
	assert_true(panel.visible)

	# When: The map's world beside the panel is clicked.
	_input.click_at(_WORLD_POSITION)

	# Then: The panel is closed.
	assert_false(panel.visible)


func test_panel_click_on_a_hud_button_presses_it_and_closes_the_panel() -> void:
	# Given: An open panel over a map, with a HUD button beside it.
	var panel := await _mount(PanelScene.instantiate())
	_std_panel(panel).open()
	await wait_process_frames(1)

	# When: The HUD button is clicked.
	var presses := [0]
	_hud.pressed.connect(func() -> void: presses[0] += 1)
	_input.click(_hud)

	# Then: The button is pressed and the panel closed.
	assert_eq(presses[0], 1)
	assert_false(panel.visible)


func test_world_panel_follows_its_target_and_flips_at_the_edge() -> void:
	# Given: A world panel over a map, tracking a point in the map's world.
	var target := Node2D.new()
	target.position = Vector2(300, 150)
	var panel := await _mount(WorldPanelScene.instantiate(), target)

	# When: The panel is opened.
	_std_panel(panel).open()
	await wait_process_frames(1)

	# Then: It sits at the target.
	assert_eq(panel.global_position, _map.world_to_screen(target.position))

	# When: The target moves.
	target.position = Vector2(500, 250)
	await wait_process_frames(1)

	# Then: The panel follows it.
	assert_eq(panel.global_position, _map.world_to_screen(target.position))

	# When: The target moves to the right edge of the screen.
	var edge := _map.get_screen_rect().end.x - 1.0
	target.position = Vector2(edge, 250)
	await wait_process_frames(1)

	# Then: The panel flips to the target's left, its right edge at the target.
	assert_eq(panel.get_global_rect().end.x, _map.world_to_screen(target.position).x)


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


## _list_buttons returns the buttons inside `panel`, in order.
func _list_buttons(panel: Control) -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(panel.find_children("*", "Button", true, false))
	return buttons


## _make_button returns one of kit's buttons, an anchor for focus if `anchor` is set.
func _make_button(anchor: bool) -> Button:
	var button: Button = ButtonScene.instantiate()
	button.custom_minimum_size = Vector2(160, 40)
	button.get_node(^"FocusHandler").use_as_anchor = anchor
	return button


## _mount mounts a map holding the game's set, with a HUD button and `panel` in its UI,
## and returns `panel` once the map's loader has synced. `panel` holds two buttons, and
## follows `target`, added to the map's world, if it's set.
func _mount(panel: PanelContainer, target: Node2D = null) -> PanelContainer:
	_map = MapScene.instantiate()
	_map.action_set = _gameplay

	var ui := _map.get_node(^"UI")

	_hud = _make_button(false)
	_hud.position = Vector2(20, 20)
	ui.add_child(_hud)

	var rows := VBoxContainer.new()
	rows.add_child(_make_button(true))
	rows.add_child(_make_button(false))
	panel.add_child(rows)
	panel.position = _PANEL_POSITION
	ui.add_child(panel)

	if target:
		_map.sub_viewport.add_child(target)

		var tracker: KitWorldTracker2D = panel.get_node(^"WorldTracker2D")
		tracker.map = _map
		tracker.target = target

	_input = await StdTestInput.mount(self, _map)
	await wait_process_frames(1)

	return panel


## _press presses and releases `keycode`.
func _press(keycode: Key) -> void:
	_input.press_key(keycode)
	_input.release_key(keycode)


## _std_panel returns the `StdPanel` which opens and closes `panel`.
func _std_panel(panel: Control) -> StdPanel:
	return panel.get_node(^"StdPanel")
