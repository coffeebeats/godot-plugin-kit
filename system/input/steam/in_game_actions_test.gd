##
## Tests for `KitSteamInGameActions` against kit's own project: the scan finds kit's
## sets, the loaded catalogues name the languages, and names resolve through `Locales`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _translations: Array[Translation] = []

# -- TEST METHODS -------------------------------------------------------------------- #


func test_generate_registers_every_action_set_in_the_project() -> void:
	# Given: A manifest with no configuration.
	var manifest := KitSteamInGameActions.new()

	# When: The manifest is generated.
	var got := manifest.generate()

	# Then: Each of kit's sets and layers is written under its block.
	assert_true(got.contains('"#set_Menu"'))
	assert_true(got.contains('"#set_Splash"'))
	assert_true(got.contains('"#layer_MenuBinding"'))
	assert_true(got.contains('"#layer_MenuOptions"'))
	assert_true(got.contains('"#layer_MenuTabbed"'))


func test_generate_writes_a_section_per_loaded_catalogue() -> void:
	# Given: A manifest with no configuration.
	var manifest := KitSteamInGameActions.new()

	# When: The manifest is generated.
	var got := manifest.generate()

	# Then: Every catalogue kit ships has a section, English and Ukrainian among them.
	var localization := got.substr(got.find('\t"localization"'))
	var sections := RegEx.create_from_string('(?m)^\t\t"([a-z]+)"$')
	var languages := PackedStringArray()
	for found in sections.search_all(localization):
		languages.append(found.get_string(1))

	assert_eq(languages.size(), _translations.size())
	assert_has(languages, "english")
	assert_has(languages, "ukrainian")


func test_generate_resolves_names_through_the_catalogues() -> void:
	# Given: A manifest with no configuration.
	var manifest := KitSteamInGameActions.new()

	# When: The manifest is generated.
	var got := manifest.generate()

	# Then: The English section names the set from the catalogue.
	assert_true(got.contains('"set_Menu"\t\t\t\t\t"Menus"'))
	assert_true(got.contains('"action_ui_accept"\t\t\t\t\t"Accept"'))

	# Then: No section falls through to the set's raw identifier.
	assert_false(got.contains('"set_Menu"\t\t\t\t\t"Menu"'))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Kit's project lists no catalogues, so the shipped ones are loaded here, as
	# a game's `locale/translations` setting loads them.
	for path in DirAccess.get_files_at("res://locale"):
		if not path.ends_with(".mo"):
			continue

		var translation: Translation = load("res://locale".path_join(path))
		TranslationServer.add_translation(translation)
		_translations.append(translation)


func after_all() -> void:
	for translation in _translations:
		TranslationServer.remove_translation(translation)

	_translations.clear()
