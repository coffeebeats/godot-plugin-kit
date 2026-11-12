##
## Controls is a settings menu tab listing one category of device's bindings, the
## keyboard and mouse's or controllers', regardless of the active device. Beside kit's
## own menu action sets, it lists the game's, read from the `Input` system component's
## `action_sets`, so a game makes its actions rebindable without editing the tab. The
## `MenuOptions` group also writes its rebinds to the game's `menu_options_layers`.
##
## A controller tab also shows the controller settings, and while a controller Steam
## Input drives is connected it shows Steam's configurator in place of the bindings. A
## keyboard and mouse tab shows the mouse settings.
##

extends VBoxContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ActionSet := preload("action_set.gd")
const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

## _TAB_IDS name each device category's tab in the ids of its rebinding groups.
const _TAB_IDS: Dictionary[StdInputDevice.DeviceType, String] = {
	DEVICE_TYPE_GENERIC: "controller",
	DEVICE_TYPE_KEYBOARD: "keyboard_mouse",
}

# -- CONFIGURATION ------------------------------------------------------------------- #

## device_category is the category of device whose bindings the tab lists, either
## `DEVICE_TYPE_KEYBOARD` for the keyboard and mouse or `DEVICE_TYPE_GENERIC` for
## controllers.
@export var device_category: StdInputDevice.DeviceType = DEVICE_TYPE_KEYBOARD

## scope is the settings scope in which the game's binding overrides will be stored.
@export var scope: StdSettingsScope = null

## action_set_scene is the rebinding group listed per game action set. Kit's scene sets
## it.
@export var action_set_scene: PackedScene = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _slot is the player's input slot, which a controller tab watches for controllers
## connecting and disconnecting while both are in the tree.
var _slot: StdInputSlot = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# NOTE: The slot is watched on each entry, since a cached settings menu leaves the
	# tree, and its devices can change while the tab is out of it.
	if device_category == DEVICE_TYPE_GENERIC:
		var slot := KitSystems.input().get_input_slot()
		assert(slot is StdInputSlot, "invalid state; missing player slot")

		_set_slot(slot)

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

	# NOTE: The settings menu reads these ids once this returns, so it can leave out
	# a rebinding group the game hides in `menu_setting_overrides`.
	for group in get_node(^"%ActionSets").get_children():
		if group is ActionSet:
			group.device_category = device_category
			group.id = _get_bindings_id(group.action_set)

	get_node(^"%MenuOptions").linked_layers = KitSystems.input().menu_options_layers


func _exit_tree() -> void:
	# NOTE: The tab can outlive the slot once out of the tree, cached or as the game
	# quits, and a slot leaving the tree disconnects each device on its way out.
	_set_slot(null)


func _ready() -> void:
	_add_action_sets(KitSystems.input().action_sets)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_action_sets lists each action set, in order, above kit's own action sets.
func _add_action_sets(action_sets: Array[StdInputActionSet]) -> void:
	assert(scope is StdSettingsScope, "invalid config; missing scope")

	var container := get_node(^"%ActionSets")
	var index := 0

	for action_set in action_sets:
		var group := action_set_scene.instantiate()
		group.action_set = action_set
		group.device_category = device_category
		group.scope = scope

		container.add_child(group)
		container.move_child(group, index)

		index += 1


## _get_bindings_id returns the id of the rebinding group listing `action_set` in
## this tab, such as `controller_bindings_menu_options`.
func _get_bindings_id(action_set: StdInputActionSet) -> StringName:
	var tab: String = _TAB_IDS[device_category]
	return StringName("%s_bindings_%s" % [tab, action_set.name.to_snake_case()])


## _set_slot watches `slot` in place of the slot the tab watched, and shows the note
## for its controllers. A `null` slot leaves the note as it is.
func _set_slot(slot: StdInputSlot) -> void:
	if slot == _slot:
		return

	if _slot:
		_set_slot_connected(_slot, false)

	_slot = slot

	if _slot:
		_set_slot_connected(_slot, true)
		_update_disconnected()


## _set_slot_connected connects the tab to the signals of `slot` which change the note
## or end the watch, or disconnects it from them.
func _set_slot_connected(slot: StdInputSlot, connected: bool) -> void:
	for pair in [
		[slot.device_connected, _on_device_connection_changed],
		[slot.device_disconnected, _on_device_connection_changed],
		[slot.tree_exiting, _on_slot_tree_exiting],
	]:
		if connected:
			Signals.connect_safe(pair[0], pair[1])
		else:
			Signals.disconnect_safe(pair[0], pair[1])


## _update_disconnected shows the note asking for a controller while the watched slot
## has none connected, since a controller tab's rebinds have nothing to listen to then.
func _update_disconnected() -> void:
	# NOTE: This reads the watched slot, since one leaving the tree can no longer be
	# looked up by the time it disconnects its devices.
	get_node(^"%Disconnected").visible = not _slot.get_connected_devices(false)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_device_connection_changed(_device: StdInputDevice) -> void:
	_update_disconnected()


func _on_slot_tree_exiting() -> void:
	_set_slot(null)
