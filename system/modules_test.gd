##
## Unit tests for `KitModules`. Each test registers modules under its own ID, since kit
## autoloads `Platform`, whose modules stay registered for the whole run.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_modules_platform_autoload_loads_storefront_and_profile() -> void:
	# Given: The autoloaded `Platform`, whose loaders placed each implementation.

	# When: Its modules are queried.
	var storefront := KitModules.is_loaded(&"storefront")
	var profile := KitModules.is_loaded(&"profile")

	# Then: Both loaded, the profile after the storefront it requires.
	assert_true(storefront)
	assert_true(profile)


func test_modules_register_twice_fails_module() -> void:
	# Given: A registered module.
	KitModules.register(add_child_autofree(Node.new()), &"test_twice")

	# When: A second node registers under the same ID.
	KitModules.register(add_child_autofree(Node.new()), &"test_twice")

	# Then: The module failed.
	assert_false(KitModules.is_loaded(&"test_twice"))
	assert_true(KitModules.is_settled())

	# Then: The player is told.
	_assert_failure_reported()


func test_modules_register_forgets_module_when_node_exits_tree() -> void:
	# Given: A registered module which has not reported.
	var node := Node.new()
	add_child(node)
	KitModules.register(node, &"test_exiting")

	# When: Its node leaves the scene tree.
	remove_child(node)
	node.free()

	# Then: Nothing is left waiting on it.
	assert_true(KitModules.is_settled())


func test_modules_report_failed_enqueues_critical_error() -> void:
	# Given: A registered module.
	KitModules.register(add_child_autofree(Node.new()), &"test_failed")

	# When: It reports that it failed to load.
	KitModules.report_failed(&"test_failed", "a reason")

	# Then: It settled without loading.
	assert_false(KitModules.is_loaded(&"test_failed"))
	assert_true(KitModules.is_settled())

	# Then: The player is told.
	_assert_failure_reported()


func test_modules_report_failed_after_loading_is_ignored() -> void:
	# Given: A module which loaded.
	KitModules.register(add_child_autofree(Node.new()), &"test_settled")
	KitModules.report_loaded(&"test_settled")

	# When: It then reports a failure.
	KitModules.report_failed(&"test_settled", "a reason")

	# Then: Its first report stands.
	assert_true(KitModules.is_loaded(&"test_settled"))
	assert_eq(KitError.drain_pending().size(), 0)


func test_modules_report_loaded_marks_module_loaded() -> void:
	# Given: A registered module.
	KitModules.register(add_child_autofree(Node.new()), &"test_loaded")

	# When: It reports that it loaded.
	KitModules.report_loaded(&"test_loaded")

	# Then: It is loaded.
	assert_true(KitModules.is_loaded(&"test_loaded"))

	# Then: Nothing is enqueued.
	assert_eq(KitError.drain_pending().size(), 0)


func test_modules_report_loaded_with_failed_requirement_fails_module() -> void:
	# Given: A module which failed to load.
	KitModules.register(add_child_autofree(Node.new()), &"test_broken")
	KitModules.report_failed(&"test_broken", "a reason")
	assert_push_error("Kit module failed to load.")
	KitError.drain_pending()

	# Given: A second module requiring it.
	KitModules.register(
		add_child_autofree(Node.new()), &"test_dependent", [&"test_broken"]
	)

	# When: The dependent reports that it loaded.
	KitModules.report_loaded(&"test_dependent")

	# Then: The dependent failed too.
	assert_false(KitModules.is_loaded(&"test_dependent"))

	# Then: The player is told.
	_assert_failure_reported()


func test_modules_report_loaded_with_loaded_requirement_loads_module() -> void:
	# Given: A module which loaded.
	KitModules.register(add_child_autofree(Node.new()), &"test_base")
	KitModules.report_loaded(&"test_base")

	# Given: A second module requiring it.
	KitModules.register(add_child_autofree(Node.new()), &"test_upper", [&"test_base"])

	# When: The dependent reports that it loaded.
	KitModules.report_loaded(&"test_upper")

	# Then: The dependent loaded.
	assert_true(KitModules.is_loaded(&"test_upper"))


func test_modules_report_loaded_with_missing_requirement_fails_module() -> void:
	# Given: A module requiring one which never registered.
	KitModules.register(
		add_child_autofree(Node.new()), &"test_orphan", [&"test_absent"]
	)

	# When: It reports that it loaded.
	KitModules.report_loaded(&"test_orphan")

	# Then: It failed.
	assert_false(KitModules.is_loaded(&"test_orphan"))

	# Then: The player is told.
	_assert_failure_reported()


func test_modules_wait_returns_failed_when_a_module_failed() -> void:
	# Given: A module which failed to load.
	KitModules.register(add_child_autofree(Node.new()), &"test_wait_failed")
	KitModules.report_failed(&"test_wait_failed", "a reason")

	# When: The caller waits for every module.
	var err: Error = await KitModules.wait()

	# Then: Waiting reports the failure.
	assert_eq(err, FAILED)
	assert_push_error("Kit module failed to load.")


func test_modules_wait_returns_once_a_loading_module_loads() -> void:
	# Given: A module which will load on the next frame.
	KitModules.register(add_child_autofree(Node.new()), &"test_wait_loading")

	get_tree().process_frame.connect(
		KitModules.report_loaded.bind(&"test_wait_loading"), CONNECT_ONE_SHOT
	)

	# When: The caller waits for every module.
	var err: Error = await KitModules.wait()

	# Then: Waiting returns once the module loaded, without error.
	assert_eq(err, OK)
	assert_true(KitModules.is_loaded(&"test_wait_loading"))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	KitError.drain_pending()


func after_each() -> void:
	KitError.drain_pending()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


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
