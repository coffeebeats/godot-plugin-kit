##
## SteamInput is the Steam Input backend. It loads at runtime, so the scene placing
## the `Input` system cannot configure it; it reads the game's Steam Input manifest
## from that system instead.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamDeviceActions := preload("res://addons/std/input/steam/device_actions.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_actions is the Steam-backed device actions component, which requires the
## manifest by the time it is ready.
@export var device_actions: SteamDeviceActions = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(
		device_actions is SteamDeviceActions, "invalid config; missing device actions"
	)

	var in_game_actions := KitSystems.input().steam_in_game_actions
	if not in_game_actions:
		push_error("invalid config; missing Steam in-game actions")

	device_actions.in_game_actions = in_game_actions
