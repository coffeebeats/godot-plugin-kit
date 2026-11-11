##
## Tests for how the Steam storefront checks the game's language list and maps Steam's
## language codes to kit's locales.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SteamStorefront := preload("storefront.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_has_language_choice_several_languages_returns_true() -> void:
	# When: A game listing English and German is checked.
	var has_choice := SteamStorefront.has_language_choice("english,german")

	# Then: Steam can name either.
	assert_true(has_choice)


func test_has_language_choice_one_language_returns_false() -> void:
	# When: A game listing only English is checked.
	var has_choice := SteamStorefront.has_language_choice("english")

	# Then: Steam names English whatever the player's language, so it isn't trusted.
	assert_false(has_choice)


func test_has_language_choice_no_languages_returns_false() -> void:
	# When: A game listing no languages is checked.
	var has_choice := SteamStorefront.has_language_choice("")

	# Then: Steam isn't trusted.
	assert_false(has_choice)


func test_to_locale_every_kit_locale_is_reached_from_a_steam_code() -> void:
	# Given: The locales kit ships a catalogue for.
	var locales := _list_kit_locales()
	assert_gt(locales.size(), 0, "precondition")

	# When: Every Steam code's locale is matched to kit's closest locale.
	var reached: Array[String] = []
	for code in StdInputSteamLanguages.LOCALES:
		reached.append(_find_closest(SteamStorefront.to_locale(code), locales))

	# Then: Each of kit's locales is reached from some code.
	for locale in locales:
		assert_has(reached, locale, "no Steam code reaches '%s'" % locale)


func test_to_locale_unknown_code_returns_empty() -> void:
	# When: The locale for a code Steam doesn't have is read.
	var locale := SteamStorefront.to_locale("klingon")

	# Then: There is none.
	assert_eq(locale, "")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _find_closest returns the locale in `locales` that best matches `locale`, or an empty
## string if none shares its language.
func _find_closest(locale: String, locales: PackedStringArray) -> String:
	var best := ""
	var best_score := 0

	for candidate in locales:
		var score := TranslationServer.compare_locales(candidate, locale)
		if score > best_score:
			best = candidate
			best_score = score

	return best


## _list_kit_locales returns the locale of each catalogue in kit's `locale/` folder.
func _list_kit_locales() -> PackedStringArray:
	var locales := PackedStringArray()

	for filename in DirAccess.get_files_at("res://locale"):
		if filename.ends_with(".po"):
			locales.append(filename.get_basename())

	return locales
