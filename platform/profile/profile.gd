##
## Profile is a `Platform` node which manages information about the user running the
## game application. The implementation for the build's storefront supplies the profile.
##

extends KitModule

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Provider := preload("provider.gd")
const Storefront := preload("../storefront/storefront.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## MODULE_ID identifies the profile to `KitModules`.
const MODULE_ID := &"profile"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"platform/profile/profile")
var _profile: KitUserProfile = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_user_profile returns information about the profile currently running the game
## application.
func get_user_profile() -> KitUserProfile:
	return _profile


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	if StdGroup.is_empty(Provider.GROUP_PROFILE_PROVIDER):
		_report_failed("no implementation loaded")
		return

	var provider: Provider = StdGroup.get_sole_member(Provider.GROUP_PROFILE_PROVIDER)

	_profile = provider.create_user_profile()
	if not _profile:
		_report_failed("implementation supplied no profile")
		return

	_logger.debug("Set profile for platform.", {&"profile": _profile.id})

	_report_loaded()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID


func _get_module_requires() -> Array[StringName]:
	return [Storefront.MODULE_ID]
