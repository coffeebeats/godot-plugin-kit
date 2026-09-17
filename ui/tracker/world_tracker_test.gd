##
## Unit tests for `KitWorldTracker` — verifies the shared tracking behavior (lifecycle
## and view-crossing signals, host positioning, off-screen clamping, startup assertions)
## through a stub subclass with a fakeable projection. Dimension-specific projection is
## covered by `world_tracker_2d_test.gd` and `world_tracker_3d_test.gd`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _container: SubViewportContainer = null
var _host: Control = null
var _map: KitMap = null
var _root: Control = null
var _target: Node = null
var _ui: Control = null
var _viewport: SubViewport = null

# -- TEST DOUBLES -------------------------------------------------------------------- #


## _StubTracker is a concrete `KitWorldTracker` whose projection is set directly by
## tests, decoupling the shared behavior from any dimension-specific `world_to_screen`.
class _StubTracker:
	extends KitWorldTracker

	var map: KitMap = null
	var projection: Vector2 = Vector2.ZERO
	var target: Node = null:
		set(value):
			target = value
			if is_instance_valid(value):
				set_process(true)

	func _get_map() -> KitMap:
		return map

	func _get_target() -> Node:
		return target

	func _project_target() -> Vector2:
		return projection


## _OverrideStubTracker overrides `_resolve_offscreen` to confirm it is the off-screen
## extension point — it parks the host at a fixed sentinel while off-screen.
class _OverrideStubTracker:
	extends _StubTracker

	func _resolve_offscreen(_screen_position: Vector2, _screen_rect: Rect2) -> Vector2:
		return Vector2(7, 7)


# -- TEST METHODS -------------------------------------------------------------------- #


func test_positions_host_at_projection() -> void:
	# Given: A tracker whose target projects to (100, 50).
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(100, 50)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host sits at the projected point.
	assert_eq(_host.global_position, Vector2(100, 50))


func test_offset_is_applied() -> void:
	# Given: A tracker with a non-zero offset.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(100, 50)
	tracker.offset = Vector2(7, -13)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host sits at the projection plus the offset.
	assert_eq(_host.global_position, Vector2(107, 37))


func test_no_op_when_target_freed() -> void:
	# Given: A tracker positioned at its target.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(100, 50)
	await wait_process_frames(1)
	var last := _host.global_position
	# When: The target is freed.
	_target.free()
	await wait_process_frames(1)
	# Then: The host stays at its last position.
	assert_eq(_host.global_position, last)


func test_freezes_host_when_projection_non_finite() -> void:
	# Given: A tracker positioned at an on-screen target.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(320, 180)
	await wait_process_frames(1)
	var last := _host.global_position
	# When: The projection becomes non-finite.
	tracker.projection = Vector2.INF
	await wait_process_frames(1)
	# Then: The host stays put — a non-finite projection moves nothing.
	assert_eq(_host.global_position, last)


func test_emits_started_on_first_frame() -> void:
	# Given: A watched tracker with a valid target.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(100, 50)
	watch_signals(tracker)
	# When: The first frame is processed.
	await wait_process_frames(1)
	# Then: `started` is emitted once.
	assert_signal_emit_count(tracker, "started", 1)


func test_emits_stopped_when_target_freed() -> void:
	# Given: A tracker actively following a target.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(100, 50)
	watch_signals(tracker)
	await wait_process_frames(1)
	# When: The target is freed.
	_target.free()
	await wait_process_frames(1)
	# Then: `stopped` is emitted once.
	assert_signal_emit_count(tracker, "stopped", 1)


func test_emits_started_on_retarget() -> void:
	# Given: A tracker whose target was freed, emitting `stopped`.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(100, 50)
	watch_signals(tracker)
	await wait_process_frames(1)
	_target.free()
	await wait_process_frames(1)
	# When: A new valid target is assigned.
	var new_target := Node.new()
	_viewport.add_child(new_target)
	tracker.target = new_target
	await wait_process_frames(1)
	# Then: `started` is emitted again; `stopped` fired only once.
	assert_signal_emit_count(tracker, "started", 2)
	assert_signal_emit_count(tracker, "stopped", 1)


func test_emits_view_signals_on_transitions() -> void:
	# Given: A tracker whose target starts off-screen.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(1000, 180)
	watch_signals(tracker)
	# When: The target is processed off-screen, then enters and exits the viewport.
	await wait_process_frames(1)
	tracker.projection = Vector2(320, 180)
	await wait_process_frames(1)
	tracker.projection = Vector2(1000, 180)
	await wait_process_frames(1)
	# Then: The off-screen start and the later exit each emitted; entry emitted once.
	assert_signal_emit_count(tracker, "target_exited_view", 2)
	assert_signal_emit_count(tracker, "target_entered_view", 1)


