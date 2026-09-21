##
## Provider is the base script for a `Storefront` implementation. It joins
## `GROUP_STOREFRONT_PROVIDER`, which a scene whose script failed to load never does.
##

extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_STOREFRONT_PROVIDER := &"platform/storefront:provider"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	StdGroup.with_id(GROUP_STOREFRONT_PROVIDER).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_STOREFRONT_PROVIDER).remove_member(self)
