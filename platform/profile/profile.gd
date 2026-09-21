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

## MODULE_ID is the ID the profile registers under as a `KitModule`.
const MODULE_ID := &"profile"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"platform/profile/profile")
var _profile: KitUserProfile = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_user_profile returns the profile of the user running the game, or null unless
## exactly one `Profile` is in the scene tree and it holds a profile.
##
## NOTE: Kit's scripts call this rather than naming the `Platform` autoload, since a
## script naming it fails to parse wherever that autoload is missing or not yet loaded.
static func find_user_profile() -> KitUserProfile:
	var profiles := StdGroup.with_id(GROUP_PROFILE_SHIM).list_members()
	if profiles.size() != 1:
		return null

	return profiles[0].get_user_profile()


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
	var providers := StdGroup.with_id(Provider.GROUP_PROFILE_PROVIDER).list_members()
	if providers.size() != 1:
		_report_failed("found %d implementations, expected 1" % providers.size())
		return

	var provider: Provider = providers[0]

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
