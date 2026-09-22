##
## The storefront implementation for Steam. It starts the Steam API and reports its own
## failure to start to the player.
##

extends "../provider.gd"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_initialized: bool = false
var _logger := StdLogger.create(&"platform/storefront/steam")

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
