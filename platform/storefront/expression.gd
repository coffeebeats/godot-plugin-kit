##
## An `StdConditionExpression` which allows its nodes in a build targeting the
## configured storefront, as `KitFeature.get_storefront` reports it.
##

extends StdConditionExpression

# -- CONFIGURATION ------------------------------------------------------------------- #

## storefront is the storefront whose builds this expression allows.
@export var storefront: KitFeature.Storefront = KitFeature.Storefront.UNKNOWN

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_allowed() -> bool:
	return KitFeature.get_storefront() == storefront
