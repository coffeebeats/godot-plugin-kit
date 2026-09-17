##
## TabGroup is a `BoxContainer` that manages a group of tab buttons. Each tab is an
## instance of a project button with `theme_type_variation` toggled between selected
## and unselected states.
##

extends BoxContainer

# -- SIGNALS ------------------------------------------------------------------------- #

## tab_changed is emitted when the active tab changes.
signal tab_changed(index: int)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ButtonScene := preload("../input/button.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

## tabs is the list of tab labels. One button will be created per entry.
@export var tabs: PackedStringArray = []

## default_tab is the initially selected tab index.
@export var default_tab: int = 0:
	set(value):
		default_tab = clampi(value, 0, max(len(tabs) - 1, 0))

## content is an optional container whose children's visibility is toggled to match the
## selected tab.
@export var content: Node = null

@export_group("Theme")

## theme_type_selected is the theme type variation for the selected tab.
@export var theme_type_selected: StringName = &"button_tab_selected"

## theme_type_unselected is the theme type variation for unselected tabs.
@export var theme_type_unselected: StringName = &"button_tab_unselected"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _buttons: Array[Button] = []
var _current: int = -1

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## select changes the active tab to the given index.
func select(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		assert(false, "invalid argument: index out of range")
		return

	if index == _current:
		return

	var button := _buttons[index]
	if button.disabled:
		return

	var previous := _current
	_current = index

	if previous >= 0:
		_apply_variation(_buttons[previous], theme_type_unselected)

	_apply_variation(button, theme_type_selected)
	_sync_content()
	tab_changed.emit(index)


## select_next selects the next non-disabled tab, wrapping around.
func select_next() -> void:
	var next := _find_next(_current, 1)
	if next >= 0:
		select(next)


## select_previous selects the previous non-disabled tab, wrapping around.
func select_previous() -> void:
	var next := _find_next(_current, -1)
	if next >= 0:
		select(next)


## set_tab_disabled enables or disables the tab at the given index.
func set_tab_disabled(index: int, disabled: bool) -> void:
	assert(
		index >= 0 and index < _buttons.size(),
		"invalid argument: index out of range",
	)

	_buttons[index].disabled = disabled


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	for i in tabs.size():
		var button: Button = ButtonScene.instantiate()
		button.text = tabs[i]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.x = 160
		button.pressed.connect(_on_tab_pressed.bind(i))
		add_child(button)
		_buttons.append(button)
		_apply_variation(button, theme_type_unselected)

	if _buttons.size() > 0:
		_current = clampi(default_tab, 0, _buttons.size() - 1)
		_apply_variation(_buttons[_current], theme_type_selected)
		_sync_content()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply_variation(button: Button, variation: StringName) -> void:
	button.theme_type_variation = variation


func _find_next(from: int, direction: int) -> int:
	var count := _buttons.size()
	if count == 0:
		return -1

	var index := (from + direction + count) % count
	while index != from and _buttons[index].disabled:
		index = (index + direction + count) % count

	if _buttons[index].disabled:
		return -1

	return index


func _sync_content() -> void:
	if not content is Node or not content.is_inside_tree():
		return

	# NOTE: Hide non-current children first so that anchor resolution in
	# `report_focus_handler_visible` never sees two panels visible at once.
	for i in content.get_child_count():
		if i != _current:
			content.get_child(i).visible = false

	var child := content.get_child(_current)
	if not child.visible:
		child.visible = true


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_tab_pressed(index: int) -> void:
	select(index)
