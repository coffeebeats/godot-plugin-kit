# gdlint:ignore=max-public-methods

##
## Unit tests for the `KitTooltip` UI popover, covering anchor resolution, face
## positioning, on-screen clamping, anchor and content repositioning, and the show/hide
## lifecycle.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

## ANCHOR_RECT is the global rect of the anchor `Control` built for each test.
const ANCHOR_RECT := Rect2(500.0, 400.0, 100.0, 80.0)

## TOOLTIP_SIZE is the fixed size given to the tooltip so positioning is deterministic.
const TOOLTIP_SIZE := Vector2(200.0, 60.0)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _root: Control = null
var _anchor: Control = null
var _tooltip: KitTooltip = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_anchor_export_overrides_parent() -> void:
	# Given: A tooltip whose `anchor` is an explicit region, parented elsewhere.
	var explicit := _add_region(Rect2(900.0, 100.0, 120.0, 90.0))
	var tooltip := _build_tooltip(_root, explicit)

	# When: It is shown CENTERED.
	tooltip.tooltip_position = KitTooltip.TOOLTIP_POSITION_CENTERED
	tooltip.show_tooltip()

	# Then: It centers on the explicit anchor, not on its parent node.
	assert_eq(tooltip.global_position, Vector2(860.0, 115.0))


func test_position_above_sits_above_anchor() -> void:
	# Given/When: A tooltip is shown anchored to the ABOVE face.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_ABOVE)

	# Then: Its bottom edge meets the anchor's top, horizontally centered.
	assert_eq(pos, Vector2(450.0, 340.0))


func test_position_below_sits_below_anchor() -> void:
	# Given/When: A tooltip is shown anchored to the BELOW face.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_BELOW)

	# Then: Its top edge meets the anchor's bottom, horizontally centered.
	assert_eq(pos, Vector2(450.0, 480.0))


func test_position_left_sits_left_of_anchor() -> void:
	# Given/When: A tooltip is shown anchored to the LEFT face.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_LEFT)

	# Then: Its right edge meets the anchor's left, vertically centered.
	assert_eq(pos, Vector2(300.0, 410.0))


func test_position_right_sits_right_of_anchor() -> void:
	# Given/When: A tooltip is shown anchored to the RIGHT face.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_RIGHT)

	# Then: Its left edge meets the anchor's right, vertically centered.
	assert_eq(pos, Vector2(600.0, 410.0))


func test_position_centered_centers_on_anchor() -> void:
	# Given/When: A tooltip is shown anchored CENTERED.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_CENTERED)

	# Then: The tooltip's center coincides with the anchor's center.
	assert_eq(pos, Vector2(450.0, 410.0))


func test_tooltip_offset_shifts_the_position() -> void:
	# Given: A non-zero `tooltip_offset`.
	_tooltip.tooltip_offset = Vector2(15.0, -25.0)

	# When: The tooltip is shown anchored ABOVE.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_ABOVE)

	# Then: The face position is shifted by the offset.
	assert_eq(pos, Vector2(450.0, 340.0) + Vector2(15.0, -25.0))


func test_clamp_keeps_tooltip_inside_region() -> void:
	# Given: A clamp region the anchored tooltip would overflow.
	_tooltip.clamp_within = _add_region(Rect2(0.0, 0.0, 600.0, 500.0))

	# When: The tooltip is shown anchored BELOW (its rect overflows the region).
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_BELOW)

	# Then: It is pushed back so its rect stays inside the region.
	assert_eq(pos, Vector2(400.0, 440.0))


func test_clamp_margin_insets_the_region() -> void:
	# Given: A clamp region with a 20px margin.
	_tooltip.clamp_within = _add_region(Rect2(0.0, 0.0, 600.0, 500.0))
	_tooltip.clamp_margin = 20.0

	# When: The tooltip is shown anchored BELOW.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_BELOW)

	# Then: The tooltip is kept `clamp_margin` pixels from the region's edge.
	assert_eq(pos, Vector2(380.0, 420.0))


