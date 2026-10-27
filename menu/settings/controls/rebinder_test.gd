##
## Tests for the rebinder, which binds the next press from the device it listens to, and
## for its prompt, which must survive a translation that lost its placeholder.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("res://addons/std/input/godot/binding.gd")
const BindingScene := preload("binding.tscn")
const MenuActions := preload("res://system/input/actions/menu.tres")
const PlatformScene := preload("res://premade/platform.tscn")
const Rebinder := preload("rebinder.gd")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTION is the action the tests rebind.
const _ACTION := &"rebinder_test_jump"

## _ACTION_STOP is the action which cancels a rebind. The game binds it, so kit's own
## input map lacks it.
const _ACTION_STOP := &"ui_binding_stop"

## _JOYPAD is the device ID of the test joypad.
const _JOYPAD := 0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _action_set: StdInputActionSet = null
var _added_actions: Array[StringName] = []
var _manager: StdScreenManager = null
var _scope: StdSettingsScope = null
var _slot: StdInputSlot = null
var _translations: Array[Translation] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_rebinder_key_press_binds_the_keyboard_binding() -> void:
	# Given: The keyboard is active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# Given: The rebinder is open for the primary binding.
	await _start_rebinding()

	# When: A key is pressed.
	await _tap(_key(KEY_K))

	# Then: The keyboard binding is that key.
	assert_eq(_bound_keycode(StdInputDevice.DEVICE_TYPE_KEYBOARD), KEY_K)

	# Then: The rebinder is closed.
	assert_false(_is_rebinder_open())


func test_rebinder_joypad_button_binds_the_joypad_binding() -> void:
	# Given: A joypad is connected and active.
	await _activate_joypad()

	# Given: The rebinder is open for the primary binding.
	await _start_rebinding()

	# When: A joypad button is pressed.
	await _tap(_joy_button(JOY_BUTTON_X))

	# Then: The joypad binding is that button.
	assert_eq(_bound_button(StdInputDevice.DEVICE_TYPE_XBOX_ONE), JOY_BUTTON_X)

	# Then: The keyboard binding is unchanged.
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_KEYBOARD))

	# Then: The rebinder is closed.
	assert_false(_is_rebinder_open())


func test_rebinder_cancel_closes_without_binding() -> void:
	# Given: The keyboard is active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# Given: The rebinder is open for the primary binding.
	await _start_rebinding()

	# When: The keyboard's cancel key is pressed.
	await _tap(_key(KEY_ESCAPE))

	# Then: The rebinder is closed.
	assert_false(_is_rebinder_open())

	# Then: Nothing is bound.
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_KEYBOARD))


func test_rebinder_unbound_press_from_another_device_is_ignored() -> void:
	# Given: A joypad is connected and active.
	await _activate_joypad()

	# Given: The rebinder is open for the primary binding.
	await _start_rebinding()

	# When: A key bound to no active action is pressed.
	await _tap(_key(KEY_J))

	# Then: The rebinder is still open.
	assert_true(_is_rebinder_open())

	# Then: The joypad stays active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_XBOX_ONE)

	# Then: Nothing is bound.
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_XBOX_ONE))
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_KEYBOARD))


func test_rebinder_touch_emulated_click_does_not_bind() -> void:
	# Given: The keyboard is active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# Given: The rebinder is open for the primary binding.
	await _start_rebinding()

	# When: A left click which Godot emulates from a touch arrives.
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_EMULATION
	click.button_index = MOUSE_BUTTON_LEFT
	await _tap(click)

	# Then: The rebinder is still open.
	assert_true(_is_rebinder_open())

	# Then: Nothing is bound.
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_KEYBOARD))


# NOTE: This pins down today's behavior, in which the rebinder follows the active
# device. A rebinder pinned to one device should cancel here instead.
func test_rebinder_cancel_from_another_device_retargets_the_rebind() -> void:
	# Given: A joypad is connected and active.
	await _activate_joypad()

	# Given: The rebinder is open for the primary binding.
	await _start_rebinding()

	# When: The keyboard's cancel key is pressed.
	await _tap(_key(KEY_ESCAPE))

	# Then: The rebinder is still open, now listening to the keyboard.
	assert_true(_is_rebinder_open())
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# When: A key is pressed.
	await _tap(_key(KEY_K))

	# Then: The keyboard binding is that key.
	assert_eq(_bound_keycode(StdInputDevice.DEVICE_TYPE_KEYBOARD), KEY_K)

	# Then: The joypad binding is unchanged.
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_XBOX_ONE))

	# Then: The rebinder is closed.
	assert_false(_is_rebinder_open())


