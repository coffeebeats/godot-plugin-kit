##
## SystemSettings is the system for the game's settings: the scopes which store them,
## the observers which apply them, and the game's own tabs in the settings menu.
##

extends KitModule

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../../platform/profile/profile.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_SETTINGS_SHIM := &"system/setting:shim"

## MENU_SETTINGS names each of kit's settings menu rows and rebinding groups by id,
## with whether the menu shows it unless `menu_setting_overrides` says otherwise.
const MENU_SETTINGS: Dictionary[StringName, bool] = {
	&"sound_volume_master": true,
	&"sound_volume_sound_effects": true,
	&"sound_volume_music": true,
	&"sound_volume_voice": true,
	&"sound_audio_device": true,
	&"sound_audio_bg_mute": true,
	&"interface_language_display": true,
	&"interface_text_scaling": true,
	&"display_video_fullscreen": true,
	&"display_video_borderless": true,
	&"display_video_fps_limit": true,
	&"display_video_vsync": true,
	&"controller_button_prompt": true,
	&"controller_disable_vibration": true,
	&"controller_vibration_strength": true,
	&"controller_steam_configurator": true,
	&"controller_bindings_menu": true,
	&"controller_bindings_menu_tabbed": true,
	&"controller_bindings_menu_options": true,
	&"controller_bindings_menu_binding": true,
	&"keyboard_mouse_confine_cursor": true,
	&"keyboard_mouse_bindings_menu": true,
	&"keyboard_mouse_bindings_menu_tabbed": true,
	&"keyboard_mouse_bindings_menu_options": true,
	&"keyboard_mouse_bindings_menu_binding": true,
	&"accessibility_holds_mode": false,
}

## MODULE_ID is the ID the settings system registers under as a `KitModule`.
const MODULE_ID := &"settings"

# -- CONFIGURATION ------------------------------------------------------------------- #

## menu_setting_overrides shows or hides each of kit's settings menu rows and
## rebinding groups it names, by id, over `MENU_SETTINGS`. A group left with no row is
## left out, as is a tab left with none of kit's rows or groups.
@export var menu_setting_overrides: Dictionary[StringName, bool] = {}

## menu_tabs are the game's own settings menu tabs, each keyed by its label's message
## ID, which the settings menu shows after kit's own. The settings menu loads at
## runtime, out of reach of the scene placing this node, so it reads the value here.
##
## NOTE: The menu stays in the tree between opens, so a tab follows the `IN_TREE` rules
## on `StdScreen.CacheMode` and does per-open work on `screen_entering`, not
## `_enter_tree`. One that breaks them keeps the menu detached, and std logs an error.
@export var menu_tabs: Dictionary[String, PackedScene] = {}

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"system/setting/settings")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_shown_menu_settings returns the ids of the rows and rebinding groups of kit's
## settings menu which it shows, after `menu_setting_overrides`.
func get_shown_menu_settings() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in MENU_SETTINGS:
		if menu_setting_overrides.get(id, MENU_SETTINGS[id]):
			out.append(id)

	return out


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(
		StdGroup.is_empty(GROUP_SETTINGS_SHIM), "invalid state; duplicate node found"
	)
	StdGroup.with_id(GROUP_SETTINGS_SHIM).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_SETTINGS_SHIM).remove_member(self)


func _ready() -> void:
	for id in menu_setting_overrides:
		if id not in MENU_SETTINGS:
			_logger.warn(
				"Unknown menu setting override; kit has no such row.", {&"id": id}
			)

	_report_loaded()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID


func _get_module_requires() -> Array[StringName]:
	return [Profile.MODULE_ID]
