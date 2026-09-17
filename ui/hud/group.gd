##
## KitHudGroup is the root of a HUD group scene, the bundle of elements one entity gets.
## It is positioned by a `KitWorldTracker` authored alongside it, so every element
## inside is laid out with ordinary `Control` anchoring and containers rather than with
## per-element screen offsets.
##
## A game authors a group by inheriting `group_2d.tscn` or `group_3d.tscn` and attaching
## its own script, which extends this one to name its elements:
##
##     class_name EnemyHud
##     extends KitHudGroup
##
##     var health: KitHudBar = null
##
##     func _bind_elements() -> void:
##         health = $Rows/Health
##
## **Use `_bind_elements`, not `@onready`.** A group is mounted on the HUD layer, which
## lives in the UI subtree, and Godot readies that subtree *after* the game world. An
## entity placed in a map scene at author time therefore reaches its own `_ready` while
## the group's `@onready` members are still null. `_bind_elements` runs as soon as the
## group is instantiated, before it is mounted, so it is correct whichever way the
## entity arrived.
##
## The group is instantiated by `KitHudLayer` on behalf of a `KitHudAnchor`; nothing
## else should create one.
##

@tool
class_name KitHudGroup
extends Control

# -- CONFIGURATION ------------------------------------------------------------------- #

## tracker drives this group's screen position from the anchored entity. It is authored
## as a child in the group scene, and `KitHudLayer` supplies its `map` and `target`.
@export var tracker: KitWorldTracker = null

## hide_offscreen hides the group while the tracked entity is outside the viewport. Turn
## it off for a group meant to stay visible at the viewport edge, such as an off-screen
## indicator, which pairs with `clamped` on the tracker.
@export var hide_offscreen: bool = true:
	set(value):
		hide_offscreen = value

		# NOTE: The property is live rather than read once at `_ready`, which would
		# leave a group hidden with nothing to show it. Both directions are handled:
		# turning it off reveals a hidden group, and turning it on hides one whose
		# entity is already out of view rather than waiting for the next crossing.
		if is_node_ready():
			visible = is_target_in_view or not value

# -- INITIALIZATION ------------------------------------------------------------------ #

## anchor is the `KitHudAnchor` this group was created for. Assigned by `KitHudLayer`
## before the group enters the tree.
var anchor: KitHudAnchor = null

## layer is the `KitHudLayer` hosting this group. Assigned by `KitHudLayer` before the
## group enters the tree.
var layer: KitHudLayer = null

## is_target_in_view reports whether the tracked entity is inside the viewport. It is
## kept from the tracker's view-crossing signals, so an element such as an off-screen
## indicator can read it without tracking anything itself.
var is_target_in_view: bool = true

## was_bound_in_tree records whether this group had already been mounted when its
## elements were bound. It must be false, and there is a test that it is, since binding
## after mounting reintroduces the ordering trap `_bind_elements` exists to remove.
var was_bound_in_tree: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## of returns the `KitHudGroup` containing `node`, or `null` when it has none.
##
## NOTE: An ancestor walk rather than `owner`, which names the root of the scene a node
## was *saved* in. An element inside a sub-scene reused across several group scenes has
## that sub-scene's root as its owner, not the group, and the failure is silent.
static func of(node: Node) -> KitHudGroup:
	assert(node, "invalid argument: missing node")

	var next := node
	while next:
		var group := next as KitHudGroup
		if group:
			return group

		next = next.get_parent()

	return null


## bind_elements binds this group's elements. `KitHudLayer` calls it once, before
## mounting; nothing else should.
func bind_elements() -> void:
	was_bound_in_tree = is_inside_tree()
	_bind_elements()


## get_world_position returns the anchored entity's position in world space, for
## elements that need to freeze a point in the world. The concrete type is `Vector2` in
## a 2D map and `Vector3` in a 3D one.
func get_world_position() -> Variant:
	assert(anchor, "invalid state; missing 'anchor'")
	return anchor.get_world_position() if anchor else null


## make_world_origin returns a callable giving the screen position of the entity's world
## position *as it is now*, re-projected on every call. An element that wants to stay
## over the spot it was spawned at holds onto this rather than a screen position, so the
## camera can pan away underneath it.
##
## The callable answers a non-finite vector when the point cannot be projected, which is
## what a 3D point behind the camera does.
func make_world_origin() -> Callable:
	var world_position: Variant = get_world_position()
	var hud := layer

	if world_position == null or not hud:
		return Callable()

	return func() -> Vector2: return hud.project_world(world_position)


## project_target returns where the anchored entity is on screen right now, unclamped.
## An element that needs to point at the entity reads this rather than its own rect,
## which the tracker may already have clamped onto the viewport edge.
func project_target() -> Vector2:
	var world_position: Variant = get_world_position()
	if world_position == null or not layer:
		return Vector2.INF

	return layer.project_world(world_position)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _bind_elements is where a game's own group script names its elements. It is called by
## `KitHudLayer` the moment the group is instantiated, before it is mounted, so it holds
## whether the entity was placed at author time or spawned into a running map.
func _bind_elements() -> void:
	pass


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not tracker:
		warnings.append("Missing property: 'tracker'")

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(tracker, "invalid config; missing 'tracker'")
	if not tracker:
		return

	if hide_offscreen:
		# NOTE: Start hidden so a group whose entity spawns off-screen never flashes on
		# the first frame; the tracker reports the real state during its first `_process`.
		visible = false

	# NOTE: Connected regardless of `hide_offscreen`, and checked in the handlers, so
	# the property stays live rather than being read once here.
	tracker.target_entered_view.connect(_on_target_entered_view)
	tracker.target_exited_view.connect(_on_target_exited_view)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_target_entered_view() -> void:
	is_target_in_view = true

	if hide_offscreen:
		visible = true


func _on_target_exited_view() -> void:
	is_target_in_view = false

	if hide_offscreen:
		visible = false
