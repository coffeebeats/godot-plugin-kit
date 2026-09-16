##
## platform/storefront/steam/steam_storefront.gd
##
## This node initializes the `Steam` storefront integration.
##

extends Node

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_initialized: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	set_process(false)

	# NOTE: No need to call 'Steam.restartAppIfNecessary', as it should be handled by
	# the Steam DRM wrapper, applied during upload. For more context, see
	# https://partner.steamgames.com/doc/features/drm.

	var response := Steam.steamInitEx(true)

	_is_initialized = response.status == OK
	if _is_initialized:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(true)

		print(
			"platform/storefront/steam/steam.gd[",
			get_instance_id(),
			"]: successfully initialized Steam",
		)

		return

	print(
		"platform/storefront/steam/steam.gd[",
		get_instance_id(),
		"]: failed to start Steam: %d: %s" % [response.status, response.verbal],
	)

	var error := (
		KitError
		. new(
			"error_platform_init_title",
			"error_platform_init_steam_message",
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
