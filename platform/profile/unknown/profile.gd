extends "../provider.gd"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create_default_user_profile creates a `KitUserProfile` defining the default profile
## information. This is intended to be used when the platform doesn't have a profile
## capability or the profile cannot be retrieved.
static func create_default_user_profile() -> KitUserProfile:
	var user_profile := KitUserProfile.new()
	user_profile.id = "public"

	return user_profile


## create_user_profile returns the default profile.
func create_user_profile() -> KitUserProfile:
	return create_default_user_profile()
