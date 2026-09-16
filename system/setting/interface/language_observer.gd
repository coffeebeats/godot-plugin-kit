##
## system/setting/language_observer.gd
##
## LanguageObserver is a `StdSettingsObserver` that handles updating the display
## language.
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
	var path_dir := ProjectSettings.globalize_path("user://locale")
	var logger := _logger.with({&"directory": path_dir})

	if not DirAccess.dir_exists_absolute(path_dir):
		logger.info("Custom locale directory doesn't exist; skipping locale import.")
		return

	# NOTE: Because the file names are sorted alphabetically, `.mo` files will always be
	# loaded before `.po` files, which is the desired behavior.
	for filename in DirAccess.get_files_at(path_dir):
		if not (filename.ends_with(&".po") or filename.ends_with(&".mo")):
			continue

		logger = logger.with({&"file": filename})

		var translation: Translation = load(path_dir.path_join(filename))
		if not translation is Translation:
			logger.warn("Failed to load custom translation file.")
			continue

		var locale := translation.locale  # Don't rely on the filename.
		logger = logger.with({&"locale": translation.locale})

		if locale in _custom_translations:
			logger.warn("Ignoring duplicate custom translation file.")
			continue

		var current := TranslationServer.get_translation_object(locale)
		if current and locale in TranslationServer.get_loaded_locales():
			logger.debug("Overwriting existing translation with custom file.")
			TranslationServer.remove_translation(current)

		TranslationServer.add_translation(translation)
		_custom_translations[locale] = translation

		logger.info("Loaded custom translation file.")


func _update_display_language(locale: String) -> void:
	assert(locale != "", "invalid argument; missing locale")

	_logger.info("Updating display language.", {&"locale": locale})

	TranslationServer.set_locale(locale)
