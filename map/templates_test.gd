##
## Tests for the three map templates as authored scenes, rather than for the script
## behind them. Nothing else in the repo instantiates a template - a game makes maps by
## inheriting one - so without this the wiring in the `.tscn` files is only ever checked
## statically, and a renamed or reordered node would surface in a game instead of here.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TEMPLATE_2D := preload("2d/scene.tscn")
const TEMPLATE_2D_PIXEL := preload("2d_pixel/scene.tscn")
const TEMPLATE_3D := preload("3d/scene.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_template_2d_wires_its_layers() -> void:
	# Given: The 2D template.
	# When: It is instantiated, as `New Inherited Scene` does.
	var map: KitMap2D = TEMPLATE_2D.instantiate()
	# Then: Every node path export resolved, and to the dimension-matched type.
	_assert_layers_are_wired(map, "KitHudLayer2D", "KitFeelLayer2D")

	map.free()


func test_template_2d_pixel_wires_its_layers() -> void:
	# Given: The pixel template, which extends the 2D one at the script level while
	# staying a standalone scene, so its wiring is a separate copy that can rot alone.
	# When: It is instantiated.
	var map: KitMapPixel2D = TEMPLATE_2D_PIXEL.instantiate()
	# Then: Every node path export resolved, and to the dimension-matched type.
	_assert_layers_are_wired(map, "KitHudLayer2D", "KitFeelLayer2D")

	map.free()


func test_template_3d_wires_its_layers() -> void:
	# Given: The 3D template.
	# When: It is instantiated.
	var map: KitMap3D = TEMPLATE_3D.instantiate()
	# Then: Every node path export resolved, and to the dimension-matched type.
	_assert_layers_are_wired(map, "KitHudLayer3D", "KitFeelLayer3D")

	map.free()


func test_templates_order_the_world_then_feel_then_the_hud() -> void:
	# Given: Each template.
	for scene: PackedScene in [TEMPLATE_2D, TEMPLATE_2D_PIXEL, TEMPLATE_3D]:
		var map: KitMap = scene.instantiate()

		var world := _branch_index(map, map.sub_viewport)
		var feel := _branch_index(map, map.feel)
		var hud := _branch_index(map, map.hud)

		# Then: The three sit in the one order the design depends on. The feel layer
		# writes the camera after the camera's own update, the HUD's trackers read the
		# canvas transform after the feel layer has written it, and the flash draws over
		# the world but under the HUD. Godot processes and draws in tree order, so
		# reordering these siblings breaks all three at once and says nothing.
		var context := "in %s" % scene.resource_path

		assert_gt(feel, world, "feel comes after the world %s" % context)
		assert_gt(hud, feel, "the HUD comes after feel %s" % context)

		map.free()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _assert_layers_are_wired checks that a template's exports resolved and that each
## layer points back at the map it was given.
func _assert_layers_are_wired(map: KitMap, hud: String, feel: String) -> void:
	assert_not_null(map.sub_viewport, "'sub_viewport' resolved")
	assert_not_null(map.hud, "'hud' resolved")
	assert_not_null(map.feel, "'feel' resolved")

	if not map.hud or not map.feel:
		return

	assert_true(map.hud.is_class("Control"), "the HUD layer is a Control")
	assert_eq(map.hud.get_script().get_global_name(), StringName(hud))
	assert_eq(map.feel.get_script().get_global_name(), StringName(feel))

	# NOTE: The map and its layers point at each other, and the two references are
	# authored separately. A template carrying one without the other loads fine and then
	# projects nothing, which is why both directions are checked.
	assert_eq(map.hud.get("map"), map, "the HUD layer points back at the map")
	assert_eq(map.feel.get("map"), map, "the feel layer points back at the map")


## _branch_index returns the index, among `map`'s own children, of the branch holding
## `node`. It answers where a nested node sits in the map's top-level order.
func _branch_index(map: Node, node: Node) -> int:
	var next := node

	while next and next.get_parent() != map:
		next = next.get_parent()

	return next.get_index() if next else -1
