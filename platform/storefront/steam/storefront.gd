##
## The storefront implementation for Steam. It starts the Steam API, reports its own
## failure to start to the player, and names the language Steam has for the game.
##

extends "../provider.gd"

# -- DEFINITIONS --------------------------------------------------------------------- #

## LOCALES maps each of Steam's API language codes to a locale. See
## https://partner.steamgames.com/doc/store/localization/languages.
##
## NOTE: Godot drops the region from `es_419`, so Latin American Spanish is `es_MX`.
const LOCALES: Dictionary[String, String] = {
	"arabic": "ar",
	"brazilian": "pt_BR",
	"bulgarian": "bg",
	"czech": "cs",
	"danish": "da",
	"dutch": "nl",
	"english": "en",
	"finnish": "fi",
	"french": "fr",
	"german": "de",
	"greek": "el",
	"hungarian": "hu",
	"indonesian": "id",
	"italian": "it",
	"japanese": "ja",
	"koreana": "ko",
	"latam": "es_MX",
	"malay": "ms",
	"norwegian": "nb",
	"polish": "pl",
	"portuguese": "pt_PT",
	"romanian": "ro",
	"russian": "ru",
	"schinese": "zh_CN",
	"spanish": "es_ES",
	"swedish": "sv",
	"tchinese": "zh_TW",
	"thai": "th",
	"turkish": "tr",
	"ukrainian": "uk",
	"vietnamese": "vi",
}

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_initialized: bool = false
var _logger := StdLogger.create(&"platform/storefront/steam")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## has_language_choice returns whether `available`, Steam's comma-separated list of the
## game's languages, offers more than one. With one or none, Steam names English even
## for a player whose client is in another language.
static func has_language_choice(available: String) -> bool:
	return available.split(",", false).size() > 1


## to_locale returns the locale for Steam's API language code `code`, or an empty string
## if `code` isn't one of Steam's.
static func to_locale(code: String) -> String:
	return LOCALES.get(code, "")


# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


## get_locale returns the locale of the language Steam has for the game, which is the
## player's choice in the game's Steam properties or else Steam's own language. It
## returns an empty string if Steam failed to start, if the game lists fewer than two
## languages in Steamworks, or if Steam names a language `LOCALES` lacks.
func get_locale() -> String:
	if not _is_initialized:
		return ""

	var available := Steam.getAvailableGameLanguages()
	var code := Steam.getCurrentGameLanguage()
	var locale := to_locale(code) if has_language_choice(available) else ""

	(
		_logger
		. debug(
			"Read Steam's game language.",
			{&"available": available, &"code": code, &"locale": locale},
		)
	)

	return locale


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	set_process(false)

	# NOTE: No need to call 'Steam.restartAppIfNecessary', as it should be handled by
	# the Steam DRM wrapper, applied during upload. For more context, see
	# https://partner.steamgames.com/doc/features/drm.

	# NOTE: No app ID is passed, so GodotSteam falls back to the project's
	# 'steam/initialization/app_data' settings and, while those give 0, the SDK reads
	# the ID the Steam client sets at launch or 'steam_appid.txt' beside the
	# executable. Callbacks are not embedded, since '_process' runs them.
	var response := Steam.steamInitEx()

	_is_initialized = response.status == OK
	if _is_initialized:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(true)

		_logger.info("Initialized Steam.")

		return

	_logger.error(
		"Failed to start Steam (%d: %s)." % [response.status, response.verbal]
	)

	var error := (
		KitError
		. new(
			"kit_error_platform_init_title",
			"kit_error_platform_init_steam_message",
			KitError.Severity.CRITICAL,
		)
	)
	KitError.enqueue(error)


func _exit_tree() -> void:
	if not _is_initialized:
		return

	Steam.steamShutdown()


func _process(_delta: float) -> void:
	Steam.run_callbacks()
