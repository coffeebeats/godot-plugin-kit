##
## LanguageOptionFormatter is a type which describes how to format a locale code into a
## list of language names, translated into the respective language.
##

extends StdSettingsControllerOptionButtonFormatter

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Locales := preload("../../../locale/locales.gd")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(locale: Variant) -> String:
	return Locales.tr_language(locale)
