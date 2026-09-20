##
## Unit tests for `KitHudAnchor`, the node a game adds to an entity. It is the whole
## template-to-game coupling, so its discovery, its lifetime and its inert path outside
## a map are all covered here.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GROUP_2D := preload("group_2d.tscn")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _container: SubViewportContainer = null
var _layer: KitHudLayer2D = null
var _map: KitMap2D = null
var _root: Control = null
var _target: Node2D = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_anchor_attaches_its_group_on_entering_the_tree() -> void:
	# Given: An anchor configured with a group scene.
	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	# When: It is added under an entity inside the map.
	_target.add_child(anchor)
	# Then: The group is mounted on the layer already, with no frame having passed. An
	# entity reads `group` in its own `_ready`, which is later than this.
	assert_not_null(anchor.group)
	assert_eq(anchor.group.get_parent(), _layer)
	assert_eq(_layer.get_group(anchor), anchor.group)


func test_anchor_mounts_a_ready_group_for_an_author_time_entity() -> void:
	# Given: A whole map built before it enters the tree, its entity inside the
	# SubViewport and its HUD layer in a later subtree. This is the shape of a map scene
	# with enemies placed in the editor, and the child order means the world subtree is
	# made ready before the UI subtree is.
	var map: KitMap2D = partial_double(KitMap2D).new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)

	var container := SubViewportContainer.new()
	container.size = Vector2(640, 360)
	map.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	container.add_child(viewport)
	map.sub_viewport = viewport

	var target := Node2D.new()
	viewport.add_child(target)

	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	target.add_child(anchor)

	var ui := Control.new()
	map.add_child(ui)

	var layer := KitHudLayer2D.new()
	layer.map = map
	ui.add_child(layer)
	map.hud = layer

	# When: The map enters the tree in one go.
	_root.add_child(map)

	# Then: The group is not merely mounted but *ready*, so the entity reading its
	# elements in its own `_ready` finds them resolved. Attaching only on entering the
	# tree left the group unready here, and the failure was a null element rather than a
	# missing group, which is why it is worth a test of its own.
	assert_not_null(anchor.group)
	assert_true(anchor.group.is_node_ready())
	assert_eq(anchor.group.get_parent(), layer)


func test_anchor_frees_its_group_on_exiting_the_tree() -> void:
	# Given: An attached anchor.
	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	_target.add_child(anchor)
	var group := anchor.group
	# When: The entity carrying it is freed.
	_target.queue_free()
	await wait_process_frames(2)
	# Then: The group goes with it, leaving nothing behind on the layer.
	assert_false(is_instance_valid(group))
	assert_eq(_layer.get_child_count(), 0)


func test_anchor_reattaches_after_reparenting() -> void:
	# Given: An attached anchor and a second entity in the world.
	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	_target.add_child(anchor)

	var other := Node2D.new()
	other.global_position = Vector2(200, 100)
	_viewport.add_child(other)

	# When: The anchor is moved to the other entity.
	anchor.reparent(other)
	await wait_process_frames(1)

	# Then: It is attached again, now tracking the new parent.
	assert_not_null(anchor.group)
	assert_eq(_layer.get_group(anchor), anchor.group)

	var tracker := anchor.group.tracker as KitWorldTracker2D
	assert_eq(tracker.target, other)


func test_anchor_follows_its_target_export_over_its_parent() -> void:
	# Given: A marker offset from the entity.
	var marker := Node2D.new()
	_target.add_child(marker)
	# When: An anchor names it as the target.
	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	anchor.target = marker
	_target.add_child(anchor)
	# Then: The tracker follows the marker, not the anchor's parent.
	var tracker := anchor.group.tracker as KitWorldTracker2D
	assert_eq(tracker.target, marker)


func test_anchor_is_inert_outside_a_map() -> void:
	# Given: An entity that is not inside any map's SubViewport, which is what a headless
	# simulation test looks like.
	var loose := Node2D.new()
	add_child_autofree(loose)
	# When: An anchor is added to it.
	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	loose.add_child(anchor)
	# Then: It mounts nothing and the entity stays usable.
	assert_null(anchor.group)


func test_anchor_reports_its_world_position() -> void:
	# Given: An entity at a known world position.
	_target.global_position = Vector2(12, 34)
	var anchor := KitHudAnchor2D.new()
	anchor.group_scene = GROUP_2D
	_target.add_child(anchor)
	# When: The anchor is asked where its entity is.
	# Then: It answers in world space, which is what a spawned element freezes.
	assert_eq(anchor.get_world_position(), Vector2(12, 34))
	assert_eq(anchor.group.get_world_position(), Vector2(12, 34))


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

	_ui = Control.new()
	_map.add_child(_ui)

	_layer = KitHudLayer2D.new()
	_layer.map = _map
	_ui.add_child(_layer)
	_map.hud = _layer

	_target = Node2D.new()
	_viewport.add_child(_target)
