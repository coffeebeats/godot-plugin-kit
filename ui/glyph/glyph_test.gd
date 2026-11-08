##
## Unit tests for `KitInputGlyph`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GlyphScene := preload("glyph.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("res://system/input/input.gd")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_keyboard_key_is_one_and_a_half_lines_of_text_tall() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to Enter.
	var actions := _load_actions()

	# Given: A keyboard glyph for `ui_accept`.
	var glyph := _create_glyph(actions)

	# When: The glyph enters the tree and draws its key.
	add_child_autofree(glyph)
	await wait_process_frames(1)

	# Then: The key is one and a half lines of the theme's text tall, and wider than tall.
	var texture := glyph.get_glyph()
	assert_true(texture.has_glyph())
	assert_eq(texture.get_height(), roundi(_get_line_height(glyph) * 1.5))
	assert_gt(texture.get_width(), texture.get_height())

	# Then: The glyph is as large as the key, so it doesn't spill onto a neighbour.
	assert_eq(glyph.get_combined_minimum_size(), texture.get_size())


func test_glyph_keyboard_key_follows_the_text_size() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to Enter.
	var actions := _load_actions()

	# Given: A keyboard glyph in the tree under a theme, drawing its key.
	var host := Control.new()
	host.theme = Theme.new()
	host.theme.default_font_size = 16
	add_child_autofree(host)

	var glyph := _create_glyph(actions)
	host.add_child(glyph)
	await wait_process_frames(1)
	var before := glyph.get_glyph().get_height()

	# When: The player's text size doubles the theme's font size.
	host.theme.default_font_size = 32
	await wait_process_frames(1)

	# Then: The key grows with the text, to one and a half lines of it.
	assert_gt(glyph.get_glyph().get_height(), before)
	assert_eq(glyph.get_glyph().get_height(), roundi(_get_line_height(glyph) * 1.5))


func test_glyph_glyph_scale_multiplies_the_line_height() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to Enter.
	var actions := _load_actions()

	# Given: A keyboard glyph two lines of text tall.
	var glyph := _create_glyph(actions)
	glyph.glyph_scale = 2.0

	# When: The glyph enters the tree and draws its key.
	add_child_autofree(glyph)
	await wait_process_frames(1)

	# Then: The key is two lines tall.
	assert_eq(glyph.get_glyph().get_height(), roundi(_get_line_height(glyph) * 2.0))


func test_glyph_secondary_binding_draws_the_second_origin() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to several keys.
	var actions := _load_actions()

	# Given: A keyboard glyph for the action's secondary binding.
	var glyph := _create_glyph(actions)
	glyph.binding_index = StdInputDeviceActions.BINDING_INDEX_SECONDARY

	# When: The glyph enters the tree and draws its key.
	add_child_autofree(glyph)
	await wait_process_frames(1)

	# Then: The glyph draws the second origin, not the first.
	var second := _get_origin_label(actions, 1)
	assert_ne(second, _get_origin_label(actions, 0))
	assert_eq(glyph.get_glyph().get_origin_label(), second)


func test_glyph_cycle_interval_advances_to_the_next_origin() -> void:
	# Given: A platform whose profile loaded, and the input scene drawing keys by name.
	add_child_autofree(PlatformScene.instantiate())
	_add_input_with_unabbreviated_keys()

	# Given: A loaded set holding `ui_accept`, which the engine binds to several keys.
	var actions := _load_actions()

	# Given: A keyboard glyph in the tree, drawing the primary binding.
	var glyph := _create_glyph(actions)
	add_child_autofree(glyph)
	await wait_process_frames(1)

	# When: The glyph starts cycling through every origin.
	glyph.cycle_interval = 0.05

	# Then: The glyph restarts at the first origin.
	var first := _get_origin_label(actions, 0)
	assert_eq(glyph.get_glyph().get_origin_label(), first)

	# Then: Once the interval elapses, the glyph shows the second origin.
	await wait_until(func(): return glyph.get_glyph().get_origin_label() != first, 1.0)
	assert_eq(glyph.get_glyph().get_origin_label(), _get_origin_label(actions, 1))


