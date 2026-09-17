##
## SaveSlots is a menu which displays save slot information and, upon selecting one,
## pops with the chosen slot's index, which the pushing screen awaits on `popped`. It
## shows one slot per `slot_count` on the `Saves` system component.
##

extends PanelContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Screens := preload("../../ui/menu/screens.gd")
const DeleteButtonScene := preload("delete_button.tscn")
const SlotButton := preload("slot_button.gd")
const SlotButtonScene := preload("slot_button.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

## confirm_delete_scene is the confirmation dialog shown before erasing a save slot.
@export var confirm_delete_scene: PackedScene

## delete_failed_scene is the error dialog shown when erasing a save slot fails.
@export var delete_failed_scene: PackedScene

# -- INITIALIZATION ------------------------------------------------------------------ #

var _confirm_delete: KitAlertDialog
var _delete_failed: KitAlertDialog

@onready var _delete_buttons: Control = %DeleteButtons
@onready var _slot_buttons: Control = %SlotButtons

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(_confirm_delete):
			_confirm_delete.free()
			_confirm_delete = null
		if is_instance_valid(_delete_failed):
			_delete_failed.free()
			_delete_failed = null


func _ready() -> void:
	_confirm_delete = confirm_delete_scene.instantiate()
	_delete_failed = delete_failed_scene.instantiate()

	var saves := KitSystems.saves()

	for slot in saves.slot_count:
		var slot_button: SlotButton = SlotButtonScene.instantiate()
		slot_button.slot = slot
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if slot == 0:
			slot_button.get_node(^"FocusHandler").use_as_anchor = true

		_slot_buttons.add_child(slot_button)
		Signals.connect_safe(slot_button.pressed, _on_slot_button_pressed.bind(slot))

		var delete_button: Button = DeleteButtonScene.instantiate()
		delete_button.disabled = (
			saves.get_save_slot(slot).status == KitSaveSlot.STATUS_EMPTY
		)

		_delete_buttons.add_child(delete_button)
		(
			Signals
			. connect_safe(
				delete_button.pressed,
				_on_delete_button_pressed.bind(delete_button, slot),
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

	var screens := Screens.find_manager(self)

	_confirm_delete.open(screens)
	var action: KitAlertDialog.Action = await _confirm_delete.closed
	if action != KitAlertDialog.Action.PRIMARY:
		return

	button.disabled = true
	if not saves.erase_slot(slot):
		_delete_failed.open(screens)
		await _delete_failed.closed
		button.disabled = false


func _on_slot_button_pressed(slot: int) -> void:
	Screens.find_manager(self).pop(slot)
