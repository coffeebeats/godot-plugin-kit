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

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_locale returns the locale of the language the build's storefront has for the
## game, or an empty string unless exactly one implementation is in the scene tree and
## it names one.
##
## NOTE: Kit's scripts call this rather than naming the `Platform` autoload, since a
## script naming it fails to parse wherever that autoload is missing or not yet loaded.
static func find_locale() -> String:
	var providers := StdGroup.with_id(Provider.GROUP_STOREFRONT_PROVIDER).list_members()
	if providers.size() != 1:
		return ""

	return providers[0].get_locale()


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
