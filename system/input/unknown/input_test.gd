##
## Tests for the input system's Godot implementation, which draws glyphs from the game's
## `glyph_sets` and `unknown_glyph`, and for the art in kit's own sets.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ArrowUp := preload("glyphs/keyboard/arrow_up.svg")
const KeycapTexture := preload("res://addons/std/input/godot/keycap_texture.gd")
const PlatformScene := preload("res://premade/platform.tscn")
const PlayStationCreate := preload("glyphs/playstation/create.png")
const PlayStationShare := preload("glyphs/playstation/share.png")
const SteamDeckView := preload("glyphs/steam_deck/view.png")
const SwitchA := preload("glyphs/switch/a.png")
const SwitchB := preload("glyphs/switch/b.png")
const SwitchMinus := preload("glyphs/switch/minus.png")
const SwitchX := preload("glyphs/switch/x.png")
const SwitchY := preload("glyphs/switch/y.png")
const SystemInput := preload("res://system/input/input.gd")
const SystemInputScene := preload("res://system/input/input.tscn")
const Unknown := preload("glyphs/unknown.svg")
const XboxBack := preload("glyphs/xbox/back.png")
const XboxView := preload("glyphs/xbox/view.png")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _GAPS_ON_EVERY_PAD lists the buttons no set of kit's has art for, which draw the
## unknown glyph on every joypad.
const _GAPS_ON_EVERY_PAD := [
	JOY_BUTTON_GUIDE,
	JOY_BUTTON_PADDLE1,
	JOY_BUTTON_PADDLE2,
	JOY_BUTTON_PADDLE3,
	JOY_BUTTON_PADDLE4,
	JOY_BUTTON_MISC2,
	JOY_BUTTON_MISC3,
	JOY_BUTTON_MISC4,
	JOY_BUTTON_MISC5,
	JOY_BUTTON_MISC6,
]

## _GAPS lists, by joypad type, the further buttons kit's sets have no art for.
const _GAPS := {
	StdInputDevice.DEVICE_TYPE_GENERIC: [JOY_BUTTON_TOUCHPAD],
	StdInputDevice.DEVICE_TYPE_PS_4: [],
	StdInputDevice.DEVICE_TYPE_PS_5: [],
	StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER:
	[
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
		JOY_BUTTON_MISC1,
		JOY_BUTTON_TOUCHPAD,
	],
	StdInputDevice.DEVICE_TYPE_STEAM_DECK: [JOY_BUTTON_MISC1, JOY_BUTTON_TOUCHPAD],
	StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR:
	[JOY_BUTTON_MISC1, JOY_BUTTON_TOUCHPAD],
	StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE:
	[JOY_BUTTON_MISC1, JOY_BUTTON_TOUCHPAD],
	StdInputDevice.DEVICE_TYPE_SWITCH_PRO: [JOY_BUTTON_MISC1, JOY_BUTTON_TOUCHPAD],
	StdInputDevice.DEVICE_TYPE_XBOX_360: [JOY_BUTTON_TOUCHPAD],
	StdInputDevice.DEVICE_TYPE_XBOX_ONE: [JOY_BUTTON_TOUCHPAD],
}

# -- INITIALIZATION ------------------------------------------------------------------ #