func test_clamp_pins_oversized_tooltip_to_region_origin() -> void:
	# Given: A tooltip larger than its clamp region.
	_tooltip.size = Vector2(800.0, 600.0)
	_tooltip.clamp_within = _add_region(Rect2(100.0, 100.0, 400.0, 300.0))

	# When: The tooltip is shown.
	var pos := _show_with_position(KitTooltip.TOOLTIP_POSITION_CENTERED)

	# Then: It pins to the region's top-left rather than inverting the clamp.
	assert_eq(pos, Vector2(100.0, 100.0))


func test_clamp_falls_back_to_viewport_when_region_unset() -> void:
	# Given: No clamp region, and an anchor far outside the viewport.
	_tooltip.clamp_within = null
	_anchor.position = Vector2(50000.0, 50000.0)

	# When: The tooltip is shown.
	_tooltip.show_tooltip()

	# Then: It is clamped to the viewport rather than rendered off-screen.
	var viewport := _tooltip.get_viewport_rect()
	var tooltip_rect := _tooltip.get_global_rect()
	assert_true(
		viewport.encloses(tooltip_rect),
		"expected %s within viewport %s" % [tooltip_rect, viewport],
	)


func test_visible_tooltip_follows_anchor_movement() -> void:
	# Given: A visible tooltip centered on its anchor.
	_tooltip.tooltip_position = KitTooltip.TOOLTIP_POSITION_CENTERED
	_tooltip.show_tooltip()
	var before := _tooltip.global_position

	# When: The anchor moves.
	_anchor.position += Vector2(120.0, -35.0)
	await get_tree().process_frame

	# Then: The tooltip shifts by the same delta.
	assert_eq(_tooltip.global_position, before + Vector2(120.0, -35.0))


func test_hidden_tooltip_ignores_anchor_movement() -> void:
	# Given: A tooltip that has never been shown.
	var before := _tooltip.global_position

	# When: The anchor moves.
	_anchor.position += Vector2(120.0, -35.0)
	await get_tree().process_frame

	# Then: The hidden tooltip does not reposition.
	assert_eq(_tooltip.global_position, before)


func test_visible_tooltip_repositions_on_content_resize() -> void:
	# Given: A visible tooltip centered on its anchor.
	_tooltip.tooltip_position = KitTooltip.TOOLTIP_POSITION_CENTERED
	_tooltip.show_tooltip()
	assert_eq(_tooltip.global_position, Vector2(450.0, 410.0))

	# When: The tooltip resizes, e.g. because its content grew.
	_tooltip.size = Vector2(300.0, 100.0)

	# Then: It recenters on the anchor using the new size.
	assert_eq(_tooltip.global_position, Vector2(400.0, 390.0))


func test_anchor_hidden_hides_visible_tooltip() -> void:
	# Given: A visible tooltip with its signals watched.
	_tooltip.show_tooltip()
	watch_signals(_tooltip)

	# When: The anchor node becomes hidden.
	_anchor.visible = false

	# Then: The tooltip hides and emits `tooltip_closed`.
	assert_false(_tooltip.visible)
	assert_signal_emitted(_tooltip, "tooltip_closed")


func test_show_makes_tooltip_visible_and_emits_opened() -> void:
	# Given: A hidden tooltip with its signals watched.
	watch_signals(_tooltip)

	# When: It is shown.
	_tooltip.show_tooltip()

	# Then: It becomes visible and emits `tooltip_opened`.
	assert_true(_tooltip.visible)
	assert_signal_emitted(_tooltip, "tooltip_opened")


func test_hide_without_animation_hides_and_emits_closed() -> void:
	# Given: A visible tooltip with its signals watched.
	_tooltip.show_tooltip()
	watch_signals(_tooltip)

	# When: It is hidden without animation.
	_tooltip.hide_tooltip(0.0, false)

	# Then: It becomes hidden and emits `tooltip_closed`.
	assert_false(_tooltip.visible)
	assert_signal_emitted(_tooltip, "tooltip_closed")


