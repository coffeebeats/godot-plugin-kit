##
## Unit tests for `SystemInput`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const SystemInput := preload("input.gd")
const SystemInputScene := preload("input.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_ready_with_implementation_loads_module() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The input scene, whose loader places the editor's implementation.
	var input := SystemInputScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(input)

	# Then: Its module loaded.
	assert_true(KitModule.is_loaded(SystemInput.MODULE_ID))


func test_input_ready_without_cursor_fails_module() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The input system alone, without the implementation that places its cursor.
	var input := SystemInput.new()

	# When: It enters the scene tree.
	add_child_autofree(input)

	# Then: Its module failed.
	assert_eq(KitModule.get_status(SystemInput.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")
