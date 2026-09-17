##
## SaveSlots is a menu which displays save slot information and, upon selecting one,
## proceeds to load the game scene.
##

extends PanelContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Screens := preload("../../ui/menu/screens.gd")
const SlotButton := preload("slot_button.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## confirm_delete_scene is the confirmation dialog shown before erasing a save slot.
@export var confirm_delete_scene: PackedScene

# -- INITIALIZATION ------------------------------------------------------------------ #

var _confirm_delete: KitAlertDialog

@onready var _delete_buttons: Control = %DeleteButtons
@onready var _slot_buttons: Control = %SlotButtons

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(_confirm_delete):
			_confirm_delete.free()
			_confirm_delete = null


func _ready() -> void:
	_confirm_delete = confirm_delete_scene.instantiate()

	for child in _slot_buttons.get_children():
		var button: SlotButton = child
		if not button is SlotButton:
			continue

		Signals.connect_safe(button.pressed, _on_slot_button_pressed.bind(button.slot))

	var saves := KitSystems.saves()

	for slot in _delete_buttons.get_child_count():
		var button: Button = _delete_buttons.get_child(slot)
		if not button is Button:
			continue

		var status := saves.get_save_slot(slot).status
		button.disabled = status == KitSaveSlot.STATUS_EMPTY
		(
			Signals
			. connect_safe(
				button.pressed,
				_on_delete_button_pressed.bind(button, slot),
			)
		)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_delete_button_pressed(
	button: Button,
	slot: int,
) -> void:
	var saves := KitSystems.saves()
	if saves.get_save_slot(slot).status == KitSaveSlot.STATUS_EMPTY:
		return

	_confirm_delete.open(Screens.find_manager(self))
	var action: KitAlertDialog.Action = await _confirm_delete.closed
	if action == KitAlertDialog.Action.PRIMARY:
		button.disabled = true
		if not saves.erase_slot(slot):
			var error := (
				KitError
				. new(
					"kit_error_delete_failed_title",
					"kit_error_delete_failed_message",
					KitError.Severity.ERROR,
				)
			)
			await Main.show_error(error, &"kit_alert_continue")
			button.disabled = false


func _on_slot_button_pressed(slot: int) -> void:
	Screens.find_manager(self).pop(slot)
