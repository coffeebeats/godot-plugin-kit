##
## Unit tests for `SystemSettings`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const SystemSettings := preload("settings.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_settings_ready_with_profile_loads_module() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# When: The settings system enters the scene tree.
	add_child_autofree(SystemSettings.new())

	# Then: Its module loaded.
	assert_true(KitModule.is_loaded(SystemSettings.MODULE_ID))


func test_settings_ready_without_profile_fails_module() -> void:
	# When: The settings system enters the scene tree with no profile loaded.
	add_child_autofree(SystemSettings.new())

	# Then: Its module failed.
	assert_eq(KitModule.get_status(SystemSettings.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")
