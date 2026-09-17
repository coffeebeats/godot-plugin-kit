##
## Unit tests for `KitFeelHitFlash2D`, the per-sprite flash. It is a node on the thing
## it affects rather than a method on the layer, so what is covered here is that it
## adopts its parent correctly and refuses one it cannot drive.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const FLASH_MATERIAL := preload("flash_material.tres")
const HIT_FLASH_2D := preload("hit_flash_2d.gd")
const HIT_FLASH_3D := preload("hit_flash_3d.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _config: KitFeelFlash = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_flash_adopts_the_template_material_on_a_bare_parent() -> void:
	# Given: A sprite with no material of its own.
	var sprite := Sprite2D.new()
	add_child_autofree(sprite)
	assert_null(sprite.material)
	# When: A hit flash is added under it.
	_attach(sprite)
	# Then: It is given the template's material, so a game gets a working flash with no
	# setup at all.
	assert_eq(sprite.material, FLASH_MATERIAL)


func test_flash_keeps_a_parents_own_shader() -> void:
	# Given: A sprite that already has a shader of its own.
	var sprite := Sprite2D.new()
	var own := ShaderMaterial.new()
	own.shader = FLASH_MATERIAL.shader
	sprite.material = own
	add_child_autofree(sprite)
	# When: A hit flash is added under it.
	_attach(sprite)
	# Then: Its material is left alone, since the game's shader carries the parameters.
	assert_eq(sprite.material, own)


func test_flash_drives_the_instance_parameter() -> void:
	# Given: A sprite with a hit flash.
	var sprite := Sprite2D.new()
	add_child_autofree(sprite)
	var flash := _attach(sprite)
	# When: The flash plays.
	flash.play(_config)
	await wait_process_frames(2)
	# Then: The blend is driven per instance, so flashing this sprite leaves every other
	# sprite sharing the material alone.
	var amount: float = sprite.get_instance_shader_parameter(HIT_FLASH_2D.PARAM_AMOUNT)
	assert_gt(amount, 0.0)


func test_flash_returns_to_zero_when_it_finishes() -> void:
	# Given: A sprite with a hit flash.
	var sprite := Sprite2D.new()
	add_child_autofree(sprite)
	var flash := _attach(sprite)
	# When: A short flash plays out.
	_config.duration = 0.1
	flash.play(_config)
	await wait_seconds(0.3)
	# Then: The sprite is back to its own colors.
	var amount: float = sprite.get_instance_shader_parameter(HIT_FLASH_2D.PARAM_AMOUNT)
	assert_almost_eq(amount, 0.0, 0.001)


func test_flash_disables_itself_on_a_non_shader_material() -> void:
	# Given: A sprite whose material cannot carry shader parameters.
	var sprite := Sprite2D.new()
	sprite.material = CanvasItemMaterial.new()
	add_child_autofree(sprite)
	# When: A hit flash is added and asked to play.
	var flash := _attach(sprite)
	flash.play(_config)
	await wait_process_frames(2)
	# Then: It goes quiet rather than driving a parameter nothing reads, having warned
	# once when it adopted the parent.
	assert_null(sprite.get_instance_shader_parameter(HIT_FLASH_2D.PARAM_AMOUNT))


func test_flash_disables_itself_on_a_shader_without_the_uniform() -> void:
	# Given: A sprite carrying a shader of its own that never declares `flash_amount`,
	# which is what a game gets by shading its sprites and forgetting the two lines.
	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "uniform vec4 tint : source_color = vec4(1.0);\n"
		+ "void fragment() { COLOR = texture(TEXTURE, UV) * tint; }\n"
	)

	var own := ShaderMaterial.new()
	own.shader = shader

	var sprite := Sprite2D.new()
	sprite.material = own
	add_child_autofree(sprite)

	# When: A hit flash is added and asked to play.
	var flash := _attach(sprite)
	flash.play(_config)
	await wait_process_frames(2)

	# Then: It goes quiet, having warned. Driving a parameter no shader declares would
	# otherwise succeed and flash nothing, with nothing at all to read.
	assert_eq(sprite.material, own)
	assert_null(sprite.get_instance_shader_parameter(HIT_FLASH_2D.PARAM_AMOUNT))


func test_flash_3d_gives_back_the_overlay_it_borrowed() -> void:
	# Given: A mesh already wearing an overlay of its own, such as an outline or a
	# selection highlight.
	var mesh := MeshInstance3D.new()
	var own := StandardMaterial3D.new()
	mesh.material_overlay = own
	add_child_autofree(mesh)

	var flash: Node = HIT_FLASH_3D.new()
	mesh.add_child(flash)

	# When: A short flash plays out.
	_config.duration = 0.1
	flash.play(_config)
	assert_ne(mesh.material_overlay, own)

	await wait_seconds(0.3)

	# Then: The mesh has its own overlay back, rather than the slot being cleared.
	assert_eq(mesh.material_overlay, own)


func test_flash_warns_about_a_parent_it_cannot_drive() -> void:
	# Given: A hit flash under a node that is not a canvas item. It is kept out of the
	# tree, since this is the editor-time check; at runtime the same case asserts.
	var flash: Node = HIT_FLASH_2D.new()
	var parent: Node = autofree(Node.new())
	parent.add_child(flash)
	# When: The editor asks for configuration warnings.
	var warnings: PackedStringArray = flash._get_configuration_warnings()
	# Then: It says so, since at runtime the assert is compiled out of a release build.
	assert_eq(warnings.size(), 1)
	assert_true("CanvasItem" in warnings[0])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_config = KitFeelFlash.new()
	_config.color = Color(1.0, 1.0, 1.0, 1.0)
	_config.duration = 0.4
	_config.rise = 0.5


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _attach adds a hit flash under `host` and returns it.
func _attach(host: Node) -> Node:
	var flash: Node = HIT_FLASH_2D.new()
	flash.material = FLASH_MATERIAL
	host.add_child(flash)

	return flash
