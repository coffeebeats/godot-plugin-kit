##
## Theme fills the project theme with kit's base theme as it enters the tree, adding
## only the items and type variation bases the game's theme lacks. The game's item
## wins over kit's on the same type, but kit's item on a variation still wins over the
## game's on the base type, as Godot reads a variation's items first. Every control
## keeps reading the one project theme, so the text size setting still resizes it.
##

extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## base is the theme whose items fill the gaps in the project theme.
@export var base: Theme = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"system/theme")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## fill adds to `target` each item and type variation base of `source` which `target`
## lacks, leaving every one `target` defines as it is.
static func fill(target: Theme, source: Theme) -> void:
	for theme_type in source.get_type_list():
		var variation_base := source.get_type_variation_base(theme_type)
		if variation_base and not target.get_type_variation_base(theme_type):
			target.set_type_variation(theme_type, variation_base)

		for i in Theme.DATA_TYPE_MAX:
			var data_type := i as Theme.DataType
			for item in source.get_theme_item_list(data_type, theme_type):
				if target.has_theme_item(data_type, item, theme_type):
					continue

				var value: Variant = source.get_theme_item(data_type, item, theme_type)
				target.set_theme_item(data_type, item, theme_type, value)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(base is Theme, "invalid config; missing base theme")

	# NOTE: This runs before any `_ready`, so a node which reads the project theme
	# there, such as the font scaling observer, already sees kit's items.
	var project := _get_project_theme()
	if not project:
		_logger.warn("No project theme to fill; set '[gui] theme/custom'.")
		return

	fill(project, base)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_project_theme returns the project theme, which `_enter_tree` fills.
##
## NOTE: Tests stub this, since the engine offers no way to set the project theme.
func _get_project_theme() -> Theme:
	return ThemeDB.get_project_theme()
