##
## Binding is a button node which allows a user to rebind an action.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Bindings := preload("res://addons/std/input/godot/binding.gd")
const Rebinder := preload("rebinder.gd")
const Screens := preload("../../../ui/menu/screens.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

@export_subgroup("Components")

## glyph is the `KitInputGlyph` node which displays the current origin binding.
@export var glyph: KitInputGlyph = null

## button is the `Button` node which, when pressed, will open the `Rebinder` panel.
@export var button: Button = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## has_user_override returns whether the input binding has a user-specified value (i.e.
## a non-default origin).
func has_user_override() -> bool:
	var active_device := KitSystems.input().get_active_device(glyph.player_id)
	if not active_device:
		return false

	return (
		Bindings
		. action_has_user_override(
			scope,
			glyph.action_set,
			glyph.action,
			active_device.device_category,
			glyph.binding_index,
		)
	)


## reset returns the input binding back to its default value.
func reset() -> void:
	var active_device := KitSystems.input().get_active_device(glyph.player_id)
	if not active_device:
		return

	(
		Bindings
		. reset_action(
			scope,
			glyph.action_set,
			glyph.action,
			active_device.device_category,
			glyph.binding_index,
		)
	)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(glyph is KitInputGlyph, "invalid state; missing node")
	assert(button is Button, "invalid state; missing node")
	assert(scope is StdSettingsScope, "invalid config; missing scope")

	Signals.connect_safe(button.pressed, _on_button_pressed)
	Signals.connect_safe(scope.config.changed, _on_bindings_changed)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_bindings_changed(category: StringName, key: StringName) -> void:
	var active_device := KitSystems.input().get_active_device(glyph.player_id)
	if not active_device:
		return

	if (
		category
		!= Bindings.get_action_set_category(
			glyph.action_set, active_device.device_category
		)
	):
		return

	if key != Bindings.get_action_key(glyph.action, glyph.binding_index):
		return

	glyph.update()


func _on_button_pressed() -> void:
	(
		Rebinder
		. start_rebinding(
			Screens.find_manager(self),
			scope,
			glyph.action_set,
			glyph.action,
			glyph.binding_index,
			glyph.player_id,
		)
	)
