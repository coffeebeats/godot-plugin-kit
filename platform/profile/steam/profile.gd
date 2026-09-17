##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../profile.gd")
const UnknownProfile := preload("../unknown/profile.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## profile is the node path to the `Profile`-typed platform node.
@export var profile: NodePath = "../.."

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _profile: Profile = get_node(profile)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(_profile is Profile, "invalid state; missing profile")

	_profile.set_user_profile(_create_user_profile())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_user_profile() -> KitUserProfile:
	var user_profile := KitUserProfile.new()

	var steam_id := Steam.getSteamID()
	if not steam_id:
		return UnknownProfile.create_default_user_profile()

	user_profile.id = str(steam_id)

	return user_profile
