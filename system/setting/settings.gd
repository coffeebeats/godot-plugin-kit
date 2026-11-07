##
## SystemSettings is the system for the game's settings: the scopes which store them,
## the observers which apply them, and the game's own tabs in the settings menu.
##

extends KitModule

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../../platform/profile/profile.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_SETTINGS_SHIM := &"system/setting:shim"

## MODULE_ID is the ID the settings system registers under as a `KitModule`.
const MODULE_ID := &"settings"

# -- CONFIGURATION ------------------------------------------------------------------- #

## menu_settings are the ids of the kit rows and rebinding groups the settings menu
## shows, defaulting to all of kit's. A group left with no row is left out, as is a
## tab left with none of kit's rows or groups.
@export var menu_settings: Array[StringName] = [
	&"sound_volume_master",
	&"sound_volume_sound_effects",
	&"sound_volume_music",
	&"sound_volume_voice",
	&"sound_audio_device",
	&"sound_audio_bg_mute",
	&"interface_language_display",
	&"interface_text_scaling",
	&"display_video_fullscreen",
	&"display_video_borderless",
	&"display_video_fps_limit",
	&"display_video_vsync",
	&"controller_button_prompt",
	&"controller_disable_vibration",
	&"controller_vibration_strength",
	&"controller_steam_configurator",
	&"controller_bindings_menu",
	&"controller_bindings_menu_tabbed",
	&"controller_bindings_menu_options",
	&"controller_bindings_menu_binding",
	&"keyboard_mouse_confine_cursor",
	&"keyboard_mouse_bindings_menu",
	&"keyboard_mouse_bindings_menu_tabbed",
	&"keyboard_mouse_bindings_menu_options",
	&"keyboard_mouse_bindings_menu_binding",
]

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
