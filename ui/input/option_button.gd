##
## OptionButton is a base `OptionButton` node which implements common cosmetic behavior.
##

@tool
extends OptionButton

# -- CONFIGURATION ------------------------------------------------------------------- #

## checkable controls whether the available options contain a `CheckBox` node.
@export var checkable: bool = true

## radio_checkable controls whether the available options contain a radio button node.
@export var radio_checkable: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(
		not (checkable and radio_checkable),
		"invalid state: cannot set checkable and radio_checkable",
	)

	_style_items()

	var err := get_popup().menu_changed.connect(_on_PopupMenu_menu_changed)
	assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _style_items() -> void:
	var popup_menu := get_popup()

	for i in popup_menu.get_item_count():
		var is_radio_checkable := popup_menu.is_item_radio_checkable(i)

		if radio_checkable and not is_radio_checkable:
			popup_menu.set_item_as_radio_checkable(i, radio_checkable)
		elif checkable and (not popup_menu.is_item_checkable(i) or is_radio_checkable):
			popup_menu.set_item_as_checkable(i, checkable)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_PopupMenu_menu_changed() -> void:
	_style_items()
