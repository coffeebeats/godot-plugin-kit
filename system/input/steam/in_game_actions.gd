##
## SteamInGameActions is a resource which, given a set of `StdInputActionSet` resources,
## generates a Steam Input actions manifest file. This works in the editor and is not
## intended to be exported.
##

@tool
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
