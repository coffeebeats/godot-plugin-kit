##
## ActionSet is a subclass of a settings group component which creates a setting per
## action included in the specified `StdInputActionSet`.
##

@warning_ignore("MISSING_TOOL")
extends "../group.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Locales := preload("../../../locale/locales.gd")
const BindingScene := preload("binding.tscn")
const Reset := preload("reset.gd")
const ResetScene := preload("reset.tscn")
const Setting := preload("../setting.gd")
const SettingScene := preload("../setting.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Action")

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null:
	set(value):
		action_set = value

		if value is StdInputActionSet:
			label = Locales.tr_action_set(value.name)

@export_subgroup("Binding")

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

@export_subgroup("Player")

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1:
	set(value):
		player_id = value

		for node in get_children():
			if not node is Setting:
				continue

			node.get_child(1).player_id = value

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _reset: Reset = %Reset

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	# This group uses manual translation calls, so prevent auto-translation.
	auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED

	assert(action_set is StdInputActionSet, "invalid config; missing action set")
	action_set = action_set  # Trigger 'label' update.

	_reset.action_set = action_set
	_reset.player_id = player_id

	_generate_settings()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _clear_settings() -> void:
	for node in get_children():
		if not node is Setting:
			continue

		remove_child(node)
		node.queue_free()


func _generate_settings() -> void:
	if not action_set is StdInputActionSet:
		assert(Engine.is_editor_hint(), "invalid state; missing action set")
		return

	_clear_settings()

	for action in action_set.list_action_names():
		var primary := BindingScene.instantiate()
		primary.scope = scope
		primary.glyph.action = action
		primary.glyph.action_set = action_set
		primary.glyph.binding_index = StdInputDeviceActions.BINDING_INDEX_PRIMARY
		primary.glyph.player_id = player_id

		var secondary := BindingScene.instantiate()
		secondary.scope = scope
		secondary.glyph.action = action
		secondary.glyph.action_set = action_set
		secondary.glyph.binding_index = StdInputDeviceActions.BINDING_INDEX_SECONDARY
		secondary.glyph.player_id = player_id

		var reset := ResetScene.instantiate()
		reset.scope = scope
		reset.bindings.append_array([primary, secondary])

		var setting := SettingScene.instantiate()
		setting.label = Locales.tr_action(action_set.name, action)
		setting.add_child(reset)
		setting.add_child(primary)
		setting.add_child(secondary)

		add_child(setting)
