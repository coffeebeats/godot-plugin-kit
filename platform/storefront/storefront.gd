##
## Storefront is a `Platform` node which owns the game's storefront integration. It
## loads once the implementation for the build's storefront has joined
## `GROUP_STOREFRONT_PROVIDER`.
##

extends KitModule

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Provider := preload("provider.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## MODULE_ID identifies the storefront to `KitModules`.
const MODULE_ID := &"storefront"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	if StdGroup.is_empty(Provider.GROUP_STOREFRONT_PROVIDER):
		_report_failed("no implementation loaded")
		return

	_report_loaded()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID
