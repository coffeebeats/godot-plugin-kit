##
## Unit tests for `SystemSave`, on the scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SystemSave := preload("saves.gd")
const SavesScene := preload("saves.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_saves_ready_without_schema_fails_module() -> void:
	# Given: The save scene, which leaves the game's schema unset.
	var saves := SavesScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(saves)

	# Then: Its module failed.
	assert_false(KitModule.is_loaded(SystemSave.MODULE_ID))

	# Then: The player is told.
	assert_push_error("Kit module failed to load.")
	assert_eq(KitError.drain_pending().size(), 1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	KitError.drain_pending()


func after_each() -> void:
	KitError.drain_pending()
