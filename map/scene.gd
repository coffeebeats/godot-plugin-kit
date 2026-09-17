##
## KitMap is the base `@tool` script for game map scenes. It renders the game world
## in a `SubViewport` at a controlled resolution while UI stays at native resolution.
##
## Expected scene tree:
##
##   Scene (Control, full-rect)
##   ├── StdInputActionSetLoader  (optional)
##   ├── StdSoundEmitter          (BGM; optional)
##   ├── SubViewportContainer     (full-rect or scaled)
##   │   └── SubViewport          (export: 'sub_viewport')
##   │       └── [game world]
##   └── UI                       (Control, full-rect; optional, native resolution)
##
## NOTE: The pusher that opens the pause menu is an attachment on the map's `StdScreen`
## (`attachment_scenes`), not a node here. It mounts into the overlay, clear of
## `pause_when_covered`, and the scene stays runnable on its own.
##
## NOTE: `StdScreen.pause_when_covered` disables the entire SubViewport subtree. Per
## Godot #79665, a paused SubViewport's descendants receive no input, even with
## `process_mode = ALWAYS`.
##
## NOTE: `_exit_tree` nulls `SubViewport.world_2d` when it is shared with the main
## viewport, so an override must call `super`. See Godot #100755.
##

@tool
class_name KitMap
extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Debug := preload("../system/debug/debug.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## sub_viewport is a `SubViewport` that renders the game world at a specific resolution.
@export var sub_viewport: SubViewport = null

## hud is the map's `KitHudLayer`, the plane that mounts world-anchored HUD elements. A
## `KitHudAnchor` on an entity finds it through `KitMap.for_node`.
@export var hud: KitHudLayer = null

## feel is the map's `KitFeelLayer`, which owns camera shake, hit-stop and the screen
## flash. View code reaches it as `map.feel`, or from a world node through
## `KitMap.for_node`.
@export var feel: KitFeelLayer = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _save_data: ProjectSaveData = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	Debug.unregister(&"map", _get_debug_state)

	_save_data = null

	# NOTE: Godot #100755 - null `world_2d` to prevent crash when changing scenes while
	# a `SubViewport` shares the main viewport's `World2D`.
	if sub_viewport and sub_viewport.world_2d == get_viewport().world_2d:
		sub_viewport.world_2d = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not sub_viewport:
		warnings.append("Missing property: 'sub_viewport'")
	elif sub_viewport.get_child_count() == 0:
		warnings.append("SubViewport has no game world content")

	if not hud:
		warnings.append("Missing property: 'hud'")

	if not feel:
		warnings.append("Missing property: 'feel'")

	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# NOTE: Registered before the save data check below, so a map run on its own, with
	# no save data and no `Main`, is still inspectable.
	Debug.register(&"map", _get_debug_state)

	_save_data = Main.get_active_save_data()
	if not _save_data:
		Main.go_to_main_menu()  # TODO: Add better error handling.
		return


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## for_node returns the `KitMap` whose `SubViewport` contains `node`, or `null` when
## `node` does not live in one. This is how a node in the game world reaches the map's
## layers without a group, a singleton, or a path baked into a scene that is authored
## separately from the map it is spawned into.
##
## NOTE: A node in the main viewport - a HUD element, for instance - is not in a map's
## `SubViewport`, so this returns `null` for it. Use `KitHudLayer.of` from inside the
## HUD.
static func for_node(node: Node) -> KitMap:
	assert(node, "invalid argument: missing node")

	if not node or not node.is_inside_tree():
		return null

	var viewport := node.get_viewport()
	if not viewport:
		return null

	var next := viewport.get_parent()
	while next:
		var map := next as KitMap
		if map:
			return map

		next = next.get_parent()

	return null


## get_screen_rect returns the screen-space rect that the `SubViewport`'s contents
## occupy.
func get_screen_rect() -> Rect2:
	var container := _get_container()
	return container.get_global_rect() if container else Rect2()


## viewport_to_screen projects a `SubViewport`-local position to screen-space
## coordinates by applying any stretch-mode visual scale, then the
## `SubViewportContainer`'s global transform.
func viewport_to_screen(p: Vector2) -> Vector2:
	var container := _get_container()
	if not container:
		return p

	return container.get_global_transform() * (p * _get_visual_scale())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_debug_state reports the map's view state to the debug bridge. Every map
## inherits this, so an inherited scene answers `call map` with no wiring of its own.
func _get_debug_state() -> Dictionary:
	var out := {
		&"scene": scene_file_path,
		&"viewport": get_viewport_rect().size,
		&"screen_rect": get_screen_rect(),
	}

	if not sub_viewport:
		return out

	out[&"resolution"] = sub_viewport.size

	var world := PackedStringArray()
	for child in sub_viewport.get_children():
		world.append(String(child.name))

	out[&"world"] = world

	var camera_2d := sub_viewport.get_camera_2d()
	if camera_2d:
		out[&"camera"] = camera_2d.get_screen_center_position()

	var camera_3d := sub_viewport.get_camera_3d()
	if camera_3d:
		out[&"camera"] = camera_3d.global_position

	return out


## _get_visual_scale returns the per-axis scale factor applied between `SubViewport`-
## local pixels and `SubViewportContainer`-local pixels.
func _get_visual_scale() -> Vector2:
	var container := _get_container()

	if not container or not sub_viewport:
		return Vector2.ONE
	if not container.stretch:
		return Vector2.ONE

	if sub_viewport.size.x <= 0 or sub_viewport.size.y <= 0:
		return Vector2.ONE

	return container.size / Vector2(sub_viewport.size)


func _get_container() -> SubViewportContainer:
	return sub_viewport.get_parent() as SubViewportContainer if sub_viewport else null
