##
## Tests for the tab group, which builds a button per tab and shows the selected tab's
## content.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PlatformScene := preload("res://premade/platform.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")
const TabGroupScene := preload("tab_group.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_remove_tab_drops_its_button_and_content() -> void:
	# Given: A group of three tabs, the last one selected.
	var tabs := _add_tabs(["a", "b", "c"])
	tabs.select(2)

	# When: The first tab is removed.
	tabs.remove_tab(0)

	# Then: The other two labels, buttons and contents remain, in order.
	assert_eq(tabs.tabs, PackedStringArray(["b", "c"]))
	assert_eq(tabs.get_child_count(), 2)
	assert_eq(tabs.content.get_child_count(), 2)
	assert_eq(tabs.content.get_child(0).name, &"b")

	# Then: The last tab stays selected and shown.
	assert_true(tabs.content.get_child(1).visible)
	assert_false(tabs.content.get_child(0).visible)


func test_remove_tab_keeps_each_button_selecting_its_own_tab() -> void:
	# Given: A group of three tabs.
	var tabs := _add_tabs(["a", "b", "c"])

	# Given: The first tab is removed.
	tabs.remove_tab(0)

	# When: The button now last is pressed.
	var selected := []
	tabs.tab_changed.connect(selected.append)
	tabs.get_child(1).pressed.emit()

	# Then: Its own tab is selected and shown.
	assert_eq(selected, [1])
	assert_true(tabs.content.get_child(1).visible)


func test_remove_tab_selects_the_default_in_place_of_the_selected_one() -> void:
	# Given: A group of three tabs, the first one selected by default.
	var tabs := _add_tabs(["a", "b", "c"])

	# When: The selected tab is removed.
	tabs.remove_tab(0)

	# Then: The new first tab is selected and shown.
	assert_true(tabs.content.get_child(0).visible)
	assert_eq(tabs.default_tab, 0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	# Given: A platform and the input scene, which the tab buttons' focus needs.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_tabs adds a tab group labeled `labels` to the tree, each tab with a content node
## named for its label, and returns it.
func _add_tabs(labels: Array) -> Node:
	var content := VBoxContainer.new()
	for label: String in labels:
		var page := Control.new()
		page.name = label
		content.add_child(page)

	add_child_autofree(content)

	var tabs: Node = TabGroupScene.instantiate()
	tabs.tabs = PackedStringArray(labels)
	tabs.content = content
	add_child_autofree(tabs)

	return tabs
