##
## SystemAudio is a sound event player which manages pools of audio player nodes, a
## music player, and mix snapshot handling for covered screens.
##

extends StdSoundEventPlayer

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_AUDIO_SHIM := &"system/audio:shim"

# -- CONFIGURATION ------------------------------------------------------------------- #

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


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	super._enter_tree()

	assert(StdGroup.is_empty(GROUP_AUDIO_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_AUDIO_SHIM).add_member(self)


func _exit_tree() -> void:
	super._exit_tree()

	StdGroup.with_id(GROUP_AUDIO_SHIM).remove_member(self)


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
