##
## Controls is a settings menu tab listing one category of device's bindings, the
## keyboard and mouse's or controllers', regardless of the active device. Beside kit's
## own menu action sets, it lists the game's, read from the `Input` system component's
## `action_sets`, so a game makes its actions rebindable without editing the tab.
##
## A controller tab also shows the controller settings, and while a controller Steam
## Input drives is connected it shows Steam's configurator in place of the bindings. A
## keyboard and mouse tab shows the mouse settings.
##

extends VBoxContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ActionSet := preload("action_set.gd")
const ActionSetScene := preload("action_set.tscn")
const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_category is the category of device whose bindings the tab lists, either
## `DEVICE_TYPE_KEYBOARD` for the keyboard and mouse or `DEVICE_TYPE_GENERIC` for
## controllers.
@export var device_category: StdInputDevice.DeviceType = DEVICE_TYPE_KEYBOARD

## scope is the settings scope in which the game's binding overrides will be stored.
@export var scope: StdSettingsScope = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# NOTE: A cached settings menu re-enters the tree with the tab already set up.
	if is_node_ready():
		return

	assert(
		device_category in [DEVICE_TYPE_KEYBOARD, DEVICE_TYPE_GENERIC],
		"invalid config; unsupported device category",
	)

	# NOTE: The other device's settings are freed before they enter the tree, so only a
	# controller tab loads Steam's configurator.
	var other := (
		^"%Keyboard" if device_category == DEVICE_TYPE_GENERIC else ^"%Controller"
	)
	get_node(other).free()

	for group in get_node(^"%ActionSets").get_children():
		if group is ActionSet:
			group.device_category = device_category


func _ready() -> void:
	_add_action_sets(KitSystems.input().action_sets)

	if device_category != DEVICE_TYPE_GENERIC:
		return

	var slot := KitSystems.input().get_input_slot()
	assert(slot is StdInputSlot, "invalid state; missing player slot")

	Signals.connect_safe(slot.device_connected, _on_device_connection_changed)
	Signals.connect_safe(slot.device_disconnected, _on_device_connection_changed)

	_update_disconnected()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action_sets lists each action set, in order, above kit's own action sets.
func _add_action_sets(action_sets: Array[StdInputActionSet]) -> void:
	assert(scope is StdSettingsScope, "invalid config; missing scope")

	var container := get_node(^"%ActionSets")
	var index := get_node(^"%MenuControls").get_index()

	for action_set in action_sets:
		var group := ActionSetScene.instantiate()
		group.action_set = action_set
		group.device_category = device_category
		group.scope = scope

		container.add_child(group)
		container.move_child(group, index)

		index += 1


## _update_disconnected shows the note asking for a controller while none is connected,
## since a controller tab's rebinds have nothing to listen to then.
func _update_disconnected() -> void:
	var slot := KitSystems.input().get_input_slot()
	get_node(^"%Disconnected").visible = not slot.get_connected_devices(false)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_device_connection_changed(_device: StdInputDevice) -> void:
	_update_disconnected()
