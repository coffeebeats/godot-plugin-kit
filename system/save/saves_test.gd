##
## Unit tests for `SystemSave`, on the scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("res://addons/std/config/config.gd")
const PlatformScene := preload("res://premade/platform.tscn")
const SaveFileWriter := preload("writer.gd")
const SystemSave := preload("saves.gd")
const SavesScene := preload("saves.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #


## FailingWriter is a save file writer whose writes fail with `store_error` before
## touching the disk.
class FailingWriter:
	extends SaveFileWriter

	var store_error: Error = OK

	func store_config(config: Config) -> StdThreadWorkerResult:
		if store_error != OK:
			return StdThreadWorkerResult.failed(store_error)

		return super(config)


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
	assert_eq(KitModule.get_status(SystemSave.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_saves_store_save_data_with_busy_save_file_keeps_slot() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The save scene, whose save file rejects each write as busy.
	var saves := _instantiate_failing(ERR_BUSY)

	# Given: It entered the scene tree.
	add_child_autofree(saves)

	# Given: Its slots finished loading on the worker thread.
	await wait_until(saves.are_slots_loaded, 2.0)

	# Given: The first slot is active.
	assert_true(saves.activate_slot(0))

	# Given: The slot's status and summary before the write.
	var save_slot := saves.get_save_slot(0)
	var status := save_slot.status
	var summary := save_slot.summary

	# Given: Save data with a change to store.
	var data := saves.create_new_save_data()
	data.mark_critical()

	# Given: A watch on the save system's signals.
	watch_signals(saves)

	# When: The save data is stored.
	var is_stored: bool = await saves.store_save_data(data)

	# When: The deferred signals fire.
	await wait_process_frames(1)

	# Then: The store reports failure.
	assert_false(is_stored)

	# Then: The slot's save reports the writer as busy.
	assert_signal_emitted_with_parameters(saves, "slot_saved", [0, ERR_BUSY])

	# Then: The slot keeps its status and summary.
	assert_eq(save_slot.status, status)
	assert_same(save_slot.summary, summary)

	# Then: The failure is logged.
	assert_push_error("Failed to save game; save file was busy.")


func test_saves_store_save_data_with_full_disk_keeps_slot() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: The save scene, whose save file fails each write as if the disk were full.
	var saves := _instantiate_failing(ERR_FILE_CANT_WRITE)

	# Given: It entered the scene tree.
	add_child_autofree(saves)

	# Given: Its slots finished loading on the worker thread.
	await wait_until(saves.are_slots_loaded, 2.0)

	# Given: The first slot is active.
	assert_true(saves.activate_slot(0))

	# Given: The slot's status and summary before the write.
	var save_slot := saves.get_save_slot(0)
	var status := save_slot.status
	var summary := save_slot.summary

	# Given: Save data with a change to store.
	var data := saves.create_new_save_data()
	data.mark_critical()

	# Given: A watch on the save system's signals.
	watch_signals(saves)

	# When: The save data is stored.
	var is_stored: bool = await saves.store_save_data(data)

	# When: The deferred signals fire.
	await wait_process_frames(1)

	# Then: The store reports failure.
	assert_false(is_stored)

	# Then: The slot's save reports the failed write.
	assert_signal_emitted_with_parameters(saves, "slot_saved", [0, ERR_FILE_CANT_WRITE])

	# Then: The slot keeps its status and summary.
	assert_eq(save_slot.status, status)
	assert_same(save_slot.summary, summary)

	# Then: The save file logs the full disk.
	assert_push_error("Disk full or write permission denied.")

	# Then: The failed save is logged.
	assert_push_error("Failed to save game; save file could not be written.")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _instantiate_failing returns the save scene with the game's schema set and its save
## file replaced by one whose writes fail with `error`.
func _instantiate_failing(error: Error) -> SystemSave:
	var saves: SystemSave = SavesScene.instantiate()
	saves.schema = StdSaveData.new()
	saves.schema.summary = StdSaveSummary.new()

	var original: SaveFileWriter = saves.get_node(^"SaveFileWriter")

	var writer := FailingWriter.new()
	writer.name = original.name
	writer.path = original.path
	writer.backup_count = original.backup_count
	writer.store_error = error

	saves.remove_child(original)
	original.free()
	saves.add_child(writer)

	return saves
