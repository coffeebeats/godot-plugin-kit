##
## SettingsGroup is a grouping of related settings items within a menu page. A name for
## the group can be set, which will be displayed above the elements.
##

@tool
extends VBoxContainer

# -- CONFIGURATION ------------------------------------------------------------------- #

## id names this group in the `Settings` system node's `MENU_SETTINGS`, which with its
## `menu_setting_overrides` decides what the settings menu shows. Left empty, the group
## isn't filtered by id, but the menu still frees it once all its rows are dropped.
@export var id: StringName = &""

@export var label: String = "":
	set(value):
		label = value
		update_configuration_warnings()

		if _label != null:
			_label.text = value

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _label: Label = $Header/Label

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_label.text = label


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if label == "":
		out.append("Invalid config; missing label")

	return out
