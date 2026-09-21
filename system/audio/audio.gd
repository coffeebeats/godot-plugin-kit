##
## SystemAudio is the game's audio system. It plays sound events through its
## `StdSoundEventPlayer`, plays background music, and ducks the mix under covered
## screens.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_AUDIO_SHIM := &"system/audio:shim"

## MODULE_ID identifies the audio system to `KitModules`.
const MODULE_ID := &"audio"

# -- CONFIGURATION ------------------------------------------------------------------- #

## sound_player is the node which plays the game's sound events from pools of audio
## players.
@export var sound_player: StdSoundEventPlayer = null

## music_player is the music player node for managing background music playback.
@export var music_player: StdMusicPlayer = null

## covered_snapshot is the mix snapshot applied when a screen is covered.
@export var covered_snapshot: StdMixSnapshot = null

## screens is the game's screen manager, whose covered and uncovered signals drive
## the mix snapshot. It lives in the game's own scene rather than this one, so the
## game assigns it at runtime. Ducking is optional, so an unset value disables it
## silently.
@export var screens: StdScreenManager = null:
	set(value):
		if value == screens:
			return

		if screens:
			Signals.disconnect_safe(screens.screen_covered, _on_screen_covered)
			Signals.disconnect_safe(screens.screen_uncovered, _on_screen_uncovered)

		screens = value

		if screens:
			Signals.connect_safe(screens.screen_covered, _on_screen_covered)
			Signals.connect_safe(screens.screen_uncovered, _on_screen_uncovered)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _covered_instance: StdMixSnapshotInstance = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## music returns the music player for managing background music.
func music() -> StdMusicPlayer:
	return music_player


## play plays the provided sound event through `sound_player`. Returns null if every
## audio player is busy with a sound of equal or higher priority.
func play(event: StdSoundEvent, fade_curve: StdTweenCurve = null) -> StdSoundInstance:
	return sound_player.play(event, fade_curve)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_AUDIO_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_AUDIO_SHIM).add_member(self)

	KitModules.register(self, MODULE_ID)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_AUDIO_SHIM).remove_member(self)


func _ready() -> void:
	if not sound_player is StdSoundEventPlayer:
		KitModules.report_failed(MODULE_ID, "missing a sound player")
		return

	KitModules.report_loaded(MODULE_ID)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_screen_covered(_screen: StdScreen, _scene: Node) -> void:
	if _covered_instance and _covered_instance.is_valid():
		return

	if covered_snapshot:
		_covered_instance = covered_snapshot.apply(self)


func _on_screen_uncovered(_screen: StdScreen, _scene: Node) -> void:
	if _covered_instance:
		_covered_instance.remove()
		_covered_instance = null
