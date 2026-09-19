##
## Tests for `Locales`, which resolves messages across every loaded catalogue so that a
## game's catalogue and kit's can both be registered.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Locales := preload("locales.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## LOCALE is a locale no project catalogue carries, so only this test's catalogues
## match.
const LOCALE := &"sw_KE"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _translations: Array[Translation] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_tr_action_finds_a_message_only_the_second_catalogue_has() -> void:
	# Given: Two catalogues, of which only the second holds the action.
	_add_catalogue(LOCALE, {})
	_add_catalogue(LOCALE, {&"ui_accept": "Accept"})

	# When: The action is translated.
	var got := Locales.tr_action(&"Menu", &"ui_accept", LOCALE)

	# Then: The second catalogue's message is used.
	assert_eq(got, "Accept")


func test_tr_action_prefers_the_first_catalogue_listed() -> void:
	# Given: Two catalogues holding the same action.
	_add_catalogue(LOCALE, {&"ui_accept": "Override"})
	_add_catalogue(LOCALE, {&"ui_accept": "Accept"})

	# When: The action is translated.
	var got := Locales.tr_action(&"Menu", &"ui_accept", LOCALE)

	# Then: The first catalogue's message is used.
	assert_eq(got, "Override")


func test_tr_action_prefers_the_closer_locale_over_the_order_listed() -> void:
	# Given: A language-only catalogue listed before an exact-locale one.
	_add_catalogue(&"sw", {&"ui_accept": "Language"})
	_add_catalogue(LOCALE, {&"ui_accept": "Exact"})

	# When: The action is translated.
	var got := Locales.tr_action(&"Menu", &"ui_accept", LOCALE)

	# Then: The exact-locale catalogue's message is used.
	assert_eq(got, "Exact")


func test_tr_action_falls_back_to_the_fallback_locale_when_untranslated() -> void:
	# Given: A catalogue for the requested locale without the action.
	_add_catalogue(LOCALE, {})

	# Given: A catalogue for English, the default fallback locale, holding the action.
	_add_catalogue(&"en_US", {&"ui_accept": "Accept"})

	# When: The action is translated.
	var got := Locales.tr_action(&"Menu", &"ui_accept", LOCALE)

	# Then: The fallback locale's message is used.
	assert_eq(got, "Accept")


func test_tr_action_set_falls_back_to_the_set_name_when_untranslated() -> void:
	# Given: A catalogue without the action set.
	_add_catalogue(LOCALE, {})

	# When: The action set is translated.
	var got := Locales.tr_action_set(&"Menu", LOCALE)

	# Then: The action set's own name is used.
	assert_eq(got, "Menu")


func test_tr_language_ignores_the_fallback_locale() -> void:
	# Given: A catalogue for English, the default fallback locale, naming its language.
	_add_catalogue(&"en_US", {Locales.MSGID_LANGUAGE: "English"}, &"")

	# When: A locale no catalogue names is translated.
	var got := Locales.tr_language(LOCALE)

	# Then: The locale itself is used rather than the fallback language's name.
	assert_eq(got, str(LOCALE))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	for translation in _translations:
		TranslationServer.remove_translation(translation)

	_translations.clear()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _add_catalogue(
	locale: StringName,
	messages: Dictionary,
	ctx: StringName = Locales.MSGCTXT_ACTION_PREFIX + "Menu",
) -> void:
	var translation := Translation.new()
	translation.locale = locale

	for msg in messages:
		translation.add_message(msg, messages[msg], ctx)

	TranslationServer.add_translation(translation)
	_translations.append(translation)