func test_glyph_always_show_kbm_and_joy_lock_the_device_type() -> void:
	# Given: A glyph.
	var glyph: KitInputGlyph = autofree(GlyphScene.instantiate())

	# When: The glyph always shows the keyboard.
	glyph.always_show_kbm = true

	# Then: Its texture is locked to the keyboard.
	assert_eq(glyph.get_glyph().device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# When: The glyph always shows a controller instead.
	glyph.always_show_joy = true

	# Then: Its texture is locked to a controller, and no longer to the keyboard.
	assert_eq(glyph.get_glyph().device_type, StdInputDevice.DEVICE_TYPE_GENERIC)
	assert_false(glyph.always_show_kbm)


func test_glyph_hide_if_cursor_visible_keeps_joypad_glyph_shown() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to joypad A.
	var actions := _load_actions()

	# Given: A connected joypad, made active by a press of `ui_accept`.
	var slot := StdInputSlot.for_player(1)
	slot.joypad_monitor.joy_connected.emit(0, StdInputDevice.DEVICE_TYPE_XBOX_ONE)
	_press_joypad_button(JOY_BUTTON_A)
	assert_eq(slot.device_type, StdInputDevice.DEVICE_TYPE_XBOX_ONE, "precondition")

	# Given: A glyph for the active device which hides while the cursor is visible.
	var glyph := _create_glyph(actions)
	glyph.always_show_kbm = false
	glyph.hide_if_cursor_visible = true
	add_child_autofree(glyph)
	await wait_process_frames(1)
	assert_not_null(glyph.texture, "precondition")

	# When: The cursor is revealed while the joypad stays active.
	KitSystems.input().show_cursor()
	await wait_process_frames(1)
	assert_true(slot.cursor.get_is_visible())
	assert_eq(slot.device_type, StdInputDevice.DEVICE_TYPE_XBOX_ONE)

	# Then: The glyph still shows the joypad's binding.
	assert_not_null(glyph.texture)


func test_glyph_hide_if_cursor_visible_hides_keyboard_glyph() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to keys.
	var actions := _load_actions()

	# Given: A keyboard glyph which hides while the cursor is visible.
	var glyph := _create_glyph(actions)
	glyph.hide_if_cursor_visible = true
	add_child_autofree(glyph)
	await wait_process_frames(1)

	# Given: The keyboard is active and the cursor is hidden.
	var slot := StdInputSlot.for_player(1)
	slot.cursor.hide_cursor()
	await wait_process_frames(1)
	assert_false(slot.cursor.get_is_visible())
	assert_eq(slot.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)
	assert_not_null(glyph.texture, "precondition")

	# When: The cursor is revealed.
	KitSystems.input().show_cursor()
	await wait_process_frames(1)

	# Then: The glyph is hidden.
	assert_null(glyph.texture)


func test_glyph_controller_prompt_lock_draws_the_connected_joypad_family() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to Enter and A.
	var actions := _load_actions()

	# Given: A connected PlayStation joypad.
	var slot := StdInputSlot.for_player(1)
	slot.joypad_monitor.joy_connected.emit(0, StdInputDevice.DEVICE_TYPE_PS_5)

	# Given: A key press makes the keyboard active.
	_press_key(KEY_ENTER)
	assert_eq(slot.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD, "precondition")

	# Given: A button prompt setting locked to controller prompts.
	var prompt := StdSettingsPropertyInt.new()
	prompt.category = &"controls"
	prompt.name = &"glyph/type"
	prompt.scope = StdSettingsScope.new()
	prompt.set_value(StdInputDevice.DEVICE_TYPE_GENERIC)

	# Given: A glyph which reads that setting.
	var glyph := _create_glyph(actions)
	glyph.always_show_kbm = false
	glyph.device_type_override = prompt

	# When: The glyph enters the tree.
	add_child_autofree(glyph)
	await wait_process_frames(1)

	# Then: The glyph draws the connected joypad's button, not the keyboard's key.
	var expected := slot.get_action_origin_label(
		actions, &"ui_accept", 0, StdInputDevice.DEVICE_TYPE_PS_5
	)
	assert_ne(expected, _get_origin_label(actions, 0), "precondition")
	assert_eq(glyph.get_glyph().get_origin_label(), expected)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_input_with_unabbreviated_keys adds the input scene with kit's keyboard set
## drawing each key by its own name. The glyph cycles through distinct glyphs, and
## "Enter" for "Kp Enter" would draw two of `ui_accept`'s origins alike.
func _add_input_with_unabbreviated_keys() -> void:
	var input: SystemInput = SystemInputScene.instantiate()

	var glyph_sets: Array[StdInputGlyphSet] = []
	for glyph_set in input.glyph_sets:
		if glyph_set is StdInputGlyphSetKeyboardDrawn:
			glyph_set = glyph_set.duplicate()
			var labels: Dictionary[String, String] = {}
			glyph_set.labels = labels

		glyph_sets.append(glyph_set)

	input.glyph_sets = glyph_sets
	add_child_autofree(input)


func _create_glyph(actions: StdInputActionSet) -> KitInputGlyph:
	var glyph: KitInputGlyph = GlyphScene.instantiate()
	glyph.always_show_kbm = true
	glyph.action_set = actions
	glyph.action = &"ui_accept"
	return glyph


## _get_line_height returns the height of a line of the theme's text at `control`.
func _get_line_height(control: Control) -> float:
	var font := control.get_theme_default_font()
	return font.get_height(control.get_theme_default_font_size())


func _get_origin_label(actions: StdInputActionSet, index: int) -> String:
	return (
		StdInputSlot
		. for_player(1)
		. get_action_origin_label(
			actions,
			&"ui_accept",
			index,
			StdInputDevice.DEVICE_TYPE_KEYBOARD,
		)
	)


func _load_actions() -> StdInputActionSet:
	var actions := StdInputActionSet.new()
	actions.name = &"Glyphs"
	actions.actions_digital = [&"ui_accept"] as Array[StringName]
	StdInputSlot.for_player(1).load_action_set(actions)
	return actions


func _press_joypad_button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
