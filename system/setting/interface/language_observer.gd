##
## LanguageObserver is a `StdSettingsObserver` that updates the display language.
##

extends StdSettingsObserver

# -- DEPENDENCIES -------------------------------------------------------------------- #

const LanguageOptionsProperty := preload("language_options_property.gd")
const LanguageProperty := preload("language_property.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## language_property is a `StdSettingsPropertyString` defining the target locale code.
@export var language_property: StdSettingsPropertyString = null

## language_options_property is a `StdSettingsPropertyStringList` defining the list of
## supported locale codes.
@export var language_options_property: StdSettingsPropertyStringList = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _custom_translations := {}
var _logger := StdLogger.create(&"system/setting/language")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	# NOTE: Steam sends no callback when the player changes the game's language in its
	# window, so the language is read again each time focus returns to the game.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		language_property.refresh_default()


func _ready() -> void:
	assert(language_property is LanguageProperty, "invalid config: missing property")
	assert(
		language_options_property is LanguageOptionsProperty,
		"invalid config: missing property",
	)

	_load_custom_translations()

	language_property.initialize()

	super._ready()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [language_property, language_options_property]


func _handle_value_change(property: StdSettingsProperty, value: Variant) -> void:
	if property == language_property:
		_update_display_language(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _load_custom_translations() -> void:
	var path_user := "user://locale"
	var path_dir := ProjectSettings.globalize_path(path_user)

	# NOTE: The global path contains the OS user's name, so logs carry the virtual one.
	var logger := _logger.with({&"directory": path_user})

	if not DirAccess.dir_exists_absolute(path_dir):
		logger.debug("Custom locale directory doesn't exist; skipping locale import.")
		return

	# NOTE: The file names sort alphabetically, so a `.mo` file loads before a `.po`
	# file of the same name, which is then skipped as a duplicate locale.
	for filename in DirAccess.get_files_at(path_dir):
		if not (filename.ends_with(&".po") or filename.ends_with(&".mo")):
			continue

		logger = logger.with({&"file": filename})

		var translation: Translation = StdLoader.load_now(path_dir.path_join(filename))
		if not translation is Translation:
			logger.warn("Failed to load custom translation file.")
			continue

		var locale := translation.locale  # Don't rely on the filename.
		logger = logger.with({&"locale": translation.locale})

		if locale in _custom_translations:
			logger.warn("Ignoring duplicate custom translation file.")
			continue

		# NOTE: Only an exact match is replaced. A translation that merely serves this
		# locale as a fallback is left loaded for the locale it is actually for.
		for current: Translation in TranslationServer.find_translations(locale, true):
			logger.debug("Overwriting existing translation with custom file.")
			TranslationServer.remove_translation(current)

		TranslationServer.add_translation(translation)
		_custom_translations[locale] = translation

		logger.info("Loaded custom translation file.")


func _update_display_language(locale: String) -> void:
	assert(locale != "", "invalid argument; missing locale")

	_logger.info("Updating display language.", {&"locale": locale})

	TranslationServer.set_locale(locale)
