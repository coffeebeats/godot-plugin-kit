##
## KitHudAnchor binds one world entity to a HUD group. Add it as a child of the entity,
## point `group_scene` at a group scene, and the elements appear when the entity enters
## the tree and are freed when it leaves. Nothing else is required of the entity.
##
## View code reaches the elements through `group`, which is typed as whatever script the
## group scene's root carries:
##
##     @onready var _hud: EnemyHud = $HudAnchor2D.group
##
##     _hud.health.set_value(health, max_health)
##
## The anchor holds no placement of its own. Where the group sits, whether it clamps to
## the viewport edge and how far it is offset all belong to the `KitWorldTracker`
## authored in the group scene.
##
## Outside a map the anchor warns once and goes inert, so an entity stays runnable in a
## headless test with no map, no HUD layer and no viewport.
##
## Attach `KitHudAnchor2D` or `KitHudAnchor3D`, never this script.
##

@tool
class_name KitHudAnchor
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## group_scene is the HUD group to mount for this entity. Its root must be a
## `KitHudGroup`, which is what inheriting `group_2d.tscn` or `group_3d.tscn` gives you.
@export var group_scene: PackedScene = null

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"ui/hud")  # gdlint:ignore=class-definitions-order,max-line-length

## group is the mounted group, or `null` while the anchor is inert. It is available from
## the moment the anchor enters the tree, so an entity may read it in `_ready`.
var group: KitHudGroup = null

var _layer: KitHudLayer = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_world_position returns the tracked entity's position in world space. The concrete
## type is `Vector2` in a 2D map and `Vector3` in a 3D one.
func get_world_position() -> Variant:
	assert(false, "unimplemented; subclass must override 'get_world_position'")
	return null


## get_target returns the node the group follows: the `target` export when set, and this
## anchor's parent otherwise.
func get_target() -> Node:
	assert(false, "unimplemented; subclass must override 'get_target'")
	return null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# NOTE: Covers an entity spawned into a running map, and re-parenting an existing
	# one. An entity placed in the map scene at author time enters before the UI subtree
	# does, so its attempt here finds no mounted layer and `_ready` picks it up instead.
	_attach(false)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	if _layer:
		_layer.detach(self)
		_layer = null

	group = null


func _ready() -> void:
	# NOTE: Every `_enter_tree` in a scene runs before any `_ready`, so by now the HUD
	# layer is mounted whatever the child order was. Attaching here makes the group's
	# own `_ready` run at once, which is what lets the entity read its elements in the
	# `_ready` that follows this one.
	_attach(true)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not group_scene:
		warnings.append("Missing property: 'group_scene'")

	if not get_target():
		warnings.append("No target; set 'target' or make this a child of the entity")

	return warnings


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _attach mounts this entity's group, if it is not mounted already. `is_final` marks
## the last attempt, which is the one that reports a missing layer.
func _attach(is_final: bool) -> void:
	if Engine.is_editor_hint() or group:
		return

	assert(group_scene, "invalid config; missing 'group_scene'")
	if not group_scene:
		return

	var map := KitMap.for_node(self)
	var layer := map.hud if map else null

	# NOTE: A layer that exists but is not yet in the tree cannot ready the group it is
	# given, and an entity reading its elements would find them unresolved. Waiting for
	# the next attempt costs nothing, since both happen before the entity's own `_ready`.
	if layer and not layer.is_inside_tree():
		layer = null

	if not layer:
		if is_final:
			var context := {&"path": get_path()}
			_logger.warn("No HUD layer found; anchor disabled.", context)

		return

	_layer = layer
	group = layer.attach(self)
