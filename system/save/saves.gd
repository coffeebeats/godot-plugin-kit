##
## SystemSave is a system for saving progress to `Config` files, suitable for small-to-
## medium sized games. Multiple slots are supported, though this implementation assumes
## a fixed (though configurable) limit.
##
## NOTE: This class is *not* thread-safe; save operations should be called from the main
## thread.
##

extends KitModule

# -- SIGNALS ------------------------------------------------------------------------- #

## slot_activated is emitted when a slot is newly activated.
signal slot_activated(index: int)

## slot_deactivated is emitted when a slot was just deactivated.
signal slot_deactivated(index: int)

## slot_erased is emitted when a save slot's data was just erased.
signal slot_erased(index: int)

## slot_saved is emitted when a slot save finishes.
signal slot_saved(index: int, error: Error)

## slot_saving is emitted when a slot save begins.
signal slot_saving(index: int)

## slots_loaded is emitted once all save slots have been loaded.
signal slots_loaded

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("res://addons/std/config/config.gd")
const FilePath := preload("res://addons/std/file/path.gd")
const Signals := preload("res://addons/std/event/signal.gd")
const Profile := preload("../../platform/profile/profile.gd")
const SaveFileWriter := preload("writer.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_SAVES_SHIM := &"system/saves:shim"

## MODULE_ID identifies the save system as a `KitModule`.
const MODULE_ID := &"saves"

const CATEGORY_SLOT_DATA := &"__slots__"
const KEY_ACTIVE_SLOT := &"active"

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Saves")

## schema is a config object schema defining the game's save data. This resource will
## *not* be updated itself. Rather, it will be cloned when loading save data.
@export var schema: StdSaveData = null

@export_subgroup("Slots")

## slot_scope is the settings scope containing metadata about the player's save data.
@export var slot_scope: StdSettingsScope = null

## slot_count is the number of save slots supported by the save system.
@export var slot_count: int = 4

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active_slot: int = -1
var _logger := StdLogger.create(&"system/save")
var _save_data: StdSaveData = null
var _save_slots: Array[KitSaveSlot] = []
var _slots_ready: bool = false

@onready var _writer: SaveFileWriter = get_node(^"SaveFileWriter")

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# Slot operations


## activate_slot sets the specified slot index as active. All subsequent save operations
## will operate against this slot.
func activate_slot(index: int) -> bool:
	var logger := _logger.with({&"slot": index})
	logger.info("Activating save slot.")

	if not _slots_ready:
		assert(false, "invalid state; slots not yet loaded")
		logger.warn("Refusing to activate save slot; slots not loaded.")
		return false

	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		logger.warn(
			"Refusing to activate save slot.", {&"error": ERR_INVALID_PARAMETER}
		)
		return false

	if index >= _save_slots.size() or _save_slots[index] == null:
		assert(false, "invalid argument; index out of bounds")
		logger.warn("Refusing to activate save slot.", {&"error": ERR_BUG})
		return false

	# Don't activate an invalid save slot.
	if _save_slots[index].status == KitSaveSlot.STATUS_BROKEN:
		logger.warn("Refusing to activate save slot.", {&"error": ERR_INVALID_DATA})
		return false

	if _writer.is_worker_in_progress():
		assert(false, "invalid state; cannot change slot while worker is in progress")
		logger.warn("Refusing to change active save slot; worker in progress.")
		return false

	# No change required.
	if index == _active_slot:
		return true

	var slot_previous := _active_slot
	_active_slot = index
	_writer.slot = index
	_save_data = null

	# Only persist the active slot when there's existing save data. Empty slots will be
	# persisted after a successful save in 'store_save_data'.
	if _save_slots[index].status == KitSaveSlot.STATUS_OK:
		slot_scope.config.set_int(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT, index)

	if slot_previous != -1:
		slot_deactivated.emit(slot_previous)

	# Emit even if persisted value wasn't changed because it's still a change for this
	# system component/application.
	slot_activated.emit(index)

	return true  # gdlint:ignore=max-returns


## clear_active_slot removes the currently active save slot index. Save operations
## cannot be used without an active save slot.
func clear_active_slot() -> bool:
	if not _slots_ready:
		assert(false, "invalid state; slots not yet loaded")
		_logger.warn("Refusing to clear active slot; slots not loaded.")
		return false

	if _active_slot == -1:
		return false

	var slot := _active_slot

	var logger := _logger.with({&"slot": slot})
	logger.info("Clearing active save slot.")

	if _writer.is_worker_in_progress():
		assert(false, "invalid state; cannot change slot while worker is in progress")
		logger.warn("Refusing to change active save slot; worker in progress.")
		return false

	_active_slot = -1
	_writer.slot = -1
	_save_data = null

	slot_scope.config.erase(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT)

	slot_deactivated.emit(slot)

	return true


## erase_slot deletes all saved data for the specified index. This is a destructive
## operation, so ensure player has consented to this twice.
func erase_slot(index: int) -> bool:
	var logger := _logger.with({&"slot": index})
	logger.info("Erasing save slot.")

	if not _slots_ready:
		assert(false, "invalid state; slots not yet loaded")
		logger.warn("Refusing to erase save slot; slots not loaded.")
		return false

	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		logger.warn(
			"Refusing to activate save slot.", {&"error": ERR_INVALID_PARAMETER}
		)
		return false

	if index >= _save_slots.size() or _save_slots[index] == null:
		assert(false, "invalid argument; index out of bounds")
		logger.warn("Refusing to activate save slot.", {&"error": ERR_BUG})
		return false

	var save_slot := _save_slots[index]
	assert(save_slot is KitSaveSlot, "invalid state; missing save slot")

	if index == _active_slot:
		if not clear_active_slot():
			assert(false, "failed to clear active slot")
			return false

	logger.debug("Deleting save slot directory.")

	var err := _writer.delete_save_directory(index)
	match err:
		OK:
			save_slot.status = KitSaveSlot.STATUS_EMPTY
			if save_slot.summary != null:
				save_slot.summary.reset()

			slot_erased.emit(index)

			return true
		ERR_FILE_BAD_PATH, ERR_BUSY, _:
			logger.error("Failed to delete directory for save slot.", {&"error": err})
			return false


## get_active_save_slot returns the index of the currently active save slot. If not save
## slot is active, `-1` is returned.
func get_active_save_slot() -> int:
	return _active_slot


## get_save_slot returns metadata about the specified save slot index, including its
## status and a summary of progress, if available.
func get_save_slot(index: int) -> KitSaveSlot:
	if not _slots_ready:
		assert(false, "invalid state; slots not yet loaded")
		return null

	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		return null

	if index >= _save_slots.size():
		assert(false, "invalid state; index out of bounds")
		return null

	var save_slot := _save_slots[index]
	assert(save_slot is KitSaveSlot, "invalid state; missing save slot")

	return save_slot


## are_slots_loaded returns whether all save slots have been loaded.
func are_slots_loaded() -> bool:
	return _slots_ready


## is_saving returns whether a save operation is currently in progress.
func is_saving() -> bool:
	return _writer.is_worker_in_progress()


# Save operations


## create_new_save_data creates a new, empty instance of the save data resource.
func create_new_save_data() -> StdSaveData:
	var data: StdSaveData = schema.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	data.reset()
	return data


## clear_save_data_cache discards the in-memory cached save data for the active slot,
## forcing the next 'load_save_data' call to read from disk.
##
## NOTE: This is primarily useful for tests.
func clear_save_data_cache() -> void:
	_save_data = null


## get_save_data copies the cached save data for the active save slot into the provided
## resource. The return value denotes whether this operation succeeded; if `false` is
## returned, no cached data was found.
func get_save_data(data: StdSaveData) -> bool:
	if _writer.is_worker_in_progress() or not _save_data is StdSaveData:
		return false

	data.copy(_save_data)
	return true


## load_save_data asynchronously hydrates the provided save data resource with the
## latest data for the active save slot and returns whether this operation succeeded.
func load_save_data(data: StdSaveData) -> bool:
	if not _slots_ready:
		assert(false, "invalid state; slots not yet loaded")
		_logger.warn("Refusing to load save data; slots not loaded.")
		return false

	var index := _active_slot

	var logger := _logger.with({&"slot": index})
	logger.info("Loading save data.")

	if index < 0 or index >= _save_slots.size():
		assert(false, "invalid argument; index out of range")
		logger.warn("Refusing to load save data for invalid save slot index.")
		return false

	# TODO: Determine how and when this constraint can be relaxed. For now, this
	# requires that the caller wait for the result of each save operation.
	if _writer.is_worker_in_progress():
		assert(false, "invalid state; save operation already in progress")
		logger.warn("Refusing to load save data; save operation already in progress.")
		return false

	# If data has already been loaded, return the cached value.
	if _save_data is StdSaveData:
		data.copy(_save_data)
		return true

	var save_slot := _save_slots[index]
	assert(save_slot is KitSaveSlot, "invalid state; missing save slot")

	_save_data = create_new_save_data()

	save_slot.status = await _writer.load_save_data(_save_data)
	save_slot.summary = _save_data.summary  # Don't duplicate; '_save_data' is private.

	logger = logger.with({&"status": save_slot.status})

	match save_slot.status:
		KitSaveSlot.STATUS_OK:
			logger.info("Successfully loaded save slot.")
			data.copy(_save_data)

			return true

		KitSaveSlot.STATUS_EMPTY:
			logger.info("Found save slot is empty.")
			data.copy(_save_data)  # Copy the empty value to "reset" argument.

			return true

		KitSaveSlot.STATUS_BROKEN, KitSaveSlot.STATUS_UNKNOWN:
			logger.warn("Failed to load save; slot is broken or corrupted.")
			_save_data = null  # Clear this so that next load can retry.
			save_slot.summary = null

	return false  # gdlint:ignore=max-returns


## flush_save_data synchronously persists the provided save data to the active slot.
## Intended for shutdown paths where await is unavailable. This is a last-resort path;
## it blocks until any in-flight save completes, then writes synchronously if dirty.
func flush_save_data(data: StdSaveData) -> void:
	_writer.wait()

	if not data.is_dirty():
		return

	_writer.store_save_data_sync(data)


## store_save_data asynchronously stores the provided save data to the currently active
## save slot and returns whether this operation succeeded.
func store_save_data(data: StdSaveData) -> bool:
	assert(data is StdSaveData, "invalid argument: missing data")

	var index := _active_slot

	if not _slots_ready:
		assert(false, "invalid state; slots not yet loaded")
		_logger.warn("Refusing to store save data; slots not loaded.")
		slot_saved.emit.call_deferred(index, ERR_BUSY)
		return false

	var logger := _logger.with({&"slot": index})

	if index < 0 or index >= _save_slots.size():
		assert(false, "invalid argument; index out of range")
		logger.warn("Refusing to store save data for invalid save slot index.")
		slot_saved.emit.call_deferred(index, ERR_INVALID_PARAMETER)
		return false

	# Skip redundant writes when data hasn't changed since last save.
	if not data.is_dirty() and not data.is_critical():
		logger.debug("Skipping save; data is not dirty.")
		return true

	var save_slot := _save_slots[index]
	assert(save_slot is KitSaveSlot, "invalid state; missing save slot")

	# TODO: Determine how and when this constraint can be relaxed. For now, this
	# requires that the caller wait for the result of each save operation.
	if _writer.is_worker_in_progress():
		assert(false, "invalid state; save operation already in progress")
		logger.warn("Refusing to store save data; save operation already in progress.")
		slot_saved.emit.call_deferred(index, ERR_BUSY)
		return false

	logger.info("Storing save data.")
	slot_saving.emit(index)

	_save_data = data

	save_slot.status = await _writer.store_save_data(_save_data)
	save_slot.summary = _save_data.summary  # Don't duplicate; '_save_data' is private.

	logger = logger.with({&"status": save_slot.status})

	match save_slot.status:
		KitSaveSlot.STATUS_OK:
			logger.info("Successfully saved game.")
			slot_scope.config.set_int(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT, index)
			slot_saved.emit.call_deferred(index, OK)
			return true

		KitSaveSlot.STATUS_EMPTY:
			logger.error("Failed to save game; found save slot to be empty.")
			slot_saved.emit.call_deferred(index, ERR_DOES_NOT_EXIST)

		KitSaveSlot.STATUS_BROKEN, KitSaveSlot.STATUS_UNKNOWN:
			logger.error(
				"Failed to save game; found save slot to be broken or corrupted."
			)
			_save_data = null  # Clear this so that next load can retry.
			save_slot.summary = null
			slot_saved.emit.call_deferred(index, ERR_INVALID_DATA)

	return false


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_SAVES_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_SAVES_SHIM).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_SAVES_SHIM).remove_member(self)


