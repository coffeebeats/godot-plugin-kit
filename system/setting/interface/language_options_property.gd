##
## system/setting/interface/language_options_property.gd
##
## LanguageOptionsProperty is a read-only settings property that provides a list of
## languages the user can display the user interface in.
##

extends StdSettingsPropertyStringList

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _can_modify() -> bool:
	return false


func _get_value_from_config(_config: Config) -> Variant:
	var options := PackedStringArray()

	for locale in TranslationServer.get_loaded_locales():
		if locale not in options:
			options.append(locale)

	options.sort()

	return options
