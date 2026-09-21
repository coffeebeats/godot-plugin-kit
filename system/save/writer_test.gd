##
## Unit tests for `SaveFileWriter`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const SaveFileWriter := preload("writer.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_writer_get_save_directory_resolves_under_profile_directory() -> void:
	# Given: A platform whose profile loaded.
	add_child_autofree(PlatformScene.instantiate())

	# When: A slot's save directory is read.
	var directory := SaveFileWriter.get_save_directory(2)

	# Then: It sits in the profile's own directory.
	assert_eq(directory, "user://profiles/public/saves/2")
