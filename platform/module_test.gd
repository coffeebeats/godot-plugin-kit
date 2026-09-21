##
## Unit tests for `KitModule`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## ExampleModule is a module whose ID and requirements each test sets, and which reports
## when the test says. It overrides `_enter_tree` without calling `super`, as kit's own
## modules do.
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

	func _is_module_async() -> bool:
		return true


## SilentModule is a module which must report by the end of its `_ready`, and never
## does.
class SilentModule:
	extends ExampleModule

	func _is_module_async() -> bool:
		return false


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
	assert_eq(KitModule.get_status(&"test_twice"), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_module_notification_calling_super_registers_once() -> void:
	# Given: A module whose `_notification` calls `super`.
	var module: NotifyingModule = autofree(NotifyingModule.new(&"test_notifying"))

	# When: It enters the scene tree.
	add_child(module)

	# When: It reports that it loaded.
	module.report_loaded()

	# Then: It loaded, rather than failing as registered twice.
	assert_true(KitModule.is_loaded(&"test_notifying"))


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


func test_module_freeing_forgets_module() -> void:
	# Given: A module which loaded.
	var module := ExampleModule.new(&"test_freed")
	add_child(module)
	module.report_loaded()

	# When: It is freed.
	module.free()

	# Then: It is no longer registered.
	assert_does_not_have(KitModule.get_module_ids(), &"test_freed")
	assert_false(KitModule.is_loaded(&"test_freed"))


func test_module_get_module_ids_returns_ids_in_registration_order() -> void:
	# Given: Two modules which entered the scene tree one after the other.
	_add_module(&"test_first")
	_add_module(&"test_second")

	# When: The registered IDs are read.
	var ids := KitModule.get_module_ids()

	# Then: Both are listed, in the order they registered.
	assert_eq(ids, [&"test_first", &"test_second"] as Array[StringName])


func test_module_get_status_while_loading_returns_loading() -> void:
	# Given: A module in the scene tree which has not reported.
	_add_module(&"test_pending")

	# When: Its status is read.
	var status := KitModule.get_status(&"test_pending")

	# Then: It is still loading.
	assert_eq(status, KitModule.Status.LOADING)


func test_module_get_status_without_module_returns_failed() -> void:
	# When: The status of an ID no module registered under is read.
	var status := KitModule.get_status(&"test_unknown")

	# Then: It reads as failed.
	assert_eq(status, KitModule.Status.FAILED)


func test_module_report_failed_logs_without_enqueuing_error() -> void:
	# Given: A module in the scene tree.
	var module := _add_module(&"test_failed")

	# When: It reports that it failed to load.
	module.report_failed("a reason")

	# Then: It failed.
	assert_eq(KitModule.get_status(&"test_failed"), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")

	# Then: Nothing reaches the player, since the game decides what a failure means.
	assert_eq(KitError.drain_pending().size(), 0)


func test_module_report_failed_after_loading_is_ignored() -> void:
	# Given: A module which loaded.
	var module := _add_module(&"test_settled")
	module.report_loaded()

	# When: It then reports a failure.
	module.report_failed("a reason")

	# Then: Its first report stands.
	assert_true(KitModule.is_loaded(&"test_settled"))
	assert_push_error_count(0)


func test_module_report_loaded_before_entering_tree_is_rejected() -> void:
	# Given: A module outside the scene tree.
	var module: ExampleModule = autofree(ExampleModule.new(&"test_early_report"))

	# When: It reports that it loaded.
	module.report_loaded()

	# When: It then enters the scene tree.
	add_child(module)

	# Then: It is still loading.
	assert_eq(KitModule.get_status(&"test_early_report"), KitModule.Status.LOADING)

	# Then: The early report is logged.
	assert_push_error("Kit module reported without registering.")


func test_module_ready_without_report_fails_module() -> void:
	# When: A module which must report from its `_ready` enters the tree and never does.
	add_child_autofree(SilentModule.new(&"test_silent"))

	# Then: It failed.
	assert_eq(KitModule.get_status(&"test_silent"), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_module_report_loaded_marks_module_loaded() -> void:
	# Given: A module in the scene tree which has not reported.
	var module := _add_module(&"test_loaded")

	# When: It reports that it loaded.
	module.report_loaded()

	# Then: It is loaded.
	assert_true(KitModule.is_loaded(&"test_loaded"))


func test_module_ready_with_failed_requirement_fails_module() -> void:
	# Given: A module which failed to load.
	var broken := _add_module(&"test_broken")
	broken.report_failed("a reason")

	# When: A second module requiring it enters the scene tree.
	_add_module(&"test_dependent", [&"test_broken"])

	# Then: The dependent failed too.
	assert_eq(KitModule.get_status(&"test_dependent"), KitModule.Status.FAILED)

	# Then: Both failures are logged.
	assert_push_error_count(2)


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
	assert_eq(KitModule.get_status(&"test_orphan"), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_module_ready_before_requirement_loads_fails_module() -> void:
	# Given: A module in the scene tree which has not loaded yet.
	var late := _add_module(&"test_late")

	# Given: A module requiring it, which starts before the requirement loads.
	var early := _add_module(&"test_early", [&"test_late"])

	# When: The requirement loads.
	late.report_loaded()

	# When: The dependent reports that it loaded.
	early.report_loaded()

	# Then: The dependent failed.
	assert_eq(KitModule.get_status(&"test_early"), KitModule.Status.FAILED)

	# Then: The failure is logged once.
	assert_push_error_count(1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	KitError.drain_pending()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_module adds a module with the given ID and requirements to the scene tree, and
## frees it once the test ends.
func _add_module(id: StringName, requires: Array[StringName] = []) -> ExampleModule:
	return add_child_autofree(ExampleModule.new(id, requires))
