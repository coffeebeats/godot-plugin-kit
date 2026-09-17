##
## KitSystems is a shim for the `System` autoload scene which allows accessing its
## components without directly referencing the autoloaded scene itself. This is a
## workaround for errors encountered when scripts referencing the `System` autoload are
## loaded in the background (see https://github.com/godotengine/godot/issues/98865).
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It
## is a "static" library that can be imported at compile-time using 'preload'.
##

class_name KitSystems
extends Object

# -- DEPENDENCIES -------------------------------------------------------------------- #

const InputSystem := preload("input/input.gd")
const SavesSystem := preload("save/saves.gd")
const AudioSystem := preload("audio/audio.gd")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## audio returns the `Audio` system component.
static func audio() -> AudioSystem:
	return StdGroup.get_sole_member(AudioSystem.GROUP_AUDIO_SHIM)


## input returns the `Input` system component.
static func input() -> InputSystem:
	return StdGroup.get_sole_member(InputSystem.GROUP_INPUT_SHIM)


## saves returns the `Saves` system component.
static func saves() -> SavesSystem:
	return StdGroup.get_sole_member(SavesSystem.GROUP_SAVES_SHIM)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
