##
## Profile is a `Platform` node which manages information about the user running the
## game application. The implementation for the build's storefront supplies the profile.
##

extends Node

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


func _enter_tree() -> void:
	KitModules.register(self, MODULE_ID, [Storefront.MODULE_ID])


func _ready() -> void:
	if StdGroup.is_empty(Provider.GROUP_PROFILE_PROVIDER):
		KitModules.report_failed(MODULE_ID, "no implementation loaded")
		return

	var provider: Provider = StdGroup.get_sole_member(Provider.GROUP_PROFILE_PROVIDER)

	_profile = provider.create_user_profile()
	if not _profile:
		KitModules.report_failed(MODULE_ID, "implementation supplied no profile")
		return

	_logger.debug("Set profile for platform.", {&"profile": _profile.id})

	KitModules.report_loaded(MODULE_ID)
