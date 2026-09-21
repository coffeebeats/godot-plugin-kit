extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../profile.gd")
const UnknownProfile := preload("../unknown/profile.gd")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	var profile: Profile = StdGroup.get_sole_member(Profile.GROUP_PROFILE_SHIM)
	profile.set_user_profile(_create_user_profile())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_user_profile() -> KitUserProfile:
	var user_profile := KitUserProfile.new()

	var steam_id := Steam.getSteamID()
	if not steam_id:
		return UnknownProfile.create_default_user_profile()

	user_profile.id = str(steam_id)

	return user_profile
