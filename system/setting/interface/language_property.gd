##
## system/setting/interface/language_property.gd
##
## LanguageProperty is a settings property which defines the target display language.
##

extends StdSettingsPropertyString

# -- CONFIGURATION ------------------------------------------------------------------- #

## language_options_property is a `StdSettingsPropertyStringList` defining the list of
## supported locale codes.
@export var language_options_property: StdSettingsPropertyStringList = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## initialize sets up the default value for this property. This must be called after the
## configuration data has been hydrated from disk.
func initialize() -> void:
	assert(scope, "invalid state; missing scope")
	assert(default == "", "invalid state; has this property already been initialized?")
	assert(
		scope.get_repository() and scope.get_repository().is_node_ready(),
		"invalid state; setting not hydrated yet",
	)

	default = _find_matching_locale(OS.get_locale())

	var current := scope.config.get_string(category, name, "")

	if current == default or current not in language_options_property.get_value():
		scope.config.erase(category, name)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	if default == "":
		default = _find_matching_locale(OS.get_locale())

	return config.get_string(category, name, default)


func _set_value_on_config(config: Config, value: String) -> bool:
	if default == "":
		default = _find_matching_locale(OS.get_locale())

	if value == default:
		return config.erase(category, name)

	return config.set_string(category, name, value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _find_matching_locale(locale: String) -> String:
	var locale_best: StringName = &"en_US"
	var score_best: int = 0

	for l: String in language_options_property.get_value():
		var score := TranslationServer.compare_locales(l, locale)
		if score > score_best:
			locale_best = l
			score_best = score

		if score_best == 10:
			break

	return locale_best
