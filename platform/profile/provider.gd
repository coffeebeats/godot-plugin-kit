##
## Provider is the base script for a `Profile` implementation, which supplies the
## profile of the user running the game. It joins `GROUP_PROFILE_PROVIDER`, which a
## scene whose script failed to load never does.
##
## NOTE: It joins from `_notification`, so an implementation overriding `_enter_tree`
## need not call `super`.
##

extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_PROFILE_PROVIDER := &"platform/profile:provider"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create_user_profile returns the profile of the user running the game.
func create_user_profile() -> KitUserProfile:
	assert(false, "unimplemented")
	return null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			StdGroup.with_id(GROUP_PROFILE_PROVIDER).add_member(self)
		NOTIFICATION_EXIT_TREE:
			StdGroup.with_id(GROUP_PROFILE_PROVIDER).remove_member(self)
