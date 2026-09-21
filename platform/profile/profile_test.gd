##
## Unit tests for `Profile`, on the scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("profile.gd")
const ProfileScene := preload("profile.tscn")
const StorefrontScene := preload("../storefront/storefront.tscn")
const UnknownProfile := preload("unknown/profile.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## EmptyProvider is a profile implementation which supplies no profile.
class EmptyProvider:
	extends "provider.gd"

	func create_user_profile() -> KitUserProfile:
		return null


# -- TEST METHODS -------------------------------------------------------------------- #


func test_profile_ready_with_implementation_loads_module() -> void:
	# Given: A storefront which loaded.
	add_child_autofree(StorefrontScene.instantiate())

	# Given: The profile scene, whose loader places the editor's implementation.
	var profile: Profile = ProfileScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(profile)

	# Then: Its module loaded.
	assert_true(KitModule.is_loaded(Profile.MODULE_ID))

	# Then: It holds the implementation's profile.
	var expected := UnknownProfile.create_default_user_profile()
	assert_eq(profile.get_user_profile().id, expected.id)


func test_profile_ready_with_every_loader_blocked_fails_module() -> void:
	# Given: A storefront which loaded.
	add_child_autofree(StorefrontScene.instantiate())

	# Given: The profile scene with every loader blocked, as by a misspelled feature.
	var profile := _instantiate_blocked()

	# When: It enters the scene tree.
	add_child_autofree(profile)

	# Then: Its module failed.
	assert_eq(KitModule.get_status(Profile.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_profile_ready_with_empty_implementation_fails_module() -> void:
	# Given: A storefront which loaded.
	add_child_autofree(StorefrontScene.instantiate())

	# Given: The profile scene with its loaders blocked.
	var profile := _instantiate_blocked()

	# Given: An implementation which supplies no profile.
	profile.add_child(EmptyProvider.new())

	# When: It enters the scene tree.
	add_child_autofree(profile)

	# Then: Its module failed without a profile.
	assert_eq(KitModule.get_status(Profile.MODULE_ID), KitModule.Status.FAILED)
	assert_null(profile.get_user_profile())

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_profile_ready_without_storefront_fails_module() -> void:
	# Given: The profile scene, with no storefront loaded before it.
	var profile := ProfileScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(profile)

	# Then: Its module failed.
	assert_eq(KitModule.get_status(Profile.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_profile_find_user_profile_returns_loaded_profile() -> void:
	# Given: A storefront which loaded.
	add_child_autofree(StorefrontScene.instantiate())

	# Given: A profile which loaded.
	var profile: Profile = add_child_autofree(ProfileScene.instantiate())

	# When: The user's profile is looked up.
	var found := Profile.find_user_profile()

	# Then: It is the loaded profile.
	assert_same(found, profile.get_user_profile())


func test_profile_find_user_profile_without_profile_returns_null() -> void:
	# Given: No profile in the scene tree.

	# When: The user's profile is looked up.
	var found := Profile.find_user_profile()

	# Then: There is none.
	assert_null(found)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _instantiate_blocked returns the profile scene with every loader blocked, so that no
## implementation is placed.
func _instantiate_blocked() -> Profile:
	var profile: Profile = ProfileScene.instantiate()

	for child in profile.get_children():
		if child is StdConditionLoader:
			child.force_block = true

	return profile
