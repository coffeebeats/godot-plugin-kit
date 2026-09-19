##
## KitSteamInGameActions is the Steam Input manifest generator with display names
## resolved through `Locales`, so a set or action is named as the controls tab names it
## in every language the game loads. A game places one as a resource and generates the
## manifest with `addons/std/input/steam/write_in_game_actions.gd`.
##

class_name KitSteamInGameActions
extends StdInputSteamInGameActions

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Locales := preload("../../../locale/locales.gd")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_action_set_display_name(
	action_set_name: StringName,
	locale: StringName = &"",
) -> String:
	return Locales.tr_action_set(action_set_name, locale)


func _get_action_display_name(
	action_set_name: StringName,
	action_name: StringName,
	locale: StringName = &"",
) -> String:
	return Locales.tr_action(action_set_name, action_name, locale)
