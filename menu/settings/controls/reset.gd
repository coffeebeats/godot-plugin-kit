##
## Reset is a button node which resets the bindings for an action.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Bindings := preload("res://addons/std/input/godot/binding.gd")
const Binding := preload("binding.gd")
const Rebinder := preload("rebinder.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

@export_subgroup("Action set")

## action_set specifies an action set to reset *all* bindings for.
##
## NOTE: Only one of `action_set` and `bindings` may be specified.
@export var action_set: StdInputActionSet = null

## device_category is the category of device whose bindings in `action_set` are reset,
## either `DEVICE_TYPE_KEYBOARD` for the keyboard and mouse or `DEVICE_TYPE_GENERIC` for
## controllers.
##
## NOTE: This property is only used if `action_set` is specified; each of `bindings`
## resets its own device's binding.
@export var device_category: StdInputDevice.DeviceType = DEVICE_TYPE_KEYBOARD

## linked_layers are layers over other sets which declare some of `action_set`'s
## actions. A reset also returns those actions' bindings in each of them to their
## defaults.
##
## NOTE: This property is only used if `action_set` is specified.
@export var linked_layers: Array[StdInputActionSetLayer] = []

@export_subgroup("Bindings ")

## bindings is a list of `Binding`-typed nodes which this `Reset` node will apply to.
##
## NOTE: Only one of `action_set` and `bindings` may be specified.
@export var bindings: Array[Binding] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_update_handled: bool = false
var _prefix_category: StringName = &""
var _prefix_key: StringName = &""

@onready var _button: Button = get_node("Prompt")
@onready var _icon: TextureRect = get_node("CenterContainer/TextureRect")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(scope is StdSettingsScope, "invalid config; missing scope")
	assert(
		(action_set is StdInputActionSet and not bindings) or not action_set,
		"invalid config; can only specify one of `action_set` and `bindings`"
	)

	Signals.connect_safe(_button.pressed, _on_pressed)
	Signals.connect_safe(scope.config.changed, _on_config_changed)

	custom_minimum_size = custom_minimum_size.max(_icon.get_combined_minimum_size())

	for binding in bindings:
		assert(binding is Binding, "invalid state; missing binding")
		assert(binding.glyph is KitInputGlyph, "invalid state; missing glyph")
		assert(binding.glyph.action, "invalid state; missing action")
		assert(
			binding.glyph.action_set is StdInputActionSet,
			"invalid state; missing action set",
		)

		assert(
			(
				not _prefix_category
				or binding.glyph.action_set.name + "/" == _prefix_category
			),
			"invalid config; conflicting binding",
		)
		_prefix_category = binding.glyph.action_set.name + "/"

		assert(
			not _prefix_key or binding.glyph.action + "/" == _prefix_key,
			"invalid config; conflicting binding",
		)
		_prefix_key = binding.glyph.action + "/"

	# Defer this call so parent nodes can set properties on this one.
	call_deferred(&"_update_visibility")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _reset_linked_layers returns the bindings of `action_set`'s actions in each of
## `linked_layers` to their defaults, leaving the layers' other actions alone.
func _reset_linked_layers() -> void:
	for layer in linked_layers:
		var actions := layer.list_action_names()

		for action in action_set.list_action_names():
			if action not in actions or action in action_set.actions_analog_2d:
				continue

			for index in StdInputDeviceActions.BindingIndex.values():
				Bindings.reset_action(scope, layer, action, device_category, index)


func _update_visibility() -> void:
	if action_set is StdInputActionSet:
		visible = Bindings.category_has_user_override(
			scope, action_set, device_category
		)

		return

	for binding in bindings:
		if binding.has_user_override():
			visible = true
			return

	visible = false


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_config_changed(category: StringName, key: StringName) -> void:
	if not category.begins_with(_prefix_category) or not key.begins_with(_prefix_key):
		return

	if not _is_update_handled:
		_update_visibility()


func _on_pressed() -> void:
	var next_focus: Control = null

	if action_set is StdInputActionSet:
		assert(not _is_update_handled, "invalid state; already handling update")
		_is_update_handled = true

		Bindings.reset_all_actions(scope, action_set, device_category)
		_reset_linked_layers()

		next_focus = find_valid_focus_neighbor(SIDE_BOTTOM)
	else:
		assert(not _is_update_handled, "invalid state; already handling update")
		_is_update_handled = true

		for binding in bindings:
			binding.reset()

		next_focus = find_valid_focus_neighbor(SIDE_RIGHT)

	_is_update_handled = false

	# A new focus target is required if using focus-based navigation. If the
	# reset button was clicked, then this doesn't matter.
	if not next_focus is Control and not KitSystems.input().is_cursor_visible():
		assert(false, "invalid state; missing target focus")
		return

	if next_focus:
		next_focus.grab_focus()

	_update_visibility()
