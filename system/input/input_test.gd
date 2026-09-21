##
## Unit tests for `SystemInput`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SystemInput := preload("input.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_input_ready_without_cursor_fails_module() -> void:
	# Given: The input system without an implementation, which places the cursor.
	var input := SystemInput.new()

	# When: It enters the scene tree.
	add_child_autofree(input)

	# Then: Its module failed.
	assert_false(KitModule.is_loaded(SystemInput.MODULE_ID))

	# Then: The player is told.
	assert_push_error("Kit module failed to load.")
	assert_eq(KitError.drain_pending().size(), 1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	KitError.drain_pending()


func after_each() -> void:
	KitError.drain_pending()