func _ready() -> void:
	if not schema is StdSaveData or not slot_scope is StdSettingsScope:
		_report_failed("missing a save schema or slot scope")
		return

	_load_all_slots()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_module_id() -> StringName:
	return MODULE_ID


func _get_module_requires() -> Array[StringName]:
	return [Profile.MODULE_ID]


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _load_all_slots asynchronously loads save data for each slot. This method is
## idempotent; subsequent calls after the first completion are no-ops.
func _load_all_slots() -> void:
	if _slots_ready:
		return

	_save_slots.resize(slot_count)

	for i in slot_count:
		assert(_save_slots[i] == null, "invalid state; found dangling save file")

		var logger := _logger.with({&"slot": i})
		logger.info("Loading save data.")

		_writer.slot = i  # Update slot so '_writer' can use correct path.

		var data := create_new_save_data()

		var save_slot := KitSaveSlot.new()
		_save_slots[i] = save_slot

		save_slot.status = await _writer.load_save_data(data)
		save_slot.summary = data.summary  # Don't duplicate; 'data' is private.

		logger = logger.with({&"status": save_slot.status})

		match save_slot.status:
			KitSaveSlot.STATUS_OK:
				logger.info("Successfully loaded save slot.")

			KitSaveSlot.STATUS_EMPTY:
				logger.info("Save slot is empty.")

			KitSaveSlot.STATUS_BROKEN, KitSaveSlot.STATUS_UNKNOWN:
				logger.warn("Save slot is broken or corrupted.")
				save_slot.summary = null

	_writer.slot = -1
	_slots_ready = true

	var last_active_slot := (
		slot_scope
		. config
		. get_int(
			CATEGORY_SLOT_DATA,
			KEY_ACTIVE_SLOT,
			-1,
		)
	)

	if last_active_slot >= _save_slots.size():
		slot_scope.config.erase(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT)

	elif (
		last_active_slot > -1
		and _save_slots[last_active_slot].status == KitSaveSlot.STATUS_OK
	):
		if not activate_slot(last_active_slot):
			assert(false, "failed to activate slot")

	_report_loaded()

	slots_loaded.emit()
