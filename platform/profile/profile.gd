##
## Profile is a `Platform` node which manages information about the user running the
## game application. The implementation for the build's storefront supplies the profile.
##

extends KitModule

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Provider := preload("provider.gd")
const Storefront := preload("../storefront/storefront.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_PROFILE_SHIM := &"platform/profile:shim"

## MODULE_ID identifies the profile as a `KitModule`.
const MODULE_ID := &"profile"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"platform/profile/profile")
var _profile: KitUserProfile = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_user_profile returns the profile of the user running the game, or null if no
## `Profile` is in the scene tree or it holds no profile.
##
## NOTE: Kit's scripts call this rather than naming the `Platform` autoload, which fails
## to parse wherever that autoload is missing or has not loaded yet.
static func find_user_profile() -> KitUserProfile:
	if StdGroup.is_empty(GROUP_PROFILE_SHIM):
		return null

	return StdGroup.get_sole_member(GROUP_PROFILE_SHIM).get_user_profile()


## get_user_profile returns information about the profile currently running the game
## application.
func get_user_profile() -> KitUserProfile:
	return _profile


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	StdGroup.with_id(GROUP_PROFILE_SHIM).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_PROFILE_SHIM).remove_member(self)


func _ready() -> void:
	if StdGroup.is_empty(Provider.GROUP_PROFILE_PROVIDER):
		_report_failed("no implementation loaded")
		return

	var provider: Provider = StdGroup.get_sole_member(Provider.GROUP_PROFILE_PROVIDER)

	_profile = provider.create_user_profile()
	if not _profile:
		_report_failed("implementation supplied no profile")
		return

	_logger.debug("Set profile for platform.", {&"profile": _profile.id})

	_report_loaded()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID


func _get_module_requires() -> Array[StringName]:
	return [Storefront.MODULE_ID]
