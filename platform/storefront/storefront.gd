##
## Storefront is a `Platform` node which owns the game's storefront integration. It
## loads once the implementation for the build's storefront has joined
## `GROUP_STOREFRONT_PROVIDER`.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Provider := preload("provider.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## MODULE_ID identifies the storefront to `KitModules`.
const MODULE_ID := &"storefront"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	KitModules.register(self, MODULE_ID)


func _ready() -> void:
	if StdGroup.is_empty(Provider.GROUP_STOREFRONT_PROVIDER):
		KitModules.report_failed(MODULE_ID, "no implementation loaded")
		return

	KitModules.report_loaded(MODULE_ID)