# NOTE: This pins down today's behavior, in which a Steam Input controller can't
# cancel a rebind or take it over, since Steam reports its presses as injected actions.
func test_rebinder_discards_an_injected_action() -> void:
	# Given: A joypad is connected, and a bound key makes the keyboard active.
	_slot.joypad_monitor.joy_connected.emit(
		_JOYPAD, StdInputDevice.DEVICE_TYPE_XBOX_ONE
	)
	await _tap(_key(KEY_ENTER))
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# Given: The rebinder is open for the primary binding.
	await _start_rebinding()

	# When: The joypad's cancel action is injected, as Steam Input reports it.
	var action := InputEventAction.new()
	action.action = _ACTION_STOP
	action.device = _JOYPAD
	await _tap(action)

	# Then: The rebinder is still open.
	assert_true(_is_rebinder_open())

	# Then: The keyboard stays active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Then: Nothing is bound.
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_KEYBOARD))


func test_rebinder_binding_row_press_rebinds_its_action_and_slot() -> void:
	# Given: The keyboard is active.
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# Given: A Controls tab row for the action's secondary binding, under the manager.
	var row: Control = BindingScene.instantiate()
	row.scope = _scope
	row.glyph.action_set = _action_set
	row.glyph.action = _ACTION
	row.glyph.binding_index = StdInputDeviceActions.BINDING_INDEX_SECONDARY
	row.glyph.player_id = 1

	var host := Control.new()
	host.add_child(row)
	_manager.add_child(host)

	# When: The row's button is pressed.
	row.button.pressed.emit()
	await wait_process_frames(2)

	# Then: The rebinder is open.
	assert_true(_is_rebinder_open())

	# When: A key is pressed.
	await _tap(_key(KEY_K))

	# Then: The row's binding is that key.
	assert_eq(
		_bound_keycode(
			StdInputDevice.DEVICE_TYPE_KEYBOARD,
			StdInputDeviceActions.BINDING_INDEX_SECONDARY,
		),
		KEY_K,
	)

	# Then: The primary binding is unchanged.
	assert_null(_binding(StdInputDevice.DEVICE_TYPE_KEYBOARD))


func test_split_placeholder_separates_the_text_around_the_placeholder() -> void:
	# Given: A translated template carrying its placeholder.
	var template := "Press any key now or %s to cancel."

	# When: The template is split.
	var parts := Rebinder._split_placeholder(template)

	# Then: The text before and after the placeholder is returned.
	assert_eq(parts, PackedStringArray(["Press any key now or ", " to cancel."]))


func test_split_placeholder_keeps_a_template_which_carries_no_placeholder() -> void:
	# Given: A template with no placeholder, as an untranslated message ID.
	var template := "kit_options_controls_rebinder_bind_or_exit"

	# When: The template is split.
	var parts := Rebinder._split_placeholder(template)

	# Then: The whole template is kept, with an empty remainder.
	assert_eq(parts, PackedStringArray([template, ""]))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _added_actions:
		InputMap.erase_action(action)
		ProjectSettings.set_setting(&"input/" + action, null)

	_added_actions.clear()

	for translation in _translations:
		TranslationServer.remove_translation(translation)

	_translations.clear()


func after_each() -> void:
	# NOTE: The game frees its main scene before the input autoload, so the manager goes
	# first here too, while the cursor its controls report hovers to still exists.
	if is_instance_valid(_manager):
		_manager.free()

	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	if is_instance_valid(_slot):
		_slot.load_action_set(StdInputActionSet.new())

	# NOTE: The rebinder reuses one instance, which the manager freed with itself, so a
	# later test must not find the freed one.
	Rebinder._instance = null


