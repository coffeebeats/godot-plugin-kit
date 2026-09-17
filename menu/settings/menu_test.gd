##
## Tests for the settings menu, which shows a game's own tabs beside kit's.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const MenuScene := preload("menu.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_add_tabs_appends_the_game_tabs_after_kit_tabs_in_order() -> void:
	# Given: A settings menu, outside the tree since its tabs need the system scenes.
	var menu: Control = autofree(MenuScene.instantiate())
	var tab_group: Node = menu.get_node(^"%TabGroup")

	var labels: PackedStringArray = tab_group.tabs.duplicate()
	var count: int = tab_group.content.get_child_count()
	assert_eq(labels.size(), count, "kit's tab labels match its tab contents")

	# Given: Two game tabs, keyed by their labels.
	var tabs: Dictionary[String, PackedScene] = {
		"game_first": _pack_tab(&"First"),
		"game_second": _pack_tab(&"Second"),
	}

	# When: The game's tabs are added.
	menu._add_tabs(tabs)

	# Then: Both labels follow kit's, in order.
	labels.append_array(["game_first", "game_second"])
	assert_eq(tab_group.tabs, labels)

	# Then: Both contents follow kit's, in the same order as their labels.
	assert_eq(tab_group.content.get_child_count(), count + 2)
	assert_eq(tab_group.content.get_child(count).name, &"First")
	assert_eq(tab_group.content.get_child(count + 1).name, &"Second")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _pack_tab(tab_name: StringName) -> PackedScene:
	var tab := VBoxContainer.new()
	tab.name = tab_name

	var scene := PackedScene.new()
	assert_eq(scene.pack(tab), OK)

	tab.free()

	return scene
