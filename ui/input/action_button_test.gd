# gdlint:ignore=max-public-methods

##
## Tests for `KitInputActionButton`, through the scene a game places.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ActionButtonScene := preload("action_button.tscn")
const GlyphTypeProperty := preload(
	"res://system/setting/controls/glyph_type_property.tres"
)
const Locales := preload("res://locale/locales.gd")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTION is the action the buttons stand for, which the engine binds to Enter.
const _ACTION := &"ui_accept"

## _ACTION_CANCEL is the action which cancels the tests' toggles, which the engine binds
## to Escape.
const _ACTION_CANCEL := &"ui_cancel"

## _ACTION_UNBOUND is an action with no binding on any device.
const _ACTION_UNBOUND := &"action_button_test_unbound"

## _ACTION_SET is the name of the set holding the tests' actions.
const _ACTION_SET := &"ActionButtonTest"

## _HOLD_DURATION is how long (in seconds) the tests' holds take to fill, long enough
## that none fills during a test.
const _HOLD_DURATION := 60.0

const MODE_HOLD := StdInputActionHold.MODE_HOLD
const MODE_PRESS := StdInputActionHold.MODE_PRESS
const MODE_TOGGLE := StdInputActionHold.MODE_TOGGLE

# -- INITIALIZATION ------------------------------------------------------------------ #

var _actions: StdInputActionSet = null

## _mounted is the scene `_mount` mounted, freed before the input scene its focus
## handler reports to.
var _mounted: StdTestInput = null
var _translations: Array[Translation] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_action_button_text_is_the_actions_translated_name() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# When: A button for the action enters the tree.
	var button := _add_button()

	# Then: The button's text is the translated name.
	assert_eq(button.text, "Confirm")


func test_action_button_text_follows_a_language_change() -> void:
	# Given: A button for the action in the tree, showing its name.
	var button := _add_button()
	assert_eq(button.text, Locales.tr_action(_ACTION_SET, _ACTION), "precondition")

	# Given: A translation of the action's name, as a new language brings.
	_add_action_translation("Confirm")

	# When: The language changes.
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)

	# Then: The button's text is the new translation.
	assert_eq(button.text, "Confirm")


func test_action_button_game_text_is_kept_across_a_language_change() -> void:
	# Given: A button for the action with the game's own text.
	var button := _create_button()
	button.use_action_text = false
	button.text = "Buy"
	add_child_autofree(button)

	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# When: The language changes.
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)

	# Then: The button keeps the game's text.
	assert_eq(button.text, "Buy")


func test_action_button_game_text_is_kept_when_loaded_from_a_scene() -> void:
	# Given: A button for the action with the game's own text, set as a scene saves it.
	var button := _create_button()
	button.text = "Buy"
	button.use_action_text = false

	# Given: A scene holding the button.
	var root := Control.new()
	root.add_child(button)
	button.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()

	# When: The scene is loaded and enters the tree.
	var loaded: Control = scene.instantiate()
	add_child_autofree(loaded)

	# Then: The loaded button keeps the game's text.
	assert_eq((loaded.get_child(0) as Button).text, "Buy")


func test_action_button_click_holds_the_action_until_released() -> void:
	# Given: A button for the action, mounted under a real mouse.
	var button := _create_button()
	var input := await _mount(button)

	# When: The mouse is pressed on the button.
	input.move_mouse(button.get_global_rect().get_center())
	input.press_mouse()

	# Then: The action is held.
	assert_true(Input.is_action_pressed(_ACTION))

	# When: The mouse is released.
	input.release_mouse()

	# Then: The action is released.
	assert_false(Input.is_action_pressed(_ACTION))


func test_action_button_raise_action_off_raises_nothing_but_still_presses() -> void:
	# Given: A button for the action which raises nothing, mounted under a real mouse.
	var button := _create_button()
	button.raise_action = false
	var input := await _mount(button)
	watch_signals(button)

	# When: The mouse is pressed on the button.
	input.move_mouse(button.get_global_rect().get_center())
	input.press_mouse()

	# Then: The action isn't raised.
	assert_false(Input.is_action_pressed(_ACTION))

	# Then: The button still emits `pressed` for the game to connect.
	assert_signal_emitted(button, "pressed")


func test_action_button_focus_anchor_reaches_the_focus_handler() -> void:
	# Given: A button for the action which anchors focus.
	var button := _create_button()
	button.focus_anchor = true

	# When: The button enters the tree.
	var host := Control.new()
	host.add_child(button)
	add_child_autofree(host)

	# Then: Focus navigation lands on the button.
	assert_eq(StdInputCursorFocusHandler.get_focus_target(host), button)


