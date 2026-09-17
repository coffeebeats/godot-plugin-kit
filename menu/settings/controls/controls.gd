##
## Controls is the settings menu's controls tab. Beside kit's own menu action sets, it
## lists the game's, read from the `Input` system component's `action_sets`, so a game
## makes its actions rebindable without editing the tab.
##

extends VBoxContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ActionSetScene := preload("action_set.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which the game's binding overrides will be stored.
@export var scope: StdSettingsScope = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_add_action_sets(KitSystems.input().action_sets)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action_sets lists each action set, in order, above kit's own action sets.
func _add_action_sets(action_sets: Array[StdInputActionSet]) -> void:
	assert(scope is StdSettingsScope, "invalid config; missing scope")

	var index := get_node(^"%MenuControls").get_index()

	for action_set in action_sets:
		var group := ActionSetScene.instantiate()
		group.action_set = action_set
		group.scope = scope

		add_child(group)
		move_child(group, index)

		index += 1
