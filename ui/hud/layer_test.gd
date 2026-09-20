##
## Unit tests for `KitHudLayer`: the plane it mounts groups on, the factory that owns
## their lifetime, and the coordinate service the elements read.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GROUP_2D := preload("group_2d.tscn")
const GROUP_3D := preload("group_3d.tscn")

const TOLERANCE := Vector2(0.001, 0.001)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _anchor: KitHudAnchor2D = null
var _container: SubViewportContainer = null
var _layer: KitHudLayer2D = null
var _map: KitMap2D = null
var _root: Control = null
var _target: Node2D = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_of_resolves_from_a_nested_element() -> void:
	# Given: A group mounted on the layer.
	var group := _layer.attach(_anchor)
	# When: A node nested inside it looks for its layer.
	var nested := Control.new()
	group.add_child(nested)
	# Then: It finds the layer it lives under.
	assert_eq(KitHudLayer.of(nested), _layer)


func test_of_returns_null_outside_a_layer() -> void:
	# Given: A node with no layer among its ancestors.
	# When: It looks for one.
	# Then: There is none, rather than an error.
	assert_null(KitHudLayer.of(_target))


func test_attach_mounts_the_group_under_the_layer() -> void:
	# Given: An anchor with a group scene.
	# When: It is attached.
	var group := _layer.attach(_anchor)
	# Then: The group is a child of the layer, and knows both of its collaborators.
	assert_not_null(group)
	assert_eq(group.get_parent(), _layer)
	assert_eq(group.anchor, _anchor)
	assert_eq(group.layer, _layer)


func test_attach_positions_the_group_at_the_projection() -> void:
	# Given: A target at world (100, 50).
	_target.global_position = Vector2(100, 50)
	var group := _layer.attach(_anchor)
	# When: A frame is processed, so the group's tracker runs.
	await wait_process_frames(1)
	# Then: The group sits at the projection, shifted by the tracker's offset.
	var expected := _map.world_to_screen(Vector2(100, 50)) + group.tracker.offset
	assert_almost_eq(group.global_position, expected, TOLERANCE)


func test_attach_wires_the_tracker_before_the_group_enters_the_tree() -> void:
	# Given: An anchor whose target is a specific node.
	# When: It is attached.
	var group := _layer.attach(_anchor)
	var tracker := group.tracker as KitWorldTracker2D
	# Then: The tracker already has both, which is what its own `_ready` asserts on.
	assert_eq(tracker.map, _map)
	assert_eq(tracker.target, _target)


func test_attach_binds_elements_before_mounting_the_group() -> void:
	# Given: An anchor with a group scene.
	# When: It is attached.
	var group := _layer.attach(_anchor)
	# Then: Its elements were bound before it entered the tree. Binding afterwards would
	# work for a runtime-spawned entity and silently leave every element null for one
	# placed in a map scene at author time, because Godot readies the UI subtree after
	# the game world.
	assert_false(group.was_bound_in_tree)


func test_attach_twice_returns_the_same_group() -> void:
	# Given: An anchor that has already been attached.
	var first := _layer.attach(_anchor)
	# When: It is attached again.
	var second := _layer.attach(_anchor)
	# Then: The same group comes back rather than a second one.
	assert_eq(first, second)
	assert_eq(_layer.get_child_count(), 1)


func test_attach_works_before_the_layer_is_ready() -> void:
	# Given: A layer that has not entered the tree, so its `_ready` has not run. An
	# entity placed in a map scene at author time attaches in exactly this window.
	var layer: KitHudLayer2D = autofree(KitHudLayer2D.new())
	layer.map = _map
	assert_false(layer.is_node_ready())
	# When: An anchor is attached.
	var group := layer.attach(_anchor)
	# Then: The group is mounted and findable.
	assert_not_null(group)
	assert_eq(layer.get_group(_anchor), group)


func test_detach_frees_the_group() -> void:
	# Given: A mounted group.
	var group := _layer.attach(_anchor)
	# When: The anchor is detached.
	_layer.detach(_anchor)
	await wait_process_frames(2)
	# Then: The group is gone and no longer tracked.
	assert_false(is_instance_valid(group))
	assert_null(_layer.get_group(_anchor))


func test_detach_of_an_unattached_anchor_is_safe() -> void:
	# Given: An anchor that was never attached.
	# When: It is detached anyway.
	_layer.detach(_anchor)
	# Then: Nothing happens, and nothing errors.
	assert_null(_layer.get_group(_anchor))


func test_get_screen_rect_matches_the_map() -> void:
	# Given: A map whose container occupies a known rect.
	# When: The layer is asked for the screen rect.
	# Then: It answers with the map's.
	assert_eq(_layer.get_screen_rect(), _map.get_screen_rect())


func test_project_world_matches_the_map() -> void:
	# Given: A world position.
	var world := Vector2(42, 84)
	# When: The layer projects it.
	# Then: It answers with the map's projection.
	assert_almost_eq(
		_layer.project_world(world), _map.world_to_screen(world), TOLERANCE
	)


func test_layer_without_a_map_warns_in_the_editor() -> void:
	# Given: A HUD layer whose map was never wired, as a botched inherited scene has.
	var layer := KitHudLayer2D.new()
	# When: The editor asks it for configuration warnings.
	var warnings: PackedStringArray = layer._get_configuration_warnings()
	# Then: It names the missing map. At runtime `project_world` answers a non-finite
	# vector and every group is wired to a null map, with nothing said about either.
	assert_true("Missing property: 'map'" in warnings)

	layer.free()


func test_attach_positions_the_group_at_the_projection_in_3d() -> void:
	# Given: A 3D map with a camera, a layer, and a target in front of the camera.
	var map: KitMap3D = partial_double(KitMap3D).new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(map)

	var container := SubViewportContainer.new()
	container.size = Vector2(640, 360)
	map.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	container.add_child(viewport)
	map.sub_viewport = viewport

	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 10)
	viewport.add_child(camera)

	var target := Node3D.new()
	target.position = Vector3(1, 0, 0)
	viewport.add_child(target)

	var ui := Control.new()
	map.add_child(ui)

	var layer := KitHudLayer3D.new()
	layer.map = map
	ui.add_child(layer)
	map.hud = layer

	var anchor := KitHudAnchor3D.new()
	anchor.group_scene = GROUP_3D
	target.add_child(anchor)

	# When: The anchor is attached and a frame is processed.
	var group := layer.attach(anchor)
	await wait_process_frames(1)

	# Then: The group sits at the 3D projection, shifted by the tracker's offset.
	var expected := map.world_to_screen(target.global_position) + group.tracker.offset
	assert_almost_eq(group.global_position, expected, TOLERANCE)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920, 1080)
	add_child_autofree(_root)

	_map = partial_double(KitMap2D).new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)
	_map.sub_viewport = _viewport

	# NOTE: A later sibling than the SubViewport, which is what `KitWorldTracker`
	# asserts on, since a tracker earlier in the tree reads a stale canvas transform.
	_ui = Control.new()
	_map.add_child(_ui)

	_layer = KitHudLayer2D.new()
	_layer.map = _map
	_ui.add_child(_layer)
	_map.hud = _layer

	_target = Node2D.new()
	_viewport.add_child(_target)

	_anchor = KitHudAnchor2D.new()
	_anchor.group_scene = GROUP_2D
	_target.add_child(_anchor)
