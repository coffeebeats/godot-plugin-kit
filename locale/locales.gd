##
## Locales is a shared library for working with translations.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It
## is a "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

## MSGCTXT_ACTION_PREFIX prefixes an action set's name to form the context under which
## its actions' names are translated.
const MSGCTXT_ACTION_PREFIX := &"actions_"

## MSGCTXT_ACTION_SET is the context under which action set names are translated.
const MSGCTXT_ACTION_SET := &"action_sets"

const MSGID_LANGUAGE := &"locale_language"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## tr_action translates an input action, falling back to the project's fallback locale
## and then to the action's name. Provide `locale` to specify a locale other than the
## one currently loaded.
static func tr_action(
	action_set: StringName,
	action: StringName,
	locale: StringName = &"",
) -> String:
	var translated := _translate_with_fallback(
		action, MSGCTXT_ACTION_PREFIX + action_set, locale
	)
	return translated if translated else str(action)


## tr_action_set translates an input action set, falling back to the project's fallback
## locale and then to the set's name. Provide `locale` to specify a locale other than
## the one currently loaded.
static func tr_action_set(action_set: StringName, locale: StringName = &"") -> String:
	var translated := _translate_with_fallback(action_set, MSGCTXT_ACTION_SET, locale)
	return translated if translated else str(action_set)


## tr_language translates the provided locale into the name of the language in the
## language itself.
##
## NOTE: This should be implemented within the engine; see
## https://github.com/godotengine/godot-proposals/issues/2378.
static func tr_language(locale: StringName) -> String:
	# NOTE: This skips the fallback locale, whose catalogue names a different language.
	var translated := _translate(MSGID_LANGUAGE, &"", locale)
	match translated:
		MSGID_LANGUAGE:
			return "English"
		"":
			return str(locale)
		_:
			return translated


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _translate returns the message from the loaded catalogue whose locale best matches
## `locale`, or an empty string if none has it. Among equally good matches the
## catalogue listed first wins, so a game lists its own catalogue before kit's to
## override kit's strings.
static func _translate(msg: StringName, ctx: StringName, locale: StringName) -> String:
	if locale == &"":
		locale = TranslationServer.get_locale()

	var result := ""
	var best_score := 0

	for translation: Translation in TranslationServer.find_translations(locale, false):
		var score := TranslationServer.compare_locales(locale, translation.get_locale())
		if score <= best_score:
			continue

		var message: String = translation.get_message(msg, ctx)
		if message:
			result = message
			best_score = score

	return result


## _translate_with_fallback returns the message `_translate` finds for `locale`, or else
## the one it finds for the project's fallback locale, as the engine's `tr` does.
static func _translate_with_fallback(
	msg: StringName, ctx: StringName, locale: StringName
) -> String:
	var translated := _translate(msg, ctx, locale)
	if translated:
		return translated

	var fallback: String = ProjectSettings.get_setting(
		"internationalization/locale/fallback", "en"
	)
	return _translate(msg, ctx, fallback)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
