##
## Tests for when `KitPauseMenu` frees the dialogs it holds out of the tree.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_pause_menu_close_request_keeps_its_dialogs() -> void:
	# Given: A pause menu in the tree, holding its dialogs.
	var menu := _create_menu()
	var confirm_quit := menu._confirm_quit
	var confirm_return := menu._confirm_return

	# When: A close request arrives, which the game may cancel.
	menu.notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# Then: The dialogs are kept.
	assert_true(is_instance_valid(confirm_quit))
	assert_true(is_instance_valid(confirm_return))


func test_pause_menu_shutdown_frees_its_dialogs() -> void:
	# Given: A pause menu in the tree, holding its dialogs.
	var menu := _create_menu()
	var confirm_quit := menu._confirm_quit
	var confirm_return := menu._confirm_return

	# When: A shutdown is propagated.
	menu.notification(StdLifecycle.NOTIFICATION_SHUTDOWN)

	# Then: The dialogs were freed at once.
	assert_false(is_instance_valid(confirm_quit))
	assert_false(is_instance_valid(confirm_return))


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _create_menu returns a pause menu added to the tree, beside the input cursor its
## controls require, which frees both after the test.
func _create_menu() -> KitPauseMenu:
	add_child_autofree(StdInputCursor.new())

	var menu: KitPauseMenu = load("res://menu/pause/menu.tscn").instantiate()
	add_child_autofree(menu)
	return menu