func test_action_button_glyph_is_as_tall_as_a_line_of_text() -> void:
	# Given: A host whose theme sets a large font size.
	var host := Control.new()
	host.theme = Theme.new()
	host.theme.default_font_size = 32
	add_child_autofree(host)

	# When: A button for the action enters the tree under it.
	var button := _create_button()
	host.add_child(button)

	# Then: The glyph is as tall as a line of the button's text.
	assert_eq(button.get_glyph().get_height(), _get_line_height(button))


func test_action_button_glyph_scale_percent_makes_the_glyph_taller() -> void:
	# Given: A host whose theme draws action buttons' glyphs at twice a line of text.
	var host := Control.new()
	host.theme = Theme.new()
	host.theme.set_constant(&"glyph_scale_percent", &"KitInputActionButton", 200)
	add_child_autofree(host)

	# When: A button for the action enters the tree under it.
	var button := _create_button()
	host.add_child(button)

	# Then: The glyph is two lines of text tall.
	assert_eq(button.get_glyph().get_height(), _get_line_height(button) * 2)


func test_action_button_accessibility_name_carries_the_origin_and_text() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# When: A button for the action enters the tree, with the keyboard active.
	var button := _add_button()

	# Then: Its accessible name is the key's name, then the action's.
	var origin := button.get_glyph().get_origin_label()
	assert_ne(origin, "", "precondition")
	assert_eq(button.accessibility_name, "%s, Confirm" % origin)


func test_action_button_accessibility_name_is_the_text_alone_with_no_origin() -> void:
	# Given: A button for an action with nothing bound.
	var button := _create_button()
	button.action = _ACTION_UNBOUND

	# When: The button enters the tree.
	add_child_autofree(button)

	# Then: Its accessible name is left to the text, which assistive tech reads alone.
	assert_eq(button.get_glyph().get_origin_label(), "", "precondition")
	assert_eq(button.accessibility_name, "")


func test_action_button_glyph_reads_the_button_prompts_setting() -> void:
	# When: A button for the action is created.
	var button: KitInputActionButton = autofree(_create_button())

	# Then: Its glyph follows the player's Button prompts setting.
	assert_eq(button.get_glyph().device_type_override, GlyphTypeProperty)


func test_action_button_hold_mode_shows_the_hold_text() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# Given: The action is a hold the player holds.
	_declare_hold(MODE_HOLD)

	# When: A button for the action enters the tree.
	var button := _add_button()

	# Then: Its text says to hold the action.
	assert_eq(button.text, "Hold to Confirm")


func test_action_button_hold_mode_with_empty_hold_text_shows_the_name() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# Given: The action is a hold the player holds.
	_declare_hold(MODE_HOLD)

	# When: A button for the action with no hold text enters the tree.
	var button := _create_button()
	button.hold_text = &""
	add_child_autofree(button)

	# Then: Its text is the action's name alone.
	assert_eq(button.text, "Confirm")


func test_action_button_hold_mode_fills_while_held_and_empties_on_release() -> void:
	# Given: The action is a hold the player holds.
	_declare_hold(MODE_HOLD)

	# Given: A button for the action, mounted under real input.
	var button := _create_button()
	var input := await _mount(button)

	# When: The action is held for a few frames.
	input.press_action(_ACTION)
	await wait_process_frames(3)

	# Then: The button fills as far as the hold has.
	var progress := _get_slot().get_action_hold_progress(_ACTION)
	assert_gt(progress, 0.0, "precondition")
	assert_eq(button._hold_progress, progress)

	# When: The action is released before the hold fills.
	input.release_action(_ACTION)

	# Then: The fill empties.
	assert_eq(button._hold_progress, 0.0)


func test_action_button_toggle_mode_shows_the_cancel_after_a_tap() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# Given: The action is a hold the player toggles, with its own cancel action.
	_declare_hold(MODE_TOGGLE, _ACTION_CANCEL)

	# Given: A button for the action, mounted under real input.
	var button := _create_button()
	var input := await _mount(button)

	# Then: Before a tap it shows the action's name and glyph.
	assert_eq(button.text, "Confirm")
	assert_eq(button.get_glyph().action, _ACTION)

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: It shows how to cancel the running toggle.
	assert_eq(button.text, "Cancel")
	assert_eq(button.get_glyph().action, _ACTION_CANCEL)

	# When: The action is tapped again, which cancels the toggle.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: It shows the action's name and glyph again.
	assert_eq(button.text, "Confirm")
	assert_eq(button.get_glyph().action, _ACTION)


func test_action_button_press_mode_shows_the_name_alone() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# Given: The action is a hold the player's setting runs on the press.
	_declare_hold(MODE_PRESS)

	# When: A button for the action enters the tree.
	var button := _add_button()

	# Then: Its text is the action's name alone.
	assert_eq(button.text, "Confirm")


