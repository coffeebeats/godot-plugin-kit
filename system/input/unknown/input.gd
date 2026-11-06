##
## GodotInput is the input system's implementation over Godot's own input. It hands the
## game's glyph sets, read from the `Input` system component's `glyph_sets`, to the
## Godot glyphs component.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GodotDeviceGlyphs := preload("res://addons/std/input/godot/device_glyphs.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## glyphs is the Godot glyphs component, which draws origins from `glyph_sets`.
@export var glyphs: StdInputDeviceGlyphs = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	var component := glyphs as GodotDeviceGlyphs
	if not component:
		assert(false, "invalid config; missing Godot glyphs component")
		return

	component.glyph_sets = KitSystems.input().glyph_sets
