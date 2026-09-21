##
## Provider is the base script for a `Storefront` implementation. It joins
## `GROUP_STOREFRONT_PROVIDER`, which a scene whose script failed to load never does.
##
## NOTE: It joins from `_notification`, so an implementation overriding `_enter_tree`
## need not call `super`.
##

extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_STOREFRONT_PROVIDER := &"platform/storefront:provider"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			StdGroup.with_id(GROUP_STOREFRONT_PROVIDER).add_member(self)
		NOTIFICATION_EXIT_TREE:
			StdGroup.with_id(GROUP_STOREFRONT_PROVIDER).remove_member(self)
