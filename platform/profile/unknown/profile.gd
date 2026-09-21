extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../profile.gd")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create_default_user_profile creates a `KitUserProfile` defining the default profile
## information. This is intended to be used when the platform doesn't have a profile
## capability or the profile cannot be retrieved.
static func create_default_user_profile() -> KitUserProfile:
	var user_profile := KitUserProfile.new()
	user_profile.id = "public"

	return user_profile


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	var profile: Profile = StdGroup.get_sole_member(Profile.GROUP_PROFILE_SHIM)
	profile.set_user_profile(create_default_user_profile())
