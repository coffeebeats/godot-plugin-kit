##
## The storefront implementation for a build published outside any storefront, so that
## every build has one. It has nothing to set up and only announces itself.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Storefront := preload("../storefront.gd")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	var storefront: Storefront = StdGroup.get_sole_member(
		Storefront.GROUP_STOREFRONT_SHIM
	)
	storefront.set_implementation(self)
