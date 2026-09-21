##
## SystemSettings is the system for the game's settings: the scopes which store them,
## the observers which apply them, and the game's own tabs in the settings menu.
##

extends KitModule

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../../platform/profile/profile.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_SETTINGS_SHIM := &"system/setting:shim"

## MODULE_ID identifies the settings system to `KitModules`.
const MODULE_ID := &"settings"

# -- CONFIGURATION ------------------------------------------------------------------- #

## menu_tabs are the game's own settings menu tabs, each keyed by its label's message
## ID, which the settings menu shows after kit's own. The settings menu loads at
## runtime, out of reach of the scene placing this node, so it reads the value here.
@export var menu_tabs: Dictionary[String, PackedScene] = {}

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(
		StdGroup.is_empty(GROUP_SETTINGS_SHIM), "invalid state; duplicate node found"
	)
	StdGroup.with_id(GROUP_SETTINGS_SHIM).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_SETTINGS_SHIM).remove_member(self)


func _ready() -> void:
	_report_loaded()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID


func _get_module_requires() -> Array[StringName]:
	return [Profile.MODULE_ID]
