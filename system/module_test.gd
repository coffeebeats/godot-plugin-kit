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

	func report_loaded() -> void:
		_report_loaded()

	func _enter_tree() -> void:
		pass

	func _get_module_id() -> StringName:
		return id

	func _get_module_requires() -> Array[StringName]:
		return requires


# -- TEST METHODS -------------------------------------------------------------------- #


func test_module_enter_tree_registers_module() -> void:
	# Given: A module which has not entered the scene tree.
	var module := ExampleModule.new()
	module.id = &"test_module_entering"

	# When: It enters the scene tree.
	add_child_autofree(module)

	# Then: It is registered and still loading.
	assert_false(KitModules.is_settled())
	assert_false(KitModules.is_loaded(&"test_module_entering"))


func test_module_report_loaded_marks_module_loaded() -> void:
	# Given: A module in the scene tree.
	var module := ExampleModule.new()
	module.id = &"test_module_loaded"
	add_child_autofree(module)

	# When: It reports that it loaded.
	module.report_loaded()

	# Then: It is loaded.
	assert_true(KitModules.is_loaded(&"test_module_loaded"))


func test_module_report_loaded_with_missing_requirement_fails_module() -> void:
	# Given: A module requiring one which never registered.
	var module := ExampleModule.new()
	module.id = &"test_module_orphan"
	module.requires = [&"test_module_absent"]
	add_child_autofree(module)

	# When: It reports that it loaded.
	module.report_loaded()

	# Then: It failed.
	assert_false(KitModules.is_loaded(&"test_module_orphan"))

	# Then: The player is told.
	assert_push_error("Kit module failed to load.")
	assert_eq(KitError.drain_pending().size(), 1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	KitError.drain_pending()


func after_each() -> void:
	KitError.drain_pending()
