##
## SteamInput is the input system's Steam Input implementation. It adds the game's
## action sets, read from the `Input` system component's `action_sets`, to the Steam
## joypad monitor's, so the monitor reads a controller's binding against every set the
## game's Steam Input manifest lists.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamJoypadMonitor := preload("res://addons/std/input/steam/joypad_monitor.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## joypad_monitor is the Steam joypad monitor, whose `action_sets` hold kit's own sets
## and layers.
@export var joypad_monitor: StdInputSlot.JoypadMonitor = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	var monitor := joypad_monitor as SteamJoypadMonitor
	if not monitor:
		assert(false, "invalid config; missing Steam joypad monitor")
		return

	# NOTE: This runs before the monitor enters the tree and starts Steam Input, so the
	# sets are complete before Steam reports a controller.
	for action_set in KitSystems.input().action_sets:
		if action_set not in monitor.action_sets:
			monitor.action_sets.append(action_set)
