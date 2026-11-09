##
## Tests for the input system's Godot implementation, which draws glyphs from the game's
## `glyph_sets` and `unknown_glyph`, names origins from its `origin_names` and runs
## holds in the player's chosen mode, and for the art and names in kit's own sets.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ArrowUp := preload("glyphs/keyboard/arrow_up.svg")
const HoldModeProperty := preload(
	"res://system/setting/controls/hold_mode_property.tres"
)
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

## _added_actions are the actions the tests registered, removed once they all end.
var _added_actions: Array[StringName] = []

## _translations holds kit's shipped catalogues while the tests run.
var _translations: Array[Translation] = []

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


func test_labels_name_each_pads_own_buttons() -> void:
	# Given: The input scene with kit's origin names.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding an action on the south face button and on Back.
	_add_action(&"labels_test_south", JOY_BUTTON_A)
	_add_action(&"labels_test_back", JOY_BUTTON_BACK)
	var actions := _load_actions([&"labels_test_south", &"labels_test_back"])

	# Given: Each pad's names for the two buttons, with the south button positional.
	var expected := {
		StdInputDevice.DEVICE_TYPE_GENERIC: ["A", "Back"],
		StdInputDevice.DEVICE_TYPE_XBOX_360: ["A", "Back"],
		StdInputDevice.DEVICE_TYPE_XBOX_ONE: ["A", "View"],
		StdInputDevice.DEVICE_TYPE_PS_4: ["Cross", "Share"],
		StdInputDevice.DEVICE_TYPE_PS_5: ["Cross", "Create"],
		StdInputDevice.DEVICE_TYPE_SWITCH_PRO: ["B", "−"],
		StdInputDevice.DEVICE_TYPE_STEAM_DECK: ["A", "View"],
		StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER: ["A", "Back"],
	}

	for device_type in expected:
		# When: The pad's labels are read for both actions.
		var got := [
			_get_label(actions, &"labels_test_south", device_type),
			_get_label(actions, &"labels_test_back", device_type),
		]

		# Then: Each button reads as that pad names it.
		assert_eq(
			got, expected[device_type], StdInputDevice.DeviceType.find_key(device_type)
		)


func test_labels_leave_a_button_a_pad_lacks_unnamed() -> void:
	# Given: The input scene with kit's origin names.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding an action on the misc button, which not every pad has.
	_add_action(&"labels_test_misc", JOY_BUTTON_MISC1)
	var actions := _load_actions([&"labels_test_misc"])

	# Given: Each pad's name for the button, empty where the pad has none.
	var expected := {
		StdInputDevice.DEVICE_TYPE_XBOX_ONE: "Share",
		StdInputDevice.DEVICE_TYPE_PS_5: "Mute",
		StdInputDevice.DEVICE_TYPE_SWITCH_PRO: "Capture",
		StdInputDevice.DEVICE_TYPE_STEAM_DECK: "",
		StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER: "",
	}

	for device_type in expected:
		# When: The pad's label is read for the action.
		var got := _get_label(actions, &"labels_test_misc", device_type)

		# Then: The button reads as that pad names it, or not at all.
		assert_eq(
			got, expected[device_type], StdInputDevice.DeviceType.find_key(device_type)
		)


func test_labels_name_a_mouse_button_and_a_named_key() -> void:
	# Given: The input scene with kit's origin names.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: An action on the left mouse button.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_add_action_event(&"labels_test_click", click)

	# Given: A loaded set holding it and `ui_accept`, which the engine binds to Enter.
	var actions := _load_actions([&"labels_test_click", &"ui_accept"])

	# When: The keyboard's labels are read for both actions.
	var got_click := _get_label(
		actions, &"labels_test_click", StdInputDevice.DEVICE_TYPE_KEYBOARD
	)
	var got_accept := _get_label(
		actions, &"ui_accept", StdInputDevice.DEVICE_TYPE_KEYBOARD
	)

	# Then: The mouse button and the key are named.
	assert_eq(got_click, "Left Mouse Button")
	assert_eq(got_accept, "Enter")


func test_origin_names_have_english_text_for_every_key() -> void:
	# Given: Kit's origin names, read from the input scene.
	var input: SystemInput = autofree(SystemInputScene.instantiate())

	# Given: Kit's English catalogue, which any other locale falls back to.
	#
	# NOTE: This reads the hand-edited catalogue rather than the compiled one, so a key
	# can't pass on a stale `.mo`.
	var english: Translation = load("res://locale/en_US.po")

	# When: Each key in each of kit's names is looked up in its names' context.
	var missing: Array[String] = []
	for names: StdInputOriginNames in input.origin_names:
		var keys: Array = (
			names.joy_buttons.values()
			+ names.joy_axes_negative.values()
			+ names.joy_axes_positive.values()
			+ names.mouse_buttons.values()
			+ names.keyboard_keys.values()
		)
		for key in keys:
			if not english.get_message(key, names.translation_context):
				missing.append("%s (%s)" % [key, names.translation_context])

	# Then: Every key has English text.
	assert_eq(missing, [] as Array[String])


