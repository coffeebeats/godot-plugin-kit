##
## Unit tests for `KitMap.for_node`, the single mechanism by which a node in the
## game world reaches its map, and through it the map's layers.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _container: SubViewportContainer = null
var _map: KitMap2D = null
var _root: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_for_node_finds_the_map_from_inside_the_subviewport() -> void:
	# Given: An entity in the game world.
	var entity := Node2D.new()
	_viewport.add_child(entity)

	# When: It looks for its map.
	# Then: It finds the one whose SubViewport it lives in.
	assert_eq(KitMap.for_node(entity), _map)


func test_for_node_finds_the_map_from_a_deeply_nested_node() -> void:
	# Given: A node several levels below the world root.
	var world := Node2D.new()
	_viewport.add_child(world)

	var entity := Node2D.new()
	world.add_child(entity)

	var component := Node.new()
	entity.add_child(component)

	# When: The deepest node looks for its map.
	# Then: The walk is up the viewport's ancestors, so depth does not matter.
	assert_eq(KitMap.for_node(component), _map)


func test_for_node_returns_null_outside_a_map() -> void:
	# Given: A node in the main viewport rather than a map's SubViewport, which is what
	# an entity in a headless simulation test looks like.
	var loose := Node2D.new()
	add_child_autofree(loose)

	# When: It looks for a map.
	# Then: There is none, and it is told so rather than erroring. This is what lets a
	# `KitHudAnchor` go inert instead of failing.
	assert_null(KitMap.for_node(loose))


func test_for_node_returns_null_for_a_node_outside_the_tree() -> void:
	# Given: A node that was never added to the tree.
	var orphan: Node2D = autofree(Node2D.new())

	# When: It looks for a map.
	# Then: There is none, and no error is raised for the missing viewport.
	assert_null(KitMap.for_node(orphan))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920, 1080)
	add_child_autofree(_root)

	_map = partial_double(KitMap2D).new()
	stub(_map, "_ready").to_do_nothing()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)
	_map.sub_viewport = _viewport
