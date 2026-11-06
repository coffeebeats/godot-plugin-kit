##
## Tests for the `Theme` node, which fills the game's theme with kit's base theme.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const BarScene := preload("res://ui/hud/bar/bar.tscn")
const FontScalingObserverScene := preload(
	"res://system/setting/interface/font_scaling_observer.tscn"
)
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")
const SystemScene := preload("res://premade/system.tscn")
const TabGroupScene := preload("res://ui/menu/tab_group.tscn")
const ThemeFill := preload("theme.gd")
const ThemeScene := preload("theme.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _VARIATION_PATTERN matches a type variation a kit scene or resource names.
const _VARIATION_PATTERN := 'theme_(?:type_)?variation = &"(\\w+)"'

# -- TEST METHODS -------------------------------------------------------------------- #


func test_theme_base_defines_every_variation_kit_names() -> void:
	# Given: Kit's base theme.
	var base := _get_base()

	# Given: Every type variation kit's scenes, resources and tab group name.
	var tabs: Node = autofree(TabGroupScene.instantiate())
	var variations := _find_named_variations("res://")
	variations[tabs.theme_type_selected] = true
	variations[tabs.theme_type_unselected] = true
	assert_gt(variations.size(), 0, "precondition")

	# Then: The base theme defines each of them as a variation.
	for variation: StringName in variations:
		assert_ne(base.get_type_variation_base(variation), &"", variation)


func test_theme_fill_keeps_the_games_value() -> void:
	# Given: A game theme which styles the HUD bar's fill.
	var game := Theme.new()
	var fill := StyleBoxFlat.new()
	game.set_stylebox(&"fill", &"HudBar", fill)

	# When: Kit's base theme fills the game's.
	ThemeFill.fill(game, _get_base())

	# Then: The game's fill is kept.
	assert_eq(game.get_stylebox(&"fill", &"HudBar"), fill)


func test_theme_fill_adds_the_kit_default_the_game_lacks() -> void:
	# Given: A game theme which styles only the HUD bar's fill.
	var game := Theme.new()
	game.set_stylebox(&"fill", &"HudBar", StyleBoxFlat.new())

	# When: Kit's base theme fills the game's.
	var base := _get_base()
	ThemeFill.fill(game, base)

	# Then: The bar's background, which the game left out, is kit's.
	var background := base.get_stylebox(&"background", &"HudBar")
	assert_eq(game.get_stylebox(&"background", &"HudBar"), background)

	# Then: Kit's own control's item is added too.
	assert_true(game.has_constant(&"glyph_scale_percent", &"KitInputActionButton"))


func test_theme_fill_adds_a_variation_base_the_game_lacks() -> void:
	# Given: A game theme which styles HUD numbers without naming their base type.
	var game := Theme.new()
	game.set_color(&"font_color", &"HudNumber", Color.RED)

	# When: Kit's base theme fills the game's.
	ThemeFill.fill(game, _get_base())

	# Then: The variation is based on `Label`.
	assert_eq(game.get_type_variation_base(&"HudNumber"), &"Label")


func test_theme_fill_keeps_the_games_variation_base() -> void:
	# Given: A game theme which bases menu bodies on another container.
	var game := Theme.new()
	game.set_type_variation(&"MenuBody", &"HBoxContainer")

	# When: Kit's base theme fills the game's.
	ThemeFill.fill(game, _get_base())

	# Then: The game's base type is kept.
	assert_eq(game.get_type_variation_base(&"MenuBody"), &"HBoxContainer")


func test_theme_fill_leaves_the_text_size_setting_working() -> void:
	# Given: A game theme with its own text size.
	var game := Theme.new()
	game.default_font_size = 20

	# Given: Kit's base theme fills it.
	ThemeFill.fill(game, _get_base())

	# Given: A label which reads the game's theme.
	var host := Control.new()
	host.theme = game
	var label := Label.new()
	host.add_child(label)
	add_child_autofree(host)

	# Given: A text size setting.
	var setting := StdSettingsPropertyFloatRange.new()
	setting.category = &"interface"
	setting.name = &"font_scaling"
	setting.maximum = 2.0
	setting.scope = StdSettingsScope.new()

	# Given: The observer which resizes the game's theme from that setting.
	var observer: Node = FontScalingObserverScene.instantiate()
	observer.font_scaling_property = setting
	observer.theme = game
	observer.debounce.duration = 0.01
	add_child_autofree(observer)

	# When: The player doubles the text size.
	setting.set_value(2.0)
	await wait_for_signal(observer.debounce.timeout, 1.0)

	# Then: The label's text is twice the game's size.
	assert_eq(label.get_theme_font_size(&"font_size"), 40)


func test_theme_fill_over_an_empty_game_theme_keeps_kit_parts_apart() -> void:
	# Given: An empty game theme.
	var game := Theme.new()

	# When: Kit's base theme fills it.
	_fill(game)

	# Then: A HUD bar's parts and the selected and unselected tabs still differ.
	_assert_parts_apart(game)


func test_theme_fill_over_a_game_styling_base_types_keeps_kit_parts_apart() -> void:
	# Given: A game theme which styles every progress bar and button.
	var game := Theme.new()
	game.set_stylebox(&"background", &"ProgressBar", StyleBoxFlat.new())
	game.set_stylebox(&"fill", &"ProgressBar", StyleBoxFlat.new())
	game.set_stylebox(&"normal", &"Button", StyleBoxFlat.new())

	# When: Kit's base theme fills it.
	_fill(game)

	# Then: A HUD bar's parts and the selected and unselected tabs still differ.
	_assert_parts_apart(game)


func test_theme_enter_tree_fills_the_project_theme() -> void:
	# Given: A game theme which styles only the HUD bar's fill.
	var game := Theme.new()
	var fill := StyleBoxFlat.new()
	game.set_stylebox(&"fill", &"HudBar", fill)

	# Given: The `Theme` node, with that theme stubbed in as the project theme.
	var node: ThemeFill = partial_double(ThemeScene).instantiate()
	stub(node, "_get_project_theme").to_return(game)

	# When: The node enters the tree.
	add_child_autofree(node)

	# Then: The game's fill is kept.
	assert_eq(game.get_stylebox(&"fill", &"HudBar"), fill)

	# Then: The bar's background, which the game left out, is kit's.
	var background := node.base.get_stylebox(&"background", &"HudBar")
	assert_eq(game.get_stylebox(&"background", &"HudBar"), background)


func test_theme_system_scene_places_the_theme_node() -> void:
	# Given: The premade `System` scene's saved nodes.
	var state := SystemScene.get_state()

	# When: The scenes it instances are collected.
	var instances: Array[String] = []
	for i in state.get_node_count():
		var instance := state.get_node_instance(i)
		if instance:
			instances.append(instance.resource_path)

	# Then: One of them is the `Theme` node.
	assert_has(instances, ThemeScene.resource_path)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _assert_parts_apart mounts kit's HUD bar and a two-tab group under `game`, then
## asserts that the ghost shows through the bar's fill, that the two fills differ, and
## that the selected tab's box differs from the other's.
func _assert_parts_apart(game: Theme) -> void:
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	var bar := _mount(game, BarScene.instantiate())
	var fill: ProgressBar = bar.get_node(^"Fill")
	var ghost: ProgressBar = bar.get_node(^"Ghost")
	var tabs: Node = TabGroupScene.instantiate()
	tabs.tabs = PackedStringArray(["a", "b"])
	_mount(game, tabs)
	var selected: Button = tabs.get_child(0)
	var unselected: Button = tabs.get_child(1)

	var background := fill.get_theme_stylebox(&"background")
	assert_is(background, StyleBoxEmpty, "fill background")
	var ghost_fill := ghost.get_theme_stylebox(&"fill")
	assert_ne(ghost_fill, fill.get_theme_stylebox(&"fill"), "ghost fill")
	var normal := selected.get_theme_stylebox(&"normal")
	assert_ne(normal, unselected.get_theme_stylebox(&"normal"), "tab normal")


## _fill fills `game` from kit's base theme, as the `Theme` scene does.
func _fill(game: Theme) -> void:
	ThemeFill.fill(game, _get_base())


## _find_named_variations returns the set of type variations named in the scenes and
## resources under `path`, outside the addons.
func _find_named_variations(path: String) -> Dictionary:
	var pattern := RegEx.create_from_string(_VARIATION_PATTERN)
	var found := {}

	for directory in DirAccess.get_directories_at(path):
		if directory.begins_with(".") or directory == "addons":
			continue

		found.merge(_find_named_variations(path.path_join(directory)))

	for file in DirAccess.get_files_at(path):
		if file.get_extension() not in ["tscn", "tres"]:
			continue

		var text := FileAccess.get_file_as_string(path.path_join(file))
		for match in pattern.search_all(text):
			found[StringName(match.get_string(1))] = true

	return found


## _get_base returns kit's base theme, as the `Theme` scene fills from it.
func _get_base() -> Theme:
	var node: Node = autofree(ThemeScene.instantiate())
	return node.base


## _mount adds `node` to the tree under a control whose theme is `game`, and returns it.
func _mount(game: Theme, node: Node) -> Node:
	var host := Control.new()
	host.theme = game
	host.add_child(node)
	add_child_autofree(host)

	return node
