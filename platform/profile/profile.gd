##
## Profile is a `Platform` node which manages information about the user running the
## game application. The implementation for the build's storefront supplies the profile.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Storefront := preload("../storefront/storefront.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_PROFILE_SHIM := &"platform/profile:shim"

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


## set_user_profile updates the current user profile.
func set_user_profile(profile: KitUserProfile) -> void:
	_profile = profile

	_logger.debug("Set profile for platform.", {&"profile": profile.id})


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_PROFILE_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_PROFILE_SHIM).add_member(self)

	KitModules.register(self, MODULE_ID, [Storefront.MODULE_ID])


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_PROFILE_SHIM).remove_member(self)


func _ready() -> void:
	if not _profile:
		KitModules.report_failed(MODULE_ID, "no implementation supplied a profile")
		return

	KitModules.report_loaded(MODULE_ID)
