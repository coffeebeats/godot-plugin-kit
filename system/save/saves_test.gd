##
## Unit tests for `SystemSave`, on the scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const SystemSave := preload("saves.gd")
const SavesScene := preload("saves.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_saves_ready_with_schema_loads_module_before_slots_loaded() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The save scene with the game's schema set.
	var saves: SystemSave = SavesScene.instantiate()
	saves.schema = StdSaveData.new()

	# Given: A listener which records whether the module loaded when the slots did.
	var is_loaded_on_signal := []
	saves.slots_loaded.connect(
		func() -> void:
			is_loaded_on_signal.append(KitModule.is_loaded(SystemSave.MODULE_ID))
	)

	# When: It enters the scene tree.
	add_child_autofree(saves)

	# When: Its slots finish loading on the worker thread.
	await wait_until(saves.are_slots_loaded, 2.0)

	# Then: Its module had loaded by the time it announced the slots.
	assert_eq(is_loaded_on_signal, [true])


func test_saves_ready_without_schema_fails_module() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The save scene, which leaves the game's schema unset.
	var saves := SavesScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(saves)

	# Then: Its module failed.
	assert_false(KitModule.is_loaded(SystemSave.MODULE_ID))

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")