func test_slot_hold_mode_setting_chooses_a_declared_holds_mode() -> void:
	# Given: A platform and the input scene.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Then: The first player's slot reads kit's hold mode setting.
	var slot := StdInputSlot.for_player(1)
	assert_eq(slot.hold_mode_property, HoldModeProperty)

	# Given: A loaded set declaring a hold on `ui_accept`, in the game's `HOLD` mode.
	_load_hold(&"ui_accept", StdInputActionHold.MODE_HOLD)

	# When: The player chooses to toggle holds.
	HoldModeProperty.set_value(StdInputActionHold.MODE_TOGGLE)

	# Then: The hold runs as a toggle.
	assert_eq(slot.get_action_hold_mode(&"ui_accept"), StdInputActionHold.MODE_TOGGLE)


func test_slot_hold_mode_setting_at_game_default_runs_the_holds_own_mode() -> void:
	# Given: A platform and the input scene.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set declaring a hold on `ui_accept`, in the game's `TOGGLE` mode.
	_load_hold(&"ui_accept", StdInputActionHold.MODE_TOGGLE)

	# When: The player leaves the setting at the game's default.
	HoldModeProperty.set_value(StdInputActionHold.MODE_INHERIT)

	# Then: The hold runs in its own mode.
	var slot := StdInputSlot.for_player(1)
	assert_eq(slot.get_action_hold_mode(&"ui_accept"), StdInputActionHold.MODE_TOGGLE)


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
	HoldModeProperty.set_value(StdInputActionHold.MODE_INHERIT)

	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


func before_all() -> void:
	# NOTE: Kit's names are translation keys, and kit's project lists no catalogues, so
	# this loads the shipped ones the way a game's project settings would.
	for path in DirAccess.get_files_at("res://locale"):
		if not path.ends_with(".mo"):
			continue

		var translation: Translation = load("res://locale".path_join(path))
		TranslationServer.add_translation(translation)
		_translations.append(translation)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action registers `action` with `button` as its default binding, unless it's
## already registered.
func _add_action(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_action_event(action, event)


## _add_action_event registers `action` with `event` as its default binding, unless it's
## already registered. std reads an action's defaults from the project settings, so the
## action is added there as well as to the input map.
func _add_action_event(action: StringName, event: InputEvent) -> void:
	if ProjectSettings.has_setting(&"input/" + action):
		return

	ProjectSettings.set_setting(
		&"input/" + action, {"deadzone": 0.5, "events": [event]}
	)

	InputMap.add_action(action)
	InputMap.action_add_event(action, event)

	_added_actions.append(action)


## _get_glyph returns the glyph a `device_type` device draws for `action`'s primary
## binding in `actions`.
func _get_glyph(
	actions: StdInputActionSet,
	action: StringName,
	device_type: StdInputDevice.DeviceType,
) -> Texture2D:
	return StdInputSlot.for_player(1).get_action_glyph(
		actions, action, 0, Vector2.ZERO, device_type
	)


## _get_label returns the name a `device_type` device gives `action`'s primary binding
## in `actions`, or an empty string if it has none.
func _get_label(
	actions: StdInputActionSet,
	action: StringName,
	device_type: StdInputDevice.DeviceType,
) -> String:
	return StdInputSlot.for_player(1).get_action_origin_label(
		actions, action, 0, device_type
	)


## _list_pad_origins returns an event for every joypad button, each stick direction and
## each pulled trigger.
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


## _load_actions loads a set holding the digital actions `names` into the first player's
## slot and returns it.
func _load_actions(names: Array[StringName]) -> StdInputActionSet:
	var actions := StdInputActionSet.new()
	actions.name = &"Glyphs"
	actions.actions_digital = names
	StdInputSlot.for_player(1).load_action_set(actions)
	return actions


## _load_hold loads into the first player's slot a set declaring a hold on `action`,
## which runs in `mode` unless a setting chooses otherwise.
func _load_hold(action: StringName, mode: StdInputActionHold.Mode) -> void:
	var hold := StdInputActionHold.new()
	hold.action = action
	hold.mode = mode

	var actions := StdInputActionSet.new()
	actions.name = &"Holds"
	actions.actions_digital = [action]
	actions.holds = [hold]
	StdInputSlot.for_player(1).load_action_set(actions)
