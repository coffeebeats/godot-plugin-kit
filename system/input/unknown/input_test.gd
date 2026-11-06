##
## Tests for the input system's Godot implementation, which draws glyphs from the game's
## `glyph_sets` and `unknown_glyph`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ArrowUp := preload("glyphs/keyboard/arrow_up.svg")
const KeycapTexture := preload("res://addons/std/input/godot/keycap_texture.gd")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("res://system/input/input.gd")
const SystemInputScene := preload("res://system/input/input.tscn")
const Unknown := preload("glyphs/unknown.svg")

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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_glyph(
	actions: StdInputActionSet,
	action: StringName,
	device_type: StdInputDevice.DeviceType,
) -> Texture2D:
	return StdInputSlot.for_player(1).get_action_glyph(
		actions, action, 0, Vector2.ZERO, device_type
	)


func _load_actions(names: Array[StringName]) -> StdInputActionSet:
	var actions := StdInputActionSet.new()
	actions.name = &"Glyphs"
	actions.actions_digital = names
	StdInputSlot.for_player(1).load_action_set(actions)
	return actions
