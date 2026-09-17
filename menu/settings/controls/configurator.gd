##
## SteamConfigurator is a node which will open the Steam Configurator (i.e. bindings
## panel) whenever the configure `Button` node is pressed.
##

extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## button is a `Button` node which, when pressed, will trigger the Steam bindings panel
## to be shown.
@export var button: Button = null

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1

## configurator is a path to a scene with a `StdInputSteamConfigurator` root node.
@export_file("*.tscn") var configurator: String = ""

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(button is Button, "invalid config; missing button node")
	assert(configurator, "invalid state; missing scene")

	var packed_scene: PackedScene = load(configurator)
	assert(packed_scene is PackedScene, "invalid config; missing configurator scene")

	var node := packed_scene.instantiate()
	if not node:
		assert(false, "failed to load configurator resource")
		return

	node.button = button
	node.player_id = player_id

	add_child(node)
