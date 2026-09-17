extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../profile.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## profile is the node path to the `Profile`-typed platform node.
@export var profile: NodePath = "../.."

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _profile: Profile = get_node(profile)

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
	assert(_profile is Profile, "invalid state; missing profile")

	_profile.set_user_profile(_create_user_profile())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_user_profile() -> KitUserProfile:
	return create_default_user_profile()
