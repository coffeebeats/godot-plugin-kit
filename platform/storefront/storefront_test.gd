##
## Unit tests for `Storefront`, on the scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Provider := preload("provider.gd")
const Storefront := preload("storefront.gd")
const StorefrontScene := preload("storefront.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_storefront_ready_with_implementation_loads_module() -> void:
	# Given: The storefront scene, whose loader places the editor's implementation.
	var storefront := StorefrontScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(storefront)

	# Then: Its module loaded.
	assert_true(KitModule.is_loaded(Storefront.MODULE_ID))


func test_storefront_ready_with_every_loader_blocked_fails_module() -> void:
	# Given: The storefront scene with every loader blocked, as by a misspelled feature.
	var storefront := _instantiate_blocked()

	# When: It enters the scene tree.
	add_child_autofree(storefront)

	# Then: Its module failed.
	assert_eq(KitModule.get_status(Storefront.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_storefront_ready_with_unscripted_implementation_fails_module() -> void:
	# Given: The storefront scene with its loaders blocked.
	var storefront := _instantiate_blocked()

	# Given: An implementation whose script failed to load, which leaves a bare node.
	storefront.add_child(Node.new())

	# When: It enters the scene tree.
	add_child_autofree(storefront)

	# Then: Its module failed.
	assert_eq(KitModule.get_status(Storefront.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


func test_storefront_ready_with_two_implementations_fails_module() -> void:
	# Given: The storefront scene, whose loader places the editor's implementation.
	var storefront := StorefrontScene.instantiate()

	# Given: A second implementation, as when a build sets two storefront features.
	storefront.add_child(Provider.new())

	# When: It enters the scene tree.
	add_child_autofree(storefront)

	# Then: Its module failed.
	assert_eq(KitModule.get_status(Storefront.MODULE_ID), KitModule.Status.FAILED)

	# Then: The failure is logged.
	assert_push_error("Kit module failed to load.")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _instantiate_blocked returns the storefront scene with every loader blocked, so that
## no implementation is placed.
func _instantiate_blocked() -> Storefront:
	var storefront: Storefront = StorefrontScene.instantiate()

	for child in storefront.get_children():
		if child is StdConditionLoader:
			child.force_block = true

	return storefront
