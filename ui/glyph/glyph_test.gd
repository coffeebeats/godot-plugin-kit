##
## Unit tests for `KitInputGlyph`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GlyphScene := preload("glyph.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_keyboard_label_fits_its_box_inside_the_glyph() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to keys.
	var actions := StdInputActionSet.new()
	actions.name = &"Glyphs"
	actions.actions_digital = [&"ui_accept"] as Array[StringName]
	StdInputSlot.for_player(1).load_action_set(actions)

	# Given: A keyboard glyph for `ui_accept` with no minimum size of its own.
	var glyph: KitInputGlyph = GlyphScene.instantiate()
	glyph.custom_minimum_size = Vector2.ZERO
	glyph.always_show_kbm = true
	glyph.action_set = actions
	glyph.action = &"ui_accept"

	# When: The glyph enters the tree and draws its key's label.
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
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to several keys.
	var actions := _load_actions()

	# Given: A keyboard glyph for the action's secondary binding.
	var glyph := _create_glyph(actions)
	glyph.binding_index = StdInputDeviceActions.BINDING_INDEX_SECONDARY

	# When: The glyph enters the tree and draws its key's label.
	add_child_autofree(glyph)
	await wait_process_frames(2)

	# Then: The glyph shows the second origin's label, not the first's.
	var second := _get_origin_label(actions, 1)
	assert_ne(second, _get_origin_label(actions, 0))
	assert_eq(glyph.label.text, second)


func test_glyph_cycle_interval_advances_to_the_next_origin() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

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
	assert_eq(glyph.label.text, first)

	# Then: Once the interval elapses, the glyph shows the second origin.
	await wait_until(func(): return glyph.label.text != first, 1.0)
	assert_eq(glyph.label.text, _get_origin_label(actions, 1))


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


func _create_glyph(actions: StdInputActionSet) -> KitInputGlyph:
	var glyph: KitInputGlyph = GlyphScene.instantiate()
	glyph.always_show_kbm = true
	glyph.action_set = actions
	glyph.action = &"ui_accept"

	# NOTE: The scene shows "Kp Enter" as "Enter", which would hide which of
	# `ui_accept`'s origins the glyph draws.
	glyph.origin_label_overrides = {}

	return glyph


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
