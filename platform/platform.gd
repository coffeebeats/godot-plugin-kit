##
## platform/platform.gd
##
## Platform is an autoloaded singleton `Node` which serves as the root for all platform-
## related functionality (i.e. not game-specific).
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("profile/profile.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _profile: Profile = get_node("Profile")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_user_profile returns the current/local user running the game application.
func get_user_profile() -> KitUserProfile:
	var profile := _profile.get_user_profile()
	if not profile:
		assert(false, "invalid state; missing profile")
		return null

	return profile