func test_action_button_hold_declared_after_ready_shows_the_hold_text() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# Given: A button for the action, whose set declares no hold.
	var button := _add_button()
	assert_eq(button.text, "Confirm", "precondition")

	# When: The action becomes a hold the player holds.
	_declare_hold(MODE_HOLD)

	# Then: Its text says to hold the action.
	assert_eq(button.text, "Hold to Confirm")


func test_action_button_mode_change_with_no_hold_running_updates_the_text() -> void:
	# Given: A translation of the action's name.
	_add_action_translation("Confirm")

	# Given: The action is a hold the player holds, through its group's setting.
	var mode := _declare_hold(MODE_HOLD)

	# Given: A button for the action, saying to hold it.
	var button := _add_button()
	assert_eq(button.text, "Hold to Confirm", "precondition")

	# When: The player changes the setting to toggle while nothing runs.
	mode.set_value(MODE_TOGGLE)

	# Then: Its text is the action's name alone.
	assert_eq(button.text, "Confirm")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	InputMap.erase_action(_ACTION_UNBOUND)
	ProjectSettings.set_setting(&"input/" + _ACTION_UNBOUND, null)


func after_each() -> void:
	if is_instance_valid(_mounted):
		_mounted.free()

	for translation in _translations:
		TranslationServer.remove_translation(translation)

	_translations.clear()

	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())


func before_all() -> void:
	# NOTE: std reads an action's defaults from the project settings, so the action is
	# added there as well as to the input map.
	ProjectSettings.set_setting(
		&"input/" + _ACTION_UNBOUND, {"deadzone": 0.5, "events": []}
	)
	InputMap.add_action(_ACTION_UNBOUND)


func before_each() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding the tests' actions.
	_actions = StdInputActionSet.new()
	_actions.name = _ACTION_SET
	_actions.actions_digital = (
		[_ACTION, _ACTION_CANCEL, _ACTION_UNBOUND] as Array[StringName]
	)
	StdInputSlot.for_player(1).load_action_set(_actions)

	# Given: Kit's English catalogue, which holds the accessible name's template.
	_add_translation(load("res://locale/en_US.mo"))


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action_translation adds a translation of `_ACTION`'s name as `text` in the
## current locale.
func _add_action_translation(text: String) -> void:
	var translation := Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message(_ACTION, text, Locales.MSGCTXT_ACTION_PREFIX + _ACTION_SET)
	_add_translation(translation)


## _add_button adds a button for `_ACTION` to the tree and returns it.
func _add_button() -> KitInputActionButton:
	var button := _create_button()
	add_child_autofree(button)
	return button


func _add_translation(translation: Translation) -> void:
	TranslationServer.add_translation(translation)
	_translations.append(translation)


## _declare_hold reloads the tests' set declaring `_ACTION` a hold which runs in `mode`,
## cancelled by `cancel_action`. The mode comes from the hold's own setting, which
## overrides any mode the player stored, and which the returned property holds.
func _declare_hold(
	mode: StdInputActionHold.Mode, cancel_action: StringName = &""
) -> StdSettingsPropertyInt:
	var property := StdSettingsPropertyInt.new()
	property.category = &"action_button_test"
	property.name = &"hold_mode"
	property.scope = StdSettingsScope.new()
	property.set_value(mode)

	var hold := StdInputActionHold.new()
	hold.action = _ACTION
	hold.cancel_action = cancel_action
	hold.duration = _HOLD_DURATION
	hold.mode_override = property

	_actions.holds = [hold] as Array[StdInputActionHold]

	# NOTE: The slot ignores a load of the set it already has, so another goes first.
	_get_slot().load_action_set(StdInputActionSet.new())
	_get_slot().load_action_set(_actions)

	return property


func _create_button() -> KitInputActionButton:
	var button: KitInputActionButton = ActionButtonScene.instantiate()
	button.action_set = _actions
	button.action = _ACTION
	return button


## _get_line_height returns the height of a line of `button`'s text.
func _get_line_height(button: Button) -> int:
	var font := button.get_theme_font(&"font")
	return roundi(font.get_height(button.get_theme_font_size(&"font_size")))


func _get_slot() -> StdInputSlot:
	return StdInputSlot.for_player(1)


## _mount mounts `button` at the root under a real mouse, sized to be clicked.
func _mount(button: KitInputActionButton) -> StdTestInput:
	button.custom_minimum_size = Vector2(160, 48)

	var host := Control.new()
	host.add_child(button)
	_mounted = await StdTestInput.mount(self, host)
	return _mounted