func test_emits_entered_view_for_on_screen_start() -> void:
	# Given: A tracker whose target starts inside the viewport.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(320, 180)
	watch_signals(tracker)
	# When: The first frame is processed.
	await wait_process_frames(1)
	# Then: `target_entered_view` is emitted on the first frame.
	assert_signal_emit_count(tracker, "target_entered_view", 1)
	assert_signal_emit_count(tracker, "target_exited_view", 0)


func test_unclamped_host_follows_target_off_screen() -> void:
	# Given: An unclamped tracker (the default) with an off-screen target.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(960, 540)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host trails the target to its raw off-screen position.
	assert_eq(_host.global_position, Vector2(960, 540))


func test_clamped_host_pins_to_viewport_edge() -> void:
	# Given: A clamped tracker with a target off the lower-right of the viewport.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(960, 360)
	tracker.clamped = true
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host pins to the right edge at (640, 270).
	assert_eq(_host.global_position, Vector2(640, 270))


func test_clamped_host_inset_by_viewport_margin() -> void:
	# Given: A clamped tracker with a 40px margin and a target off the right edge.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(960, 180)
	tracker.clamped = true
	tracker.viewport_margin = 40.0
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host pins 40px inside the right edge, at (600, 180).
	assert_eq(_host.global_position, Vector2(600, 180))


func test_clamped_offset_does_not_breach_margin() -> void:
	# Given: A clamped tracker with a margin and a large offset.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(960, 180)
	tracker.clamped = true
	tracker.viewport_margin = 40.0
	tracker.offset = Vector2(1000, 0)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The host pins to the inset edge at (600, 180), unmoved by `offset`.
	assert_eq(_host.global_position, Vector2(600, 180))


func test_clamped_host_stays_fully_visible() -> void:
	# Given: A clamped tracker, a sized host, an off-screen target.
	_host.size = Vector2(80, 40)
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(960, 180)
	tracker.clamped = true
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: The whole host rect stays on-screen, not just its origin.
	assert_true(_map.get_screen_rect().encloses(_host.get_global_rect()))
	assert_eq(_host.global_position, Vector2(560, 160))


func test_clamped_host_frozen_when_no_room_to_clamp() -> void:
	# Given: A clamped tracker, an oversized margin, an on-screen target.
	var tracker := _attach_tracker(_host)
	tracker.projection = Vector2(320, 180)
	tracker.clamped = true
	tracker.viewport_margin = 200.0
	await wait_process_frames(1)
	var last := _host.global_position
	# When: The target moves off-screen.
	tracker.projection = Vector2(2000, 180)
	await wait_process_frames(1)
	# Then: The host freezes — a collapsed clamp region degrades gracefully.
	assert_eq(_host.global_position, last)


func test_resolve_offscreen_override_replaces_default() -> void:
	# Given: A tracker subclass overriding `_resolve_offscreen` with a fixed result.
	var tracker := _OverrideStubTracker.new()
	tracker.map = _map
	tracker.target = _target
	tracker.projection = Vector2(960, 360)
	_host.add_child(tracker)
	# When: A frame is processed with the target off-screen.
	await wait_process_frames(1)
	# Then: The override decides the host position, not the built-in `clamped` logic.
	assert_eq(_host.global_position, Vector2(7, 7))


func test_parent_must_be_control_asserts() -> void:
	# Given: A tracker whose parent is a plain Node, not a Control.
	var bare_parent := Node.new()
	_root.add_child(bare_parent)
	# When: The tracker is added to that bare Node.
	_attach_tracker(bare_parent)
	await wait_process_frames(1)
	# Then: A startup assertion fires identifying the Control requirement.
	assert_engine_error("Control")


func test_target_outside_subviewport_asserts() -> void:
	# Given: A target placed in the UI subtree, not inside the SubViewport.
	var stray := Node.new()
	_ui.add_child(stray)
	_target = stray
	# When: A tracker is created pointing at that stray target.
	_attach_tracker(_host)
	await wait_process_frames(1)
	# Then: A startup assertion fires identifying the SubViewport requirement.
	assert_engine_error("sub_viewport")


func test_tree_order_invariant_asserts() -> void:
	# Given: The UI layer is moved before the SubViewportContainer.
	_map.move_child(_ui, 0)
	# When: A tracker is attached to the host inside the now-earlier UI subtree.
	_attach_tracker(_host)
	await wait_process_frames(1)
	# Then: A startup assertion fires identifying the tree-order requirement.
	assert_engine_error("later than")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920, 1080)
	add_child_autofree(_root)

	_map = partial_double(KitMap).new()
	stub(_map, "_ready").to_do_nothing()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)

	_target = Node.new()
	_viewport.add_child(_target)

	_map.sub_viewport = _viewport

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.add_child(_ui)

	_host = Control.new()
	_ui.add_child(_host)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _attach_tracker(parent: Node) -> _StubTracker:
	var tracker := _StubTracker.new()
	tracker.map = _map
	tracker.target = _target
	parent.add_child(tracker)
	return tracker
