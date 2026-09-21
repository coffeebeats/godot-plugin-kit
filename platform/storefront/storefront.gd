##
## Storefront is a `Platform` node which owns the game's storefront integration. It
## loads once exactly one implementation, the one for the build's storefront, has joined
## `GROUP_STOREFRONT_PROVIDER`.
##

extends KitModule

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Provider := preload("provider.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## MODULE_ID is the ID the storefront registers under as a `KitModule`.
const MODULE_ID := &"storefront"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	var providers := StdGroup.with_id(Provider.GROUP_STOREFRONT_PROVIDER).list_members()
	if providers.size() != 1:
		_report_failed("found %d implementations, expected 1" % providers.size())
		return

	_report_loaded()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID
