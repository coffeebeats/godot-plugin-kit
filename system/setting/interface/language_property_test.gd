##
## Tests for the language property, whose default follows the language the build's
## storefront has for the game until the player picks one.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const LanguageProperty := preload("language_property.gd")
const Provider := preload("res://platform/storefront/provider.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## StubProvider is a storefront implementation naming a fixed locale.
class StubProvider:
	extends Provider

	var locale: String = ""

	func get_locale() -> String:
		return locale


# -- INITIALIZATION ------------------------------------------------------------------ #

var _language: LanguageProperty = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_language_default_with_storefront_locale_follows_it() -> void:
	# Given: A storefront that has German for the game.
	_add_provider("de")

	# When: The language is read before the player picks one.
	var value: String = _language.get_value()

	# Then: It is German.
	assert_eq(value, "de")


func test_language_default_with_regional_storefront_locale_picks_closest() -> void:
	# Given: A storefront that has Austrian German for the game.
	_add_provider("de_AT")

	# When: The language is read before the player picks one.
	var value: String = _language.get_value()

	# Then: It is the loaded German.
	assert_eq(value, "de")


func test_language_saved_choice_beats_storefront_locale() -> void:
	# Given: A storefront that has German for the game.
	_add_provider("de")

	# Given: The player picked French.
	_language.set_value("fr")

	# When: The language is read.
	var value: String = _language.get_value()

	# Then: It is French.
	assert_eq(value, "fr")


func test_language_default_with_storefront_without_locale_follows_system() -> void:
	# Given: A storefront that names no language, as when Steam failed to start.
	_add_provider("")

	# When: The language is read before the player picks one.
	var value: String = _language.get_value()

	# Then: It is the system's.
	assert_eq(value, OS.get_locale())


func test_language_default_without_storefront_follows_system() -> void:
	# Given: No storefront in the scene tree.

	# When: The language is read before the player picks one.
	var value: String = _language.get_value()

	# Then: It is the system's.
	assert_eq(value, OS.get_locale())


func test_refresh_default_storefront_locale_changed_follows_it() -> void:
	# Given: A storefront that has German for the game, which the language follows.
	var provider := _add_provider("de")
	assert_eq(_language.get_value(), "de", "precondition")

	# Given: The player switches the game to French in the storefront.
	provider.locale = "fr"

	# When: The default is re-read.
	watch_signals(_language)
	_language.refresh_default()

	# Then: The language is French, and its observers hear so.
	assert_eq(_language.get_value(), "fr")
	assert_signal_emitted_with_parameters(_language, "value_changed", ["fr"])


func test_refresh_default_with_saved_choice_keeps_it() -> void:
	# Given: A storefront that has German for the game.
	var provider := _add_provider("de")

	# Given: The player picked French in the game.
	_language.set_value("fr")

	# Given: The player switches the game to the system's language in the storefront.
	provider.locale = OS.get_locale()

	# When: The default is re-read.
	watch_signals(_language)
	_language.refresh_default()

	# Then: The language stays French, and its observers hear nothing.
	assert_eq(_language.get_value(), "fr")
	assert_signal_not_emitted(_language, "value_changed")


func test_refresh_default_with_saved_choice_matching_default_keeps_it() -> void:
	# Given: A storefront that has German for the game.
	var provider := _add_provider("de")

	# Given: The player picked German in the game, matching the storefront.
	_language.set_value("de")

	# Given: The player switches the game to French in the storefront.
	provider.locale = "fr"

	# When: The default is re-read.
	watch_signals(_language)
	_language.refresh_default()

	# Then: The language stays German, and its observers hear nothing.
	assert_eq(_language.get_value(), "de")
	assert_signal_not_emitted(_language, "value_changed")


func test_refresh_default_storefront_locale_unchanged_emits_nothing() -> void:
	# Given: A storefront that has German for the game, which the language follows.
	_add_provider("de")
	assert_eq(_language.get_value(), "de", "precondition")

	# When: The default is re-read.
	watch_signals(_language)
	_language.refresh_default()

	# Then: Its observers hear nothing.
	assert_signal_not_emitted(_language, "value_changed")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	var scope := StdSettingsScope.new()

	var options := StdSettingsPropertyStringList.new()
	options.category = &"interface"
	options.name = &"language/options"
	options.default = PackedStringArray(["de", "fr", OS.get_locale()])
	options.scope = scope

	_language = LanguageProperty.new()
	_language.category = &"interface"
	_language.name = &"language/language_code"
	_language.scope = scope
	_language.language_options_property = options


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_provider adds a storefront implementation naming `locale` to the scene tree.
func _add_provider(locale: String) -> StubProvider:
	var provider := StubProvider.new()
	provider.locale = locale
	add_child_autofree(provider)
	return provider
