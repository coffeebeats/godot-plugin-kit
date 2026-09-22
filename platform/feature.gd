##
## A shared library for querying feature flags and platform metadata.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It
## is a "static" library that can be imported at compile-time using 'preload'.
##

class_name KitFeature
extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

## HostPlatform enumerates the set of OS/platforms which this game might target.
enum HostPlatform { UNKNOWN, MACOS, WEB, WINDOWS }

## Storefront enumerates the set of storefronts on which this game might be published.
enum Storefront {
	UNKNOWN,
	GOG,
	STEAM,
}

## FEATURE_DEBUG marks a build with debugging enabled.
const FEATURE_DEBUG := &"debug"

## FEATURE_EDITOR marks a game running from the Godot editor.
const FEATURE_EDITOR := &"editor"

## FEATURE_MACOS, FEATURE_WEB and FEATURE_WINDOWS name the host platforms this game
## targets.
const FEATURE_MACOS := &"macos"
const FEATURE_WEB := &"web"
const FEATURE_WINDOWS := &"windows"

## FEATURE_STOREFRONT_* name the storefront a build targets. A preset declares one
## through `custom_features`, which no constant can reach, so the spelling here is the
## contract that file must match. A build declaring none targets `Storefront.UNKNOWN`.
const FEATURE_STOREFRONT_GOG := &"storefront:gog"
const FEATURE_STOREFRONT_STEAM := &"storefront:steam"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_platform returns which platform this game is currently running on.
static func get_platform() -> HostPlatform:
	if is_windows_platform():
		return HostPlatform.WINDOWS
	if is_macos_platform():
		return HostPlatform.MACOS
	if is_web_platform():
		return HostPlatform.WEB

	return HostPlatform.UNKNOWN


## is_editor_build returns whether the game is running via the Godot editor.
static func is_editor_build() -> bool:
	return OS.has_feature(FEATURE_EDITOR)


## is_macos_platform returns whether this game is running on macOS.
static func is_macos_platform() -> bool:
	return OS.has_feature(FEATURE_MACOS)


## is_web_platform returns whether this game is running on a web browser.
static func is_web_platform() -> bool:
	return OS.has_feature(FEATURE_WEB)


## is_windows_platform returns whether this game is running on Windows.
static func is_windows_platform() -> bool:
	return OS.has_feature(FEATURE_WINDOWS)


## get_storefront returns the 'Storefront' targeted by the current game build, which is
## `UNKNOWN` for a build declaring no storefront feature, the editor included.
static func get_storefront() -> Storefront:
	if is_steam_storefront_enabled():
		assert(not is_gog_storefront_enabled(), "cannot enable multiple storefronts")
		return Storefront.STEAM
	if is_gog_storefront_enabled():
		assert(not is_steam_storefront_enabled(), "cannot enable multiple storefronts")
		return Storefront.GOG

	return Storefront.UNKNOWN


## is_steam_enabled returns whether the game build is targeting the Steam 'Storefront'.
static func is_steam_storefront_enabled() -> bool:
	return OS.has_feature(FEATURE_STOREFRONT_STEAM)


## is_gog_enabled returns whether the game build is targeting the GOG 'Storefront'.
static func is_gog_storefront_enabled() -> bool:
	return OS.has_feature(FEATURE_STOREFRONT_GOG)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
