##
## project/main/logging.gd
##
## Sets up logging profiles for the applicatione.
##
## NOTE: This node should enter the scene tree before any loggers are used so that they
## are correctly configured before use.
##

extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## profile_default is the default logging profile.
@export var profile_default: StdLogProfile = null

## profile_editor is a logging profile to use when running the project from an editor.
@export var profile_editor: StdLogProfile = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if OS.has_feature("editor") and profile_editor:
		profile_editor.apply()
	elif profile_default:
		profile_default.apply()