var _added_actions: Array[StringName] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyphs_game_set_ahead_of_kits_overrides_only_its_own_keys() -> void:
	# Given: A game set with art for the Escape key alone.
	var game_set := StdInputGlyphSetKeyboard.new()
	game_set.device_types = [StdInputDevice.DEVICE_TYPE_KEYBOARD]
	game_set.cmd_escape = PlaceholderTexture2D.new()

	# Given: The input scene, with the game's set ahead of kit's.
	add_child_autofree(PlatformScene.instantiate())
	var input: SystemInput = SystemInputScene.instantiate()
	var glyph_sets: Array[StdInputGlyphSet] = [game_set]
	glyph_sets.append_array(input.glyph_sets)
	input.glyph_sets = glyph_sets
	add_child_autofree(input)

	# Given: A loaded set holding `ui_cancel` and `ui_accept`, on Escape and Enter.
	var actions := _load_actions([&"ui_cancel", &"ui_accept"])

	# When: The keyboard's glyphs are drawn for both actions.
	var cancel := _get_glyph(actions, &"ui_cancel", StdInputDevice.DEVICE_TYPE_KEYBOARD)
	var accept := _get_glyph(actions, &"ui_accept", StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Then: Escape draws the game's art.
	assert_eq(cancel, game_set.cmd_escape)

	# Then: Enter, which the game's set has no art for, draws kit's keycap.
	assert_is(accept, KeycapTexture)
	assert_eq(accept.label, "Enter")


func test_glyphs_keyboard_letter_draws_a_keycap_with_its_label() -> void:
	# Given: The input scene with kit's glyph sets.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_text_select_all`, which the engine binds to A.
	var actions := _load_actions([&"ui_text_select_all"])

	# When: The keyboard's glyph is drawn for the action.
	var glyph := _get_glyph(
		actions, &"ui_text_select_all", StdInputDevice.DEVICE_TYPE_KEYBOARD
	)

	# Then: The glyph is a keycap labelled with the key's letter.
	assert_is(glyph, KeycapTexture)
	assert_eq(glyph.label, "A")


func test_glyphs_keyboard_named_key_draws_its_abbreviation() -> void:
	# Given: The input scene with kit's glyph sets.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_cancel`, which the engine binds to Escape.
	var actions := _load_actions([&"ui_cancel"])

	# When: The keyboard's glyph is drawn for the action.
	var glyph := _get_glyph(actions, &"ui_cancel", StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Then: The keycap names the key by its abbreviation.
	assert_is(glyph, KeycapTexture)
	assert_eq(glyph.label, "Esc")


func test_glyphs_keyboard_arrow_draws_its_icon() -> void:
	# Given: The input scene with kit's glyph sets.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_up`, which the engine binds to the up arrow.
	var actions := _load_actions([&"ui_up"])

	# When: The keyboard's glyph is drawn for the action.
	var glyph := _get_glyph(actions, &"ui_up", StdInputDevice.DEVICE_TYPE_KEYBOARD)

	# Then: The keycap draws the arrow icon in place of a label.
	assert_is(glyph, KeycapTexture)
	assert_eq(glyph.icon, ArrowUp)
	assert_eq(glyph.label, "")


func test_glyphs_joypad_button_with_no_art_draws_kits_unknown_glyph() -> void:
	# Given: The input scene with kit's glyph sets and unknown glyph.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_up`, which the engine binds to the d-pad's up.
	var actions := _load_actions([&"ui_up"])

	# When: A Steam Controller's glyph, whose set has no d-pad art, is drawn for it.
	var glyph := _get_glyph(
		actions, &"ui_up", StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER
	)

	# Then: The glyph is kit's unknown glyph.
	assert_eq(glyph, Unknown)


func test_glyphs_game_unknown_glyph_replaces_kits() -> void:
	# Given: The input scene, with the game's own unknown glyph.
	add_child_autofree(PlatformScene.instantiate())
	var input: SystemInput = SystemInputScene.instantiate()
	input.unknown_glyph = PlaceholderTexture2D.new()
	add_child_autofree(input)

	# Given: A loaded set holding `ui_up`, which the engine binds to the d-pad's up.
	var actions := _load_actions([&"ui_up"])

	# When: A Steam Controller's glyph, whose set has no d-pad art, is drawn for it.
	var glyph := _get_glyph(
		actions, &"ui_up", StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER
	)

	# Then: The glyph is the game's unknown glyph.
	assert_eq(glyph, input.unknown_glyph)


func test_glyphs_back_draws_each_pads_own_button() -> void:
	# Given: The input scene with kit's glyph sets.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding an action on the pad's Back button.
	_add_action(&"glyphs_test_back", JOY_BUTTON_BACK)
	var actions := _load_actions([&"glyphs_test_back"])

	# Given: Each pad's Back art, with a generic pad sharing the Xbox 360's.
	var expected := {
		StdInputDevice.DEVICE_TYPE_GENERIC: XboxBack,
		StdInputDevice.DEVICE_TYPE_XBOX_360: XboxBack,
		StdInputDevice.DEVICE_TYPE_XBOX_ONE: XboxView,
		StdInputDevice.DEVICE_TYPE_PS_4: PlayStationShare,
		StdInputDevice.DEVICE_TYPE_PS_5: PlayStationCreate,
		StdInputDevice.DEVICE_TYPE_SWITCH_PRO: SwitchMinus,
		StdInputDevice.DEVICE_TYPE_STEAM_DECK: SteamDeckView,
	}

	for device_type in expected:
		# When: The pad's glyph is drawn for the action.
		var glyph := _get_glyph(actions, &"glyphs_test_back", device_type)

		# Then: The glyph is that pad's own button.
		assert_eq(
			glyph,
			expected[device_type],
			StdInputDevice.DeviceType.find_key(device_type),
		)


func test_glyphs_switch_face_buttons_draw_the_button_in_their_position() -> void:
	# Given: The input scene with kit's glyph sets.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: Godot's face buttons, which go by position, and the Nintendo button in each.
	var expected := {
		JOY_BUTTON_A: SwitchB,
		JOY_BUTTON_B: SwitchA,
		JOY_BUTTON_X: SwitchY,
		JOY_BUTTON_Y: SwitchX,
	}

	# Given: A loaded set holding an action on each face button.
	var names: Array[StringName] = []
	for button in expected:
		names.append(StringName("glyphs_test_face_%d" % button))
		_add_action(names[-1], button)
	var actions := _load_actions(names)

	for i in names.size():
		# When: A Switch Pro controller's glyph is drawn for the action.
		var glyph := _get_glyph(
			actions, names[i], StdInputDevice.DEVICE_TYPE_SWITCH_PRO
		)

		# Then: The glyph is the Nintendo button in that position.
		assert_eq(glyph, expected.values()[i], names[i])


func test_glyph_sets_have_art_for_every_pad_origin_except_the_listed_gaps() -> void:
	# Given: Kit's glyph sets, read from the input scene.
	var input: SystemInput = autofree(SystemInputScene.instantiate())

	# When: Each joypad type's matching sets are searched for art for each origin.
	#
	# NOTE: This reads the sets rather than drawing through the provider, which would
	# return the unknown glyph for a gap and so never fail.
	var mismatched: Array[String] = []
	for device_type in StdInputDevice.DeviceType.values():
		if (
			device_type
			in [
				StdInputDevice.DEVICE_TYPE_UNKNOWN,
				StdInputDevice.DEVICE_TYPE_KEYBOARD,
				StdInputDevice.DEVICE_TYPE_TOUCH,
			]
		):
			continue

		var sets := input.glyph_sets.filter(
			func(glyph_set): return glyph_set.matches(device_type)
		)
		var gaps: Array = _GAPS_ON_EVERY_PAD + _GAPS.get(device_type, [])

		for event in _list_pad_origins():
			var has_art := sets.any(
				func(glyph_set): return glyph_set.get_origin_glyph(event) != null
			)
			var is_gap: bool = (
				event is InputEventJoypadButton and event.button_index in gaps
			)
			if has_art == is_gap:
				(
					mismatched
					. append(
						(
							"%s: %s"
							% [
								StdInputDevice.DeviceType.find_key(device_type),
								event.as_text(),
							]
						)
					)
				)

	# Then: Art is missing for the listed gaps and nothing else.
	assert_eq(mismatched, [] as Array[String])


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


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action registers `action` with `button` as its default binding, unless it's
## already registered. std reads an action's defaults from the project settings, so the
## action is added there as well as to the input map.
func _add_action(action: StringName, button: JoyButton) -> void:
	if ProjectSettings.has_setting(&"input/" + action):
		return

	var event := InputEventJoypadButton.new()
	event.button_index = button
	ProjectSettings.set_setting(
		&"input/" + action, {"deadzone": 0.5, "events": [event]}
	)

	InputMap.add_action(action)
	InputMap.action_add_event(action, event)

	_added_actions.append(action)


func _get_glyph(
	actions: StdInputActionSet,
	action: StringName,
	device_type: StdInputDevice.DeviceType,
) -> Texture2D:
	return StdInputSlot.for_player(1).get_action_glyph(
		actions, action, 0, Vector2.ZERO, device_type
	)


func _list_pad_origins() -> Array[InputEvent]:
	var origins: Array[InputEvent] = []

	for button in JOY_BUTTON_SDL_MAX:
		var event := InputEventJoypadButton.new()
		event.button_index = button as JoyButton
		origins.append(event)

	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		for value in [-1.0, 1.0]:
			var event := InputEventJoypadMotion.new()
			event.axis = axis
			event.axis_value = value
			origins.append(event)

	for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = 1.0
		origins.append(event)

	return origins


func _load_actions(names: Array[StringName]) -> StdInputActionSet:
	var actions := StdInputActionSet.new()
	actions.name = &"Glyphs"
	actions.actions_digital = names
	StdInputSlot.for_player(1).load_action_set(actions)
	return actions
