##
## SteamInput is the input system's Steam Input implementation. It adds the game's
## action sets, read from the `Input` system component's `action_sets` and
## `menu_options_layers`, to the Steam joypad monitor's, so the monitor reads a
## controller's binding against every set the game's Steam Input manifest lists. It
## hands the system component's `unknown_glyph` to the Steam glyphs component.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamJoypadMonitor := preload("res://addons/std/input/steam/joypad_monitor.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## joypad_monitor is the Steam joypad monitor, whose `action_sets` hold kit's own sets
## and layers.
@export var joypad_monitor: StdInputSlot.JoypadMonitor = null

## glyphs is the Steam glyphs component, which draws the origins of controllers Steam
## Input drives.
@export var glyphs: StdInputDeviceGlyphs = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	var monitor := joypad_monitor as SteamJoypadMonitor
	if not monitor:
		assert(false, "invalid config; missing Steam joypad monitor")
		return

	if not glyphs:
		assert(false, "invalid config; missing Steam glyphs component")
		return

	var input := KitSystems.input()
	glyphs.unknown_glyph = input.unknown_glyph

	# NOTE: This runs before the monitor enters the tree and starts Steam Input, so the
	# sets are complete before Steam reports a controller.
	for action_set in input.action_sets + input.menu_options_layers:
		if action_set not in monitor.action_sets:
			monitor.action_sets.append(action_set)
