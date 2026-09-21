##
## Storefront is a `Platform` node which owns the game's storefront integration. The
## build's implementation announces itself here, since a scene whose script failed to
## load is still added to the scene tree and cannot be told apart otherwise.
##

extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_STOREFRONT_SHIM := &"platform/storefront:shim"

## MODULE_ID identifies the storefront to `KitModules`.
const MODULE_ID := &"storefront"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _implementation: Node = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## set_implementation records the node implementing the build's storefront. The
## implementation calls it once set up, even if the storefront was unreachable.
func set_implementation(node: Node) -> void:
	_implementation = node


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(
		StdGroup.is_empty(GROUP_STOREFRONT_SHIM), "invalid state; duplicate node found"
	)
	StdGroup.with_id(GROUP_STOREFRONT_SHIM).add_member(self)

	KitModules.register(self, MODULE_ID)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_STOREFRONT_SHIM).remove_member(self)


func _ready() -> void:
	if not _implementation:
		KitModules.report_failed(MODULE_ID, "no implementation announced itself")
		return

	KitModules.report_loaded(MODULE_ID)
