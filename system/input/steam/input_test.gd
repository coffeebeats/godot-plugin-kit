##
## Tests for the Steam Input implementation's scene, which wires std's Steam joypad
## monitor to kit's sets, the game's sets and layers, and the Godot joypad monitor.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("res://system/input/input.gd")

const Menu := preload("res://system/input/actions/menu.tres")
const MenuBinding := preload("res://system/input/actions/menu_binding.tres")
const MenuOptions := preload("res://system/input/actions/menu_options.tres")
const MenuTabbed := preload("res://system/input/actions/menu_tabbed.tres")
const Splash := preload("res://system/input/actions/splash.tres")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _INPUT_SCENE_PATH is the Steam input scene, loaded in `before_all` rather than
## preloaded, since its monitor can't be parsed without the `Steam` singleton the
## GodotSteam extension registers and `should_skip_script` skips this script without it.
const _INPUT_SCENE_PATH := "res://system/input/steam/input.tscn"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _input_scene: PackedScene = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_monitor_reads_bindings_against_kit_and_game_sets() -> void:
	# Given: A game set, and one of kit's sets the game also lists.
	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"
	var action_sets: Array[StdInputActionSet] = [gameplay, Menu]

	# Given: The game's options layer over its set.
	var options := StdInputActionSetLayer.new()
	options.name = &"GameplayOptions"
	options.parent = gameplay
	var layers: Array[StdInputActionSetLayer] = [options]

	# When: The Steam input scene enters the tree under the input system.
	var input := _add_input(action_sets, layers)

	# Then: Its monitor holds each of kit's sets and layers.
	var monitor: Node = input.get_node(^"JoypadMonitor")
	var kit_sets := [Menu, Splash, MenuBinding, MenuOptions, MenuTabbed]
	for action_set in kit_sets:
		assert_has(monitor.action_sets, action_set)

	# Then: It holds the game's set and options layer.
	assert_has(monitor.action_sets, gameplay)
	assert_has(monitor.action_sets, options)

	# Then: It holds a set both list once.
	assert_eq(monitor.action_sets.count(Menu), 1)


func test_input_monitor_kit_sets_are_each_validated_by_the_input_system() -> void:
	# Given: The Steam input scene, whose monitor lists kit's own sets and layers.
	var input: Node = autofree(_input_scene.instantiate())

	# When: The input system lists the sets it validates.
	var listed: Array[StdInputActionSet] = (
		autofree(SystemInput.new())._list_action_sets()
	)

	# Then: Each of kit's sets on the monitor is among them.
	for action_set in input.get_node(^"JoypadMonitor").action_sets:
		assert_has(listed, action_set)


func test_input_monitor_holds_godot_joypad_monitor() -> void:
	# When: The Steam input scene enters the tree under the input system.
	var input := _add_input()

	# Then: Its monitor holds the Godot monitor the observer swaps in.
	var monitor: Node = input.get_node(^"JoypadMonitor")
	var observer: Node = input.get_node(^"Observers/Player1")
	assert_not_null(monitor.godot_joypad_monitor)
	assert_eq(monitor.godot_joypad_monitor, observer.godot_joypad_monitor)


func test_input_godot_glyphs_hold_the_systems_glyph_sets() -> void:
	# Given: A glyph set the game lists on the input system.
	var glyph_set := StdInputGlyphSetKeyboard.new()
	var glyph_sets: Array[StdInputGlyphSet] = [glyph_set]

	# When: The Steam input scene enters the tree under the input system.
	var input := _add_input([], [], glyph_sets)

	# Then: The Godot glyphs component, which draws the keyboard, holds the set.
	var glyphs: Node = input.get_node(^"Godot/Godot/Components/Glyphs")
	assert_eq(glyphs.glyph_sets, glyph_sets)


func test_input_glyphs_hold_the_systems_unknown_glyph() -> void:
	# Given: An unknown glyph the game sets on the input system.
	var unknown_glyph := PlaceholderTexture2D.new()

	# When: The Steam input scene enters the tree under the input system.
	var input := _add_input([], [], [], unknown_glyph)

	# Then: The Steam glyphs component, which draws pads Steam Input drives, holds it.
	assert_eq(input.get_node(^"Components/Glyphs").unknown_glyph, unknown_glyph)

	# Then: The Godot glyphs component, which draws the rest, holds it.
	assert_eq(
		input.get_node(^"Godot/Godot/Components/Glyphs").unknown_glyph, unknown_glyph
	)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	_input_scene = load(_INPUT_SCENE_PATH)


func should_skip_script():
	if not ClassDB.class_exists(&"Steam"):
		return "the GodotSteam extension isn't available on this platform"

	return false


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_input adds a platform whose profile loaded, then the Steam input scene under an
## input system listing `action_sets`, `menu_options_layers`, `glyph_sets` and
## `unknown_glyph`, as the system's loader places it on Steam builds.
func _add_input(
	action_sets: Array[StdInputActionSet] = [],
	menu_options_layers: Array[StdInputActionSetLayer] = [],
	glyph_sets: Array[StdInputGlyphSet] = [],
	unknown_glyph: Texture2D = null,
) -> Node:
	add_child_autofree(PlatformScene.instantiate())

	var system := SystemInput.new()
	system.action_sets = action_sets
	system.menu_options_layers = menu_options_layers
	system.glyph_sets = glyph_sets
	system.unknown_glyph = unknown_glyph

	var input := _input_scene.instantiate()
	system.add_child(input)
	add_child_autofree(system)

	# NOTE: The monitor fails to start Steam Input without the Steam client.
	assert_engine_error("SteamAPI_SteamInput")
	assert_engine_error("failed to initialize Steam Input")

	return input
