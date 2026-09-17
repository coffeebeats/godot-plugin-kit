##
## Tests for the controls tab, which lists a game's action sets beside kit's own.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ControlsScene := preload("controls.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_add_action_sets_lists_the_game_sets_above_kit_sets_in_order() -> void:
	# Given: A controls tab, outside the tree since its bindings need an input slot.
	var controls: VBoxContainer = autofree(ControlsScene.instantiate())

	# Given: Two game action sets.
	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"

	var options := StdInputActionSetLayer.new()
	options.name = &"GameplayOptions"

	var action_sets: Array[StdInputActionSet] = [gameplay, options]

	# When: The game's action sets are added.
	controls._add_action_sets(action_sets)

	# Then: Both are listed, in order, directly above kit's first action set.
	var index := controls.get_node(^"%MenuControls").get_index()
	assert_eq(controls.get_child(index - 2).action_set, gameplay)
	assert_eq(controls.get_child(index - 1).action_set, options)

	# Then: Both store their bindings in the tab's scope.
	assert_not_null(controls.scope)
	assert_eq(controls.get_child(index - 2).scope, controls.scope)
	assert_eq(controls.get_child(index - 1).scope, controls.scope)
