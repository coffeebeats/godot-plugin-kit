extends "../provider.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const UnknownProfile := preload("../unknown/profile.gd")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create_user_profile returns the signed-in Steam user's profile, or the default
## profile if Steam has no user.
func create_user_profile() -> KitUserProfile:
	var user_profile := KitUserProfile.new()

	var steam_id := Steam.getSteamID()
	if not steam_id:
		return UnknownProfile.create_default_user_profile()

	user_profile.id = str(steam_id)

	return user_profile
