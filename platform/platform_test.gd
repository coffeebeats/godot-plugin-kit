##
## Unit tests for `Platform`, on the premade scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Platform := preload("platform.gd")
const PlatformScene := preload("res://premade/platform.tscn")
const Profile := preload("profile/profile.gd")
const Storefront := preload("storefront/storefront.gd")
const UnknownProfile := preload("profile/unknown/profile.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_platform_ready_loads_storefront_and_profile() -> void:
	# Given: The platform scene, whose loaders place the default implementations.
	var platform: Platform = PlatformScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(platform)

	# Then: Both modules loaded, the profile after the storefront it requires.
	assert_true(KitModule.is_loaded(Storefront.MODULE_ID))
	assert_true(KitModule.is_loaded(Profile.MODULE_ID))

	# Then: It hands out the implementation's profile.
	var expected := UnknownProfile.create_default_user_profile()
	assert_eq(platform.get_user_profile().id, expected.id)
