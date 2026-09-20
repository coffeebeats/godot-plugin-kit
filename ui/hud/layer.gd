##
## KitHudLayer is the map's HUD plane. It is three things and nothing else:
##
##   1. A place to live. HUD elements must be `Control` nodes in the UI subtree, later
##      in the tree than the `SubViewport`, or the projection they are positioned by is
##      a frame stale.
##   2. A factory and owner. It instantiates a `KitHudGroup` for a `KitHudAnchor` and
##      frees it when that anchor leaves, so nothing outlives the entity it describes.
##   3. A coordinate service. It holds the map, so it answers `project_world` and
##      `get_screen_rect` for the elements that need them.
##
## It carries no vocabulary for game facts: no values, no text, no keys and no signal
## routing. Those belong to the elements, which a game calls directly.
##
## Attach `KitHudLayer2D` or `KitHudLayer3D`, never this script.
##
## NOTE: This node must be usable before its own `_ready`. An entity placed in a map
## scene at author time runs `_ready` before the UI subtree does, because `_ready`
## propagates bottom-up and the `SubViewport` is an earlier sibling than `UI`. All state
## here is therefore initialized at declaration.
##

@tool
class_name KitHudLayer
extends Control

# -- DEFINITIONS --------------------------------------------------------------------- #

## DEBUG_ELEMENT_DEPTH is how many levels of a group's children the debug report walks.
const DEBUG_ELEMENT_DEPTH: int = 3

# -- INITIALIZATION ------------------------------------------------------------------ #

var _groups: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## of returns the `KitHudLayer` hosting `node`, or `null` when it has none. Every
## element is a descendant of its layer, so this resolves for anything inside a group.
static func of(node: Node) -> KitHudLayer:
	assert(node, "invalid argument: missing node")

	var next := node
	while next:
		var layer := next as KitHudLayer
		if layer:
			return layer

		next = next.get_parent()

	return null


## attach instantiates `anchor`'s group scene under this layer and returns it, or
## `null` when the anchor is not configured for one. Attaching an anchor which already
## has a group returns the existing one.
func attach(anchor: KitHudAnchor) -> KitHudGroup:
	assert(anchor, "invalid argument: missing anchor")
	if not anchor:
		return null

	var key := anchor.get_instance_id()

	var existing: KitHudGroup = _groups.get(key)
	if is_instance_valid(existing):
		return existing

	var scene := anchor.group_scene
	assert(scene, "invalid config; missing 'group_scene'")
	if not scene:
		return null

	var group := scene.instantiate() as KitHudGroup
	assert(group, "invalid config; 'group_scene' root must be a 'KitHudGroup'")
	if not group:
		return null

	if not group.tracker:
		assert(false, "invalid config; group scene has no tracker")
		group.free()
		return null

	group.anchor = anchor
	group.layer = self

	# NOTE: `KitWorldTracker` asserts on both `map` and `target` in its `_ready`, so the
	# tracker must be wired before the group enters the tree.
	_configure_tracker(group.tracker, anchor)

	# NOTE: Before mounting, and deliberately not left to `@onready`. `add_child` only
	# readies a child when its parent has been readied, and this layer lives in the UI
	# subtree, which Godot readies after the game world. An entity placed in a map scene
	# at author time would otherwise reach its own `_ready` with every element still
	# null. See `KitHudGroup._bind_elements`.
	group.bind_elements()

	add_child(group)
	_groups[key] = group

	return group


## detach frees the group attached for `anchor`, if any. It is safe to call for an
## anchor which was never attached.
func detach(anchor: KitHudAnchor) -> void:
	assert(anchor, "invalid argument: missing anchor")
	if not anchor:
		return

	var key := anchor.get_instance_id()

	var group: KitHudGroup = _groups.get(key)
	_groups.erase(key)

	if is_instance_valid(group):
		group.queue_free()


## get_group returns the group attached for `anchor`, or `null` when there is none.
func get_group(anchor: KitHudAnchor) -> KitHudGroup:
	if not anchor:
		return null

	var group: KitHudGroup = _groups.get(anchor.get_instance_id())
	return group if is_instance_valid(group) else null


## get_screen_rect returns the screen-space rect the game world occupies.
func get_screen_rect() -> Rect2:
	var map := _get_map()
	return map.get_screen_rect() if map else Rect2()


## project_world projects a world-space position into screen space. `world_position` is
## a `Vector2` on a 2D layer and a `Vector3` on a 3D one; it is untyped here only
## because the two dimensions cannot share a signature.
func project_world(_world_position: Variant) -> Vector2:
	assert(false, "unimplemented; subclass must override 'project_world'")
	return Vector2.INF


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _configure_tracker wires a group's tracker to this layer's map and the anchor's
## target. Overridden by subclasses, which know both concrete types.
func _configure_tracker(_tracker: KitWorldTracker, _anchor: KitHudAnchor) -> void:
	assert(false, "unimplemented; subclass must override '_configure_tracker'")


## _get_map returns the `KitMap` this layer draws over. Overridden by subclasses to
## expose their dimension-typed `map` export.
func _get_map() -> KitMap:
	assert(false, "unimplemented; subclass must override '_get_map'")
	return null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _describe_elements lists a group's `Control` descendants with their screen rects, so
## the debug bridge reports what is actually on screen and where.
func _describe_elements(node: Node, depth: int) -> Array:
	var out := []
	if depth <= 0:
		return out

	for child in node.get_children():
		var control := child as Control
		if not control:
			continue

		var script: Script = control.get_script()
		var type := script.get_global_name() if script else StringName()

		var element := {
			&"name": String(control.name),
			&"type": String(type) if type else control.get_class(),
			&"rect": control.get_global_rect(),
			&"visible": control.is_visible_in_tree(),
			&"children": _describe_elements(control, depth - 1),
		}

		out.append(element)

	return out


## _get_debug_state reports every mounted group to the debug bridge, which answers
## what is on screen without a human looking at the window.
##
## NOTE: Nothing in a shipped build calls this; the bridge finds it by method name.
func _get_debug_state() -> Dictionary:
	var groups := []

	for key: int in _groups:
		var group: KitHudGroup = _groups[key]
		if not is_instance_valid(group):
			continue

		var anchor := group.anchor
		var is_anchored := is_instance_valid(anchor) and anchor.is_inside_tree()

		var entry := {
			&"anchor": String(anchor.get_path()) if is_anchored else "",
			&"scene": group.scene_file_path,
			&"position": group.global_position,
			&"visible": group.is_visible_in_tree(),
			&"elements": _describe_elements(group, DEBUG_ELEMENT_DEPTH),
		}

		groups.append(entry)

	return {&"screen_rect": get_screen_rect(), &"groups": groups}
