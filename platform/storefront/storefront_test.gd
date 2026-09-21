##
## Unit tests for `Storefront`, on the scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

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
	assert_false(KitModule.is_loaded(Storefront.MODULE_ID))

	# Then: The player is told.
	assert_push_error("Kit module failed to load.")
	assert_eq(KitError.drain_pending().size(), 1)


func test_storefront_ready_with_unscripted_implementation_fails_module() -> void:
	# Given: The storefront scene with its loaders blocked.
	var storefront := _instantiate_blocked()

	# Given: An implementation whose script failed to load, which leaves a bare node.
	storefront.add_child(Node.new())

	# When: It enters the scene tree.
	add_child_autofree(storefront)

	# Then: Its module failed.
	assert_false(KitModule.is_loaded(Storefront.MODULE_ID))

	# Then: The player is told.
	assert_push_error("Kit module failed to load.")
	assert_eq(KitError.drain_pending().size(), 1)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	KitError.drain_pending()


func after_each() -> void:
	KitError.drain_pending()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _instantiate_blocked returns the storefront scene with every loader blocked, so that
## no implementation is placed.
func _instantiate_blocked() -> Storefront:
	var storefront: Storefront = StorefrontScene.instantiate()

	for child in storefront.get_children():
		if child is StdConditionLoader:
			child.force_block = true

	return storefront
