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


func test_get_shown_menu_settings_applies_only_the_overrides() -> void:
	# Given: A settings system whose game hides the voice volume.
	var settings: Node = autofree(SystemSettings.new())
	settings.menu_setting_overrides[&"sound_volume_voice"] = false

	# When: The ids the settings menu shows are read.
	var shown: Array[StringName] = settings.get_shown_menu_settings()

	# Then: The voice volume is left out.
	assert_does_not_have(shown, &"sound_volume_voice")

	# Then: Every other row kit shows by default stays.
	var others := SystemSettings.MENU_SETTINGS.keys().filter(
		func(id: StringName) -> bool:
			return SystemSettings.MENU_SETTINGS[id] and id != &"sound_volume_voice"
	)
	assert_eq(shown, others)


func test_get_shown_menu_settings_true_override_shows_a_default_off_row() -> void:
	# Given: Kit leaves the hold mode row off.
	assert_false(
		SystemSettings.MENU_SETTINGS[&"accessibility_holds_mode"], "precondition"
	)

	# Given: A settings system whose game shows it.
	var settings: Node = autofree(SystemSettings.new())
	settings.menu_setting_overrides[&"accessibility_holds_mode"] = true

	# When: The ids the settings menu shows are read.
	var shown: Array[StringName] = settings.get_shown_menu_settings()

	# Then: The hold mode row is shown.
	assert_has(shown, &"accessibility_holds_mode")


func test_settings_ready_with_an_unknown_override_reports_it() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: A settings system overriding an id kit has no row for.
	var settings: Node = SystemSettings.new()
	settings.menu_setting_overrides[&"sound_volume_mastr"] = false

	# When: It enters the scene tree.
	add_child_autofree(settings)

	# Then: The unknown id is reported.
	assert_push_warning("Unknown menu setting override")

	# Then: Its module still loads, since the override changes nothing.
	assert_true(KitModule.is_loaded(SystemSettings.MODULE_ID))
