##
## platform/profile/profile.gd
##
## Profile is a `Platform` node which manages information about the user running the
## game application.
##

extends Node

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
	if _profile:
		assert(false, "invalid state; user profile already set")
		return

	_profile = profile

	_logger.info("Set profile for platform.", {&"profile": profile.id})
