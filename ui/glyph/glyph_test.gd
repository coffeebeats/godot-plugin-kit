##
## Unit tests for `KitInputGlyph`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const GlyphScene := preload("glyph.tscn")
const PlatformScene := preload("res://premade/platform.tscn")
const SystemInputScene := preload("res://system/input/input.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_glyph_keyboard_label_fits_its_box_inside_the_glyph() -> void:
	# Given: A platform whose profile loaded, and the input scene with its slot.
	add_child_autofree(PlatformScene.instantiate())
	add_child_autofree(SystemInputScene.instantiate())

	# Given: A loaded set holding `ui_accept`, which the engine binds to keys.
	var actions := StdInputActionSet.new()
	actions.name = &"Glyphs"
	actions.actions_digital = [&"ui_accept"] as Array[StringName]
	StdInputSlot.for_player(1).load_action_set(actions)

	# Given: A keyboard glyph for `ui_accept` with no minimum size of its own.
	var glyph: KitInputGlyph = GlyphScene.instantiate()
	glyph.custom_minimum_size = Vector2.ZERO
	glyph.always_show_kbm = true
	glyph.action_set = actions
	glyph.action = &"ui_accept"

	# When: The glyph enters the tree and draws its key's label.
	add_child_autofree(glyph)
	await wait_process_frames(2)

	# Then: The glyph shows a label whose box pads it.
	assert_true(glyph.label.visible)
	var box := glyph.panel_container.get_combined_minimum_size()
	assert_gt(box.x, glyph.label.get_combined_minimum_size().x)

	# Then: The glyph is at least as large as that box.
	var size := glyph.get_combined_minimum_size()
	assert_eq(size.max(box), size)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	# NOTE: The Godot backend keeps the loaded set across slots, so leave an empty one
	# behind rather than a set whose actions a later test's input map lacks.
	var slot := StdInputSlot.for_player(1)
	if slot:
		slot.load_action_set(StdInputActionSet.new())
