##
## SettingsMenu is a full settings menu with the ability to read and write user/game
## preferences. Designed as a standalone Control pushed via StdScreenManager.
##
## After kit's own tabs it shows the game's, read from the `Settings` system
## component's `menu_tabs`. Of kit's own rows and rebinding groups, it shows those the
## component's `get_shown_menu_settings` returns.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ActionSet := preload("controls/action_set.gd")
const Group := preload("group.gd")
const Setting := preload("setting.gd")
const Signals := preload("res://addons/std/event/signal.gd")
const TabGroup := preload("../../ui/menu/tab_group.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Feedback")

## tab_switch_sound_event is a sound event which will be played when switching tabs.
@export var tab_switch_sound_event: StdSoundEvent1D = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _tab_switch_muted: bool = false

## _tabs_left_out are the tab contents which `_ready` removes, as the game listed none
## of their rows or groups.
var _tabs_left_out: Array[Node] = []

@onready var _tab_group: TabGroup = %TabGroup

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if not is_node_ready():
		var settings := KitSystems.settings()

		# NOTE: Tabs are added before `TabGroup._ready` builds a button per label.
		_add_tabs(settings.menu_tabs)

		# NOTE: A tab is pruned after its own `_enter_tree`, where the controls tab names
		# its rebinding groups, and before its rows enter the tree.
		var shown := settings.get_shown_menu_settings()
		var tab_group: TabGroup = get_node(^"%TabGroup")
		for tab in tab_group.content.get_children():
			tab.tree_entered.connect(
				_on_tab_tree_entered.bind(tab, shown), CONNECT_ONE_SHOT
			)

		return  # First enter; _ready() handles initial state.

	# A re-entry pushes a cached instance, so reset to the default tab without its sound.
	if _tab_group.tabs.is_empty():
		return  # Every tab was removed; there is nothing to select.

	_tab_switch_muted = true
	_tab_group.select(_tab_group.default_tab)
	(func() -> void: _tab_switch_muted = false).call_deferred()


func _ready() -> void:
	assert(_tab_group is TabGroup, "invalid state; missing control node")

	for tab in _tabs_left_out:
		_tab_group.remove_tab(tab.get_index())

	_tabs_left_out.clear()

	Signals.connect_safe(_tab_group.tab_changed, _on_tab_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_next", false, true):
		_tab_group.select_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_prev", false, true):
		_tab_group.select_previous()
		get_viewport().set_input_as_handled()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_tabs appends each tab, labeled by its key, after kit's own tabs.
func _add_tabs(tabs: Dictionary[String, PackedScene]) -> void:
	var tab_group: TabGroup = get_node(^"%TabGroup")
	assert(tab_group.content is Node, "invalid state; missing tab contents")

	for label in tabs:
		tab_group.content.add_child(tabs[label].instantiate())

	tab_group.tabs = tab_group.tabs + PackedStringArray(tabs.keys())


## _anchor_first_row lands focus on the first visible row under `tab` when nothing
## there takes focus as the tab shows, as when its first row was left out.
func _anchor_first_row(tab: Node) -> void:
	var anchors := _find_anchors(tab)
	if anchors.any(_is_anchor):
		return

	# NOTE: The visible anchor with the highest priority wins, so ranking each row in
	# tree order picks the first one shown, whatever hides the rows above it.
	var group_anchored := false
	for i in anchors.size():
		var anchor := anchors[i]
		if anchor is ActionSet:
			if not group_anchored:
				anchor.anchor_first_row = true
				group_anchored = true
		else:
			anchor.use_as_anchor = true
			anchor.priority = anchors.size() - i


## _find_anchors returns, in tree order, each focus handler under `node` and each
## rebinding group, whose rows do not exist until it is ready.
func _find_anchors(node: Node) -> Array[Node]:
	var out: Array[Node] = []

	for child in node.get_children():
		if child is ActionSet:
			out.append(child)
			continue

		if child is StdInputCursorFocusHandler:
			out.append(child)

		out.append_array(_find_anchors(child))

	return out


## _get_id returns the id of `node` if it is a settings row or group, or else `&""`.
func _get_id(node: Node) -> StringName:
	return node.id if node is Group or node is Setting else &""


## _has_listable returns whether `node` holds a row or group with an id.
func _has_listable(node: Node) -> bool:
	for child in node.get_children():
		if _get_id(child) or _has_listable(child):
			return true

	return false


## _is_anchor returns whether focus lands on `node`, a result of `_find_anchors`.
func _is_anchor(node: Node) -> bool:
	return node.anchor_first_row if node is ActionSet else node.use_as_anchor


## _prune frees each row and group under `tab` whose id `shown` lacks, then any group
## left with no row. It returns false if `tab` held some with an id and none is left.
func _prune(tab: Node, shown: Array[StringName]) -> bool:
	if not _has_listable(tab):
		return true

	_prune_children(tab, shown)
	if not _has_listable(tab):
		return false

	_anchor_first_row(tab)
	return true


## _prune_children frees each row and group under `node` whose id `shown` lacks, then
## `node` itself if it is a group left with no row.
func _prune_children(node: Node, shown: Array[StringName]) -> void:
	var row_freed := false

	for child in node.get_children():
		var id := _get_id(child)
		if id and id not in shown:
			row_freed = row_freed or child is Setting
			child.free()
		else:
			_prune_children(child, shown)

	if row_freed and node is Group:
		if not node.get_children().any(func(c): return c is Setting):
			node.free()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_tab_changed(_index: int) -> void:
	if not KitSystems.input().is_cursor_visible():
		KitSystems.input().mute_next_focus_sound()

	if not _tab_switch_muted and tab_switch_sound_event:
		KitSystems.audio().play(tab_switch_sound_event)


func _on_tab_tree_entered(tab: Node, shown: Array[StringName]) -> void:
	if not _prune(tab, shown):
		_tabs_left_out.append(tab)