func test_show_when_visible_does_not_re_emit_opened() -> void:
	# Given: An already-visible tooltip.
	_tooltip.show_tooltip()
	watch_signals(_tooltip)

	# When: It is shown again.
	_tooltip.show_tooltip()

	# Then: The redundant call is a no-op; `tooltip_opened` is not re-emitted.
	assert_signal_not_emitted(_tooltip, "tooltip_opened")


func test_hide_when_hidden_does_not_emit_closed() -> void:
	# Given: A hidden tooltip with its signals watched.
	watch_signals(_tooltip)

	# When: A hide is requested.
	_tooltip.hide_tooltip(0.0, false)

	# Then: The redundant call is a no-op; `tooltip_closed` is not emitted.
	assert_signal_not_emitted(_tooltip, "tooltip_closed")


func test_slide_in_displaces_position_per_face() -> void:
	# Given: A slide-in animation with a known translation vector.
	var slide := KitAnimationSlide.new()
	slide.translation = Vector2(10.0, 4.0)
	_tooltip.slide_in = slide
	# NOTE: Each anchored face rotates the translation onto its own axes; the tooltip
	# starts displaced from the face position by that rotated offset.
	var expected := {
		KitTooltip.TOOLTIP_POSITION_CENTERED: Vector2(460.0, 414.0),
		KitTooltip.TOOLTIP_POSITION_ABOVE: Vector2(454.0, 330.0),
		KitTooltip.TOOLTIP_POSITION_BELOW: Vector2(454.0, 490.0),
		KitTooltip.TOOLTIP_POSITION_RIGHT: Vector2(610.0, 414.0),
		KitTooltip.TOOLTIP_POSITION_LEFT: Vector2(290.0, 414.0),
	}
	for face: KitTooltip.TooltipPosition in expected:
		# When: The tooltip is shown anchored to that face.
		_tooltip.tooltip_position = face
		_tooltip.show_tooltip()
		# Then: Its initial position is the face position plus the slide offset.
		assert_eq(_tooltip.global_position, expected[face])
		_tooltip.hide_tooltip(0.0, false)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(4000.0, 4000.0)
	add_child_autofree(_root)

	_anchor = Control.new()
	_anchor.position = ANCHOR_RECT.position
	_anchor.size = ANCHOR_RECT.size
	_root.add_child(_anchor)

	_tooltip = _build_tooltip(_anchor)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_region creates a `Control` at the given rect and parents it to `_root`. It is
## used both as a clamp region and as an explicit anchor.
func _add_region(rect: Rect2) -> Control:
	var region := Control.new()
	region.position = rect.position
	region.size = rect.size
	_root.add_child(region)
	return region


## _build_tooltip creates a `KitTooltip` with a fixed-size content child and a generous
## clamp region, parenting it to `parent`. When `anchor_node` is given it becomes the
## tooltip's explicit `anchor`; otherwise the tooltip falls back to its parent. The
## clamp region is a no-op for positioning tests; clamp-specific tests override
## `clamp_within` with a tighter region.
func _build_tooltip(parent: Control, anchor_node: Control = null) -> KitTooltip:
	var tooltip := KitTooltip.new()
	tooltip.anchor = anchor_node
	tooltip.clamp_within = _add_region(Rect2(Vector2.ZERO, Vector2(4000.0, 4000.0)))

	var content := Control.new()
	content.custom_minimum_size = TOOLTIP_SIZE
	tooltip.add_child(content)

	parent.add_child(tooltip)
	tooltip.size = TOOLTIP_SIZE

	return tooltip


## _show_with_position sets the tooltip's anchored face, shows it, and returns the
## resulting global position.
func _show_with_position(tooltip_position: KitTooltip.TooltipPosition) -> Vector2:
	_tooltip.tooltip_position = tooltip_position
	_tooltip.show_tooltip()
	return _tooltip.global_position
