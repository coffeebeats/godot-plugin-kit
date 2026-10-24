##
## Tests for a controls tab group, which lists one action set's rebindable actions.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ActionSetScene := preload("action_set.tscn")
const Setting := preload("../setting.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_generate_settings_lists_a_stick_directions_without_the_stick() -> void:
	# Given: A group, outside the tree since its bindings need an input slot.
	var group: VBoxContainer = autofree(ActionSetScene.instantiate())

	# Given: An action set with a stick, its four directions and a button.
	var actions := StdInputActionSet.new()
	actions.name = &"Gameplay"
	actions.actions_analog_2d = [&"move"] as Array[StringName]
	actions.actions_digital = (
		[&"move_left", &"move_right", &"move_up", &"move_down", &"jump"]
		as Array[StringName]
	)
	group.action_set = actions

	# When: The group generates a setting per action.
	group._generate_settings()

	# Then: Each direction and the button has a row, and the stick has none.
	var listed: Array[StringName] = []
	for node in group.get_children():
		# NOTE: A row holds its label, its reset button, then its primary binding.
		if node is Setting:
			listed.append(node.get_child(2).glyph.action)

	assert_eq(
		listed,
		(
			[&"move_left", &"move_right", &"move_up", &"move_down", &"jump"]
			as Array[StringName]
		),
	)
