##
## Unit tests for `KitModule`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## ExampleModule is a module whose ID and requirements each test sets. It overrides
## `_enter_tree` without calling `super`, as kit's own modules do.
class ExampleModule:
	extends KitModule

	var id: StringName = &""
	var requires: Array[StringName] = []

	func _init(p_id: StringName, p_requires: Array[StringName] = []) -> void:
		id = p_id
		requires = p_requires

	func report_failed(reason: String) -> void:
		_report_failed(reason)

	func report_loaded() -> void:
		_report_loaded()

	func _enter_tree() -> void:
		pass

	func _get_module_id() -> StringName:
		return id

	func _get_module_requires() -> Array[StringName]:
		return requires


## NotifyingModule is a module whose `_notification` calls `super`, so Godot runs the
## base class's handler twice for each notification.
class NotifyingModule:
	extends ExampleModule

	func _notification(what: int) -> void:
		super._notification(what)


# -- TEST METHODS -------------------------------------------------------------------- #


func test_module_register_twice_fails_module() -> void:
	# Given: A module in the scene tree.
	_add_module(&"test_twice")

	# When: A second module enters the scene tree under the same ID.
	_add_module(&"test_twice")

	# Then: The module failed.
	assert_false(KitModule.is_loaded(&"test_twice"))

	# Then: The player is told.
	_assert_failure_reported()


func test_module_notification_calling_super_registers_once() -> void:
	# Given: A module whose `_notification` calls `super`.
	var module: NotifyingModule = autofree(NotifyingModule.new(&"test_notifying"))

	# When: It enters the scene tree.
	add_child(module)

	# When: It reports that it loaded.
	module.report_loaded()

	# Then: It loaded, rather than failing as registered twice.
	assert_true(KitModule.is_loaded(&"test_notifying"))
	assert_eq(KitError.drain_pending().size(), 0)


func test_module_reentering_tree_keeps_status() -> void:
	# Given: A module which loaded.
	var module := _add_module(&"test_reentering")
	module.report_loaded()

	# When: It leaves the scene tree.
	remove_child(module)

	# When: It re-enters the scene tree.
	add_child(module)

	# Then: It is still loaded, without failing as registered twice.
	assert_true(KitModule.is_loaded(&"test_reentering"))
	assert_eq(KitError.drain_pending().size(), 0)

	# Then: Waiting returns without error.
	assert_eq(await _wait_for_modules(), OK)


func test_module_leaving_tree_while_loading_does_not_hold_up_waiting() -> void:
	# Given: A module in the scene tree which has not reported.
	var module := _add_module(&"test_leaving")

	# When: It leaves the scene tree.
	remove_child(module)

	# Then: Waiting returns without error.
	assert_eq(await _wait_for_modules(), OK)


func test_module_freeing_forgets_module() -> void:
	# Given: A module which loaded.
	var module := ExampleModule.new(&"test_freed")
	add_child(module)
	module.report_loaded()

	# When: It is freed.
	module.free()

	# Then: It is no longer loaded.
	assert_false(KitModule.is_loaded(&"test_freed"))


func test_module_report_failed_enqueues_critical_error() -> void:
	# Given: A module in the scene tree.
	var module := _add_module(&"test_failed")

	# When: It reports that it failed to load.
	module.report_failed("a reason")

	# Then: It did not load.
	assert_false(KitModule.is_loaded(&"test_failed"))

	# Then: The player is told.
	_assert_failure_reported()


func test_module_report_failed_after_loading_is_ignored() -> void:
	# Given: A module which loaded.
	var module := _add_module(&"test_settled")
	module.report_loaded()

	# When: It then reports a failure.
	module.report_failed("a reason")

	# Then: Its first report stands.
	assert_true(KitModule.is_loaded(&"test_settled"))
	assert_eq(KitError.drain_pending().size(), 0)


func test_module_report_loaded_marks_module_loaded() -> void:
	# Given: A module in the scene tree which has not reported.
	var module := _add_module(&"test_loaded")

	# When: It reports that it loaded.
	module.report_loaded()

	# Then: It is loaded.
	assert_true(KitModule.is_loaded(&"test_loaded"))

	# Then: Nothing is enqueued.
	assert_eq(KitError.drain_pending().size(), 0)


