##
## LanguageProperty is a settings property which defines the target display language.
## Its default is the loaded locale closest to the language the build's storefront has
## for the game, or else to the system's.
##

extends StdSettingsPropertyString

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Storefront := preload("../../../platform/storefront/storefront.gd")

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

	default = _find_matching_locale(_get_platform_locale())

	var current := scope.config.get_string(category, name, "")

	if current not in language_options_property.get_value():
		scope.config.erase(category, name)


## refresh_default re-reads the language the build's storefront has for the game, which
## Steam lets the player change while the game runs. If the player hasn't picked a
## language in the game and the default moved, the value follows and `value_changed` is
## emitted.
func refresh_default() -> void:
	var next := _find_matching_locale(_get_platform_locale())
	if next == default:
		return

	default = next

	if not scope.config.has_string(category, name):
		value_changed.emit(next)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	if default == "":
		default = _find_matching_locale(_get_platform_locale())

	return config.get_string(category, name, default)


func _set_value_on_config(config: Config, value: String) -> bool:
	# NOTE: The player's choice is stored even when it matches the default, so it holds
	# once the storefront's language changes.
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


## _get_platform_locale returns the locale of the language the build's storefront has
## for the game, falling back to the system's.
##
## NOTE: `Platform` registers before `System`, so the storefront has started by the time
## the language observer initializes this property.
func _get_platform_locale() -> String:
	var locale := Storefront.find_locale()
	return locale if locale else OS.get_locale()
