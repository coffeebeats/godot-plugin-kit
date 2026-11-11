##
## GodotInput is the input system's implementation over Godot's own input. It hands the
## `Input` system component's `glyph_sets`, `origin_names` and `unknown_glyph` to the
## Godot glyphs component.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GodotDeviceGlyphs := preload("res://addons/std/input/godot/device_glyphs.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## glyphs is the Godot glyphs component, which draws origins from `glyph_sets` and
## names them from `origin_names`.
@export var glyphs: StdInputDeviceGlyphs = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	var component := glyphs as GodotDeviceGlyphs
	if not component:
		assert(false, "invalid config; missing Godot glyphs component")
		return

	var input := KitSystems.input()
	component.glyph_sets = input.glyph_sets
	component.origin_names = input.origin_names
	component.unknown_glyph = input.unknown_glyph