func before_all() -> void:
	# NOTE: Kit's project lists no catalogues, so this loads the shipped ones the way a
	# game's `locale/translations` setting would.
	for path in DirAccess.get_files_at("res://locale"):
		if not path.ends_with(".mo"):
			continue

		var translation: Translation = load("res://locale".path_join(path))
		TranslationServer.add_translation(translation)
		_translations.append(translation)

	var key := InputEventKey.new()
	key.device = StdInputDevice.DEVICE_ID_ALL
	key.keycode = KEY_ESCAPE

	var button := InputEventJoypadButton.new()
	button.device = StdInputDevice.DEVICE_ID_ALL
	button.button_index = JOY_BUTTON_START

	_add_action(_ACTION, [])
	_add_action(_ACTION_STOP, [key, button])


func before_each() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())
	_slot = StdInputSlot.for_player(1)

	# Given: The menu's set is active, as in the settings menu.
	_slot.load_action_set(MenuActions)

	# Given: A screen manager below the input scene, as in the game's main scene.
	_manager = StdScreenManager.new()
	add_child_autofree(_manager)
	await wait_idle_frames(1)

	# Given: A screen under the rebinder, as the settings menu is in the game.
	_manager.push(StdScreen.new(), Control.new())
	await wait_idle_frames(1)

	_scope = StdSettingsScope.new()

	_action_set = StdInputActionSet.new()
	_action_set.name = &"RebinderTest"
	_action_set.actions_digital = [_ACTION] as Array[StringName]


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action registers `action` with `events` as its default bindings, unless the
## project defines it. std reads an action's defaults from the project settings, so the
## action is added there as well as to the input map.
func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if ProjectSettings.has_setting(&"input/" + action):
		return

	ProjectSettings.set_setting(&"input/" + action, {"deadzone": 0.5, "events": events})

	InputMap.add_action(action)
	for event in events:
		InputMap.action_add_event(action, event)

	_added_actions.append(action)


## _activate_joypad connects an Xbox joypad and makes it active with a press of
## `ui_accept`, which the engine binds to its A button.
func _activate_joypad() -> void:
	_slot.joypad_monitor.joy_connected.emit(
		_JOYPAD, StdInputDevice.DEVICE_TYPE_XBOX_ONE
	)
	await _tap(_joy_button(JOY_BUTTON_A))
	assert_eq(_active_type(), StdInputDevice.DEVICE_TYPE_XBOX_ONE, "precondition")


func _active_type() -> StdInputDevice.DeviceType:
	var device := _slot.get_active_device()
	return device.device_type if device else StdInputDevice.DEVICE_TYPE_UNKNOWN


func _binding(
	device_type: StdInputDevice.DeviceType,
	index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
) -> InputEvent:
	# NOTE: Bindings are stored per device category, as the rebinder binds them.
	var category := StdInputDevice.get_device_category(device_type)
	return Bindings.get_action_binding(_scope, _action_set, _ACTION, category, index)


func _bound_button(device_type: StdInputDevice.DeviceType) -> JoyButton:
	var binding := _binding(device_type)
	return (
		(binding as InputEventJoypadButton).button_index
		if binding is InputEventJoypadButton
		else JOY_BUTTON_INVALID
	)


func _bound_keycode(
	device_type: StdInputDevice.DeviceType,
	index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
) -> Key:
	var binding := _binding(device_type, index)
	return (binding as InputEventKey).keycode if binding is InputEventKey else KEY_NONE


func _is_rebinder_open() -> bool:
	return not StdGroup.is_empty(Rebinder.GROUP_REBINDER)


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = _JOYPAD
	event.button_index = button
	return event


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event


func _start_rebinding() -> void:
	(
		Rebinder
		. start_rebinding(
			_manager,
			_scope,
			_action_set,
			_ACTION,
			StdInputDeviceActions.BINDING_INDEX_PRIMARY,
			1,
		)
	)
	await wait_process_frames(2)
	assert_true(_is_rebinder_open(), "precondition")


## _tap presses `event`, then releases a copy of it, letting the frames pass which
## deliver each to the scene's input callbacks.
func _tap(event: InputEvent) -> void:
	var release: InputEvent = event.duplicate()

	event.set(&"pressed", true)
	Input.parse_input_event(event)
	await wait_process_frames(2)

	release.set(&"pressed", false)
	Input.parse_input_event(release)
	await wait_process_frames(2)
