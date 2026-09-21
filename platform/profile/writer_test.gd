##
## Unit tests for `ProfileConfigWriter`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const ProfileConfigWriter := preload("writer.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_writer_get_filepath_resolves_under_profile_directory() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# Given: A writer for a file relative to the profile.
	var writer: ProfileConfigWriter = autofree(ProfileConfigWriter.new())
	writer.path = "profile://settings.dat"

	# When: Its file path is read.
	var path := writer.get_filepath()

	# Then: The file sits in the profile's own directory.
	assert_eq(path, "user://profiles/public/settings.dat")


func test_writer_get_filepath_without_profile_returns_empty() -> void:
	# Given: No profile in the scene tree.

	# Given: A writer for a file relative to the profile.
	var writer: ProfileConfigWriter = autofree(ProfileConfigWriter.new())
	writer.path = "profile://settings.dat"

	# When: Its file path is read.
	var path := writer.get_filepath()

	# Then: It has none.
	assert_eq(path, "")