func test_module_ready_with_failed_requirement_fails_module() -> void:
	# Given: A module which failed to load.
	var broken := _add_module(&"test_broken")
	broken.report_failed("a reason")
	assert_push_error("Kit module failed to load.")
	KitError.drain_pending()

	# When: A second module requiring it enters the scene tree.
	_add_module(&"test_dependent", [&"test_broken"])

	# Then: The dependent failed too.
	assert_false(KitModule.is_loaded(&"test_dependent"))

	# Then: The player is told.
	_assert_failure_reported()


func test_module_report_loaded_with_loaded_requirement_loads_module() -> void:
	# Given: A module which loaded.
	var base := _add_module(&"test_base")
	base.report_loaded()

	# Given: A second module requiring it.
	var upper := _add_module(&"test_upper", [&"test_base"])

	# When: The dependent reports that it loaded.
	upper.report_loaded()

	# Then: The dependent loaded.
	assert_true(KitModule.is_loaded(&"test_upper"))


func test_module_ready_with_missing_requirement_fails_module() -> void:
	# When: A module requiring one which never registered enters the scene tree.
	_add_module(&"test_orphan", [&"test_absent"])

	# Then: It failed.
	assert_false(KitModule.is_loaded(&"test_orphan"))

	# Then: The player is told.
	_assert_failure_reported()


func test_module_ready_before_requirement_loads_fails_module() -> void:
	# Given: A module in the scene tree which has not loaded yet.
	var late := _add_module(&"test_late")

	# Given: A module requiring it, which starts before the requirement loads.
	var early := _add_module(&"test_early", [&"test_late"])

	# When: The requirement loads.
	late.report_loaded()

	# When: The dependent reports that it loaded.
	early.report_loaded()

	# Then: The dependent failed, since it started without its requirement.
	assert_false(KitModule.is_loaded(&"test_early"))

	# Then: The player is told once.
	_assert_failure_reported()


func test_module_wait_returns_failed_when_a_module_failed() -> void:
	# Given: A module which failed to load.
	var module := _add_module(&"test_wait_failed")
	module.report_failed("a reason")

	# When: The caller waits for every module.
	var err: Error = await _wait_for_modules()

	# Then: Waiting reports the failure.
	assert_eq(err, FAILED)
	assert_push_error("Kit module failed to load.")


func test_module_wait_returns_once_a_loading_module_loads() -> void:
	# Given: A module which will load on the next frame.
	var module := _add_module(&"test_wait_loading")
	get_tree().process_frame.connect(module.report_loaded, CONNECT_ONE_SHOT)

	# When: The caller waits for every module.
	var err: Error = await _wait_for_modules()

	# Then: Waiting returns once the module loaded, without error.
	assert_eq(err, OK)
	assert_true(KitModule.is_loaded(&"test_wait_loading"))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	KitError.drain_pending()


func after_each() -> void:
	KitError.drain_pending()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_module adds a module with the given ID and requirements to the scene tree, and
## frees it once the test ends.
func _add_module(id: StringName, requires: Array[StringName] = []) -> ExampleModule:
	return add_child_autofree(ExampleModule.new(id, requires))


## _assert_failure_reported asserts that a module's failure was logged and enqueued as a
## single critical error.
##
## NOTE: The logged line carries no context, because the editor's logging profile hands
## `push_error` the bare message.
func _assert_failure_reported() -> void:
	assert_push_error("Kit module failed to load.")

	var errors := KitError.drain_pending()

	assert_eq(errors.size(), 1)
	assert_eq(errors[0].severity, KitError.Severity.CRITICAL)
	assert_eq(errors[0].message, "kit_error_module_failed_message")


## _wait_for_modules returns what waiting on every module returns, or `ERR_TIMEOUT` if
## waiting has not returned within a second.
func _wait_for_modules() -> Error:
	var result := [ERR_TIMEOUT]

	var waiter := func() -> void: result[0] = await KitModule.wait()
	waiter.call()

	await wait_until(func() -> bool: return result[0] != ERR_TIMEOUT, 1.0)

	return result[0]
