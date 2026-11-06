##
## Unit tests for `KitInputGlyph`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GlyphScene := preload("glyph.tscn")
const KeycapTexture := preload("res://addons/std/input/godot/keycap_texture.gd")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("res://system/input/input.gd")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_keyboard_key_draws_a_keycap_at_its_full_width() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to Enter.
	var actions := _load_actions()

	# Given: A keyboard glyph for `ui_accept` at the scene's size.
	var glyph := _create_glyph(actions)

	# When: The glyph enters the tree and draws its key.
	add_child_autofree(glyph)
	await wait_process_frames(2)

	# Then: The glyph draws a keycap at its minimum height, wider than it is tall.
	var keycap := glyph.texture_rect.texture as KeycapTexture
	assert_not_null(keycap)
	assert_eq(keycap.get_height(), roundi(glyph.custom_minimum_size.y))
	assert_gt(keycap.get_width(), keycap.get_height())

	# Then: The glyph is wide enough for the whole keycap.
	assert_gte(glyph.get_combined_minimum_size().x, float(keycap.get_width()))


func test_glyph_fallback_label_fits_its_box_inside_the_glyph() -> void:
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

	# Given: A glyph for the active device with no minimum size of its own.
	var glyph := _create_glyph(actions)
	glyph.custom_minimum_size = Vector2.ZERO
	glyph.always_show_kbm = false

	# Given: A fallback label, which shows since the headless joypad has no glyph.
	glyph.fallback_label = "--"

	# When: The glyph enters the tree and draws its fallback label.
	add_child_autofree(glyph)
	await wait_process_frames(2)

	# Then: The glyph shows a label whose box pads it.
	assert_true(glyph.label.visible)
	var box := glyph.panel_container.get_combined_minimum_size()
	assert_gt(box.x, glyph.label.get_combined_minimum_size().x)

	# Then: The glyph is at least as large as that box.
	var size := glyph.get_combined_minimum_size()
	assert_eq(size.max(box), size)


func test_glyph_secondary_binding_draws_the_second_origin() -> void:
	# Given: A platform whose profile loaded, and the input scene drawing keys by name.
	add_child_autofree(PlatformScene.instantiate())
	_add_input_with_unabbreviated_keys()

	# Given: A loaded set holding `ui_accept`, which the engine binds to several keys.
	var actions := _load_actions()

	# Given: A keyboard glyph for the action's secondary binding.
	var glyph := _create_glyph(actions)
	glyph.binding_index = StdInputDeviceActions.BINDING_INDEX_SECONDARY

	# When: The glyph enters the tree and draws its key.
	add_child_autofree(glyph)
	await wait_process_frames(2)

	# Then: The glyph draws the second origin's key, not the first's.
	var second := _get_origin_label(actions, 1)
	assert_ne(second, _get_origin_label(actions, 0))
	assert_eq(_get_keycap_label(glyph), second)


func test_glyph_cycle_interval_advances_to_the_next_origin() -> void:
	# Given: A platform whose profile loaded, and the input scene drawing keys by name.
	add_child_autofree(PlatformScene.instantiate())
	_add_input_with_unabbreviated_keys()

	# Given: A loaded set holding `ui_accept`, which the engine binds to several keys.
	var actions := _load_actions()

	# Given: A keyboard glyph in the tree, drawing the primary binding.
	var glyph := _create_glyph(actions)
	add_child_autofree(glyph)
	await wait_process_frames(2)

	# When: The glyph starts cycling through every origin.
	glyph.cycle_interval = 0.05

	# Then: The glyph restarts at the first origin.
	var first := _get_origin_label(actions, 0)
	assert_eq(_get_keycap_label(glyph), first)

	# Then: Once the interval elapses, the glyph shows the second origin.
	await wait_until(func(): return _get_keycap_label(glyph) != first, 1.0)
	assert_eq(_get_keycap_label(glyph), _get_origin_label(actions, 1))


func test_glyph_origin_labels_changed_redraws_the_key_label() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to keys.
	var actions := _load_actions()

	# Given: A keyboard glyph drawing the first origin's key.
	var glyph := _create_glyph(actions)
	add_child_autofree(glyph)
	await wait_process_frames(2)
	var expected := _get_keycap_label(glyph)
	assert_ne(expected, "", "precondition")

	# Given: The glyph's drawn key is cleared.
	glyph.texture_rect.texture = null

	# When: The slot reports that its origins' labels changed.
	StdInputSlot.for_player(1).origin_labels_changed.emit()

	# Then: The glyph draws the current key again.
	assert_eq(_get_keycap_label(glyph), expected)


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
	assert_eq(slot.device_type, StdInputDevice.DEVICE_TYPE_XBOX_ONE)

	# Given: A glyph for the active device which hides while the cursor is visible.
	var glyph := _create_glyph(actions)
	glyph.always_show_kbm = false
	glyph.hide_if_cursor_visible = true

	# NOTE: The headless joypad has no glyph or label, and a hidden glyph skips its
	# fallback, so the fallback label shows whether the glyph is hidden.
	glyph.fallback_label = "Fallback"

	add_child_autofree(glyph)
	await wait_process_frames(2)
	assert_true(_is_glyph_shown(glyph))

	# When: The cursor is revealed while the joypad stays active.
	KitSystems.input().show_cursor()
	await wait_process_frames(1)
	assert_true(slot.cursor.get_is_visible())
	assert_eq(slot.device_type, StdInputDevice.DEVICE_TYPE_XBOX_ONE)

	# Then: The glyph still shows the joypad's binding.
	assert_true(_is_glyph_shown(glyph))


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
	await wait_process_frames(2)

	# Given: The keyboard is active and the cursor is hidden.
	var slot := StdInputSlot.for_player(1)
	slot.cursor.hide_cursor()
	await wait_process_frames(1)
	assert_false(slot.cursor.get_is_visible())
	assert_eq(slot.device_type, StdInputDevice.DEVICE_TYPE_KEYBOARD)
	assert_true(_is_glyph_shown(glyph))

	# When: The cursor is revealed.
	KitSystems.input().show_cursor()
	await wait_process_frames(1)

	# Then: The glyph is hidden.
	assert_false(_is_glyph_shown(glyph))


func test_glyph_controller_prompt_lock_draws_the_connected_joypad_family() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to keys.
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
	await wait_process_frames(2)

	# Then: The glyph draws the connected joypad's family, not the keyboard's.
	assert_eq(glyph._get_device_type(), StdInputDevice.DEVICE_TYPE_PS_5)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_input_with_unabbreviated_keys adds the input scene with kit's keyboard set
## drawing each key by its own name, since "Enter" for "Kp Enter" would hide which of
## `ui_accept`'s origins a glyph draws.
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


func _get_keycap_label(glyph: KitInputGlyph) -> String:
	var keycap := glyph.texture_rect.texture as KeycapTexture
	return keycap.label if keycap else ""


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


func _is_glyph_shown(glyph: KitInputGlyph) -> bool:
	return glyph.label.visible or glyph.texture_rect.visible


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
