##
## KitWorldTracker is the shared base for `KitWorldTracker2D` and `KitWorldTracker3D`.
## It drives its parent `Control` (the "host") to follow a world-space node projected
## into a `KitMap`'s `SubViewport`, emitting view-crossing and lifecycle signals.
##
## Subclasses supply dimension-specific projection; attach `KitWorldTracker2D` or
## `KitWorldTracker3D`, never this script directly.
##

class_name KitWorldTracker
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## target_entered_view is emitted when the tracked point crosses into the viewport.
signal target_entered_view

## target_exited_view is emitted when the tracked point crosses out of the viewport.
signal target_exited_view

## started is emitted when tracking becomes active (first frame or re-arm after stop).
signal started

## stopped is emitted when tracking halts after `target` or `map` becomes invalid.
signal stopped

# -- CONFIGURATION ------------------------------------------------------------------- #

## offset shifts the tracked point in screen-space pixels (e.g. to float a widget above
## its target). View-crossing and edge-clamping both act on the shifted point.
@export var offset: Vector2 = Vector2.ZERO

## clamped pins the host to the viewport edge while the tracked point is off-screen.
@export var clamped: bool = false

## viewport_margin insets the clamped edge by this many screen-space pixels.
@export var viewport_margin: float = 0.0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active: bool = false
var _host: Control = null
var _is_in_view: bool = false
var _view_initialized: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	var map := _get_map()
	var target := _get_target()
	if not _host or not is_instance_valid(map) or not is_instance_valid(target):
		if _active:
			_active = false
			stopped.emit()
		set_process(false)
		return

	if not _active:
		_active = true
		_view_initialized = false
		started.emit()

	var screen_position := _project_target()
	if screen_position.is_finite():
		screen_position += offset

	var screen_rect := map.get_screen_rect()
	var is_in_view := screen_rect.has_point(screen_position)
	if not is_in_view:
		screen_position = _resolve_offscreen(screen_position, screen_rect)

	# Move the host before announcing a crossing so handlers see the new position.
	if screen_position.is_finite():
		_host.global_position = screen_position

	if not _view_initialized or is_in_view != _is_in_view:
		_view_initialized = true
		_is_in_view = is_in_view
		if is_in_view:
			target_entered_view.emit()
		else:
			target_exited_view.emit()


func _ready() -> void:
	var map := _get_map()
	var target := _get_target()
	assert(map, "invalid config; missing 'map'")
	assert(map.sub_viewport, "invalid config; 'map' has no SubViewport")
	assert(target, "invalid config; missing 'target'")

	_host = get_parent() as Control
	assert(_host, "invalid config; KitWorldTracker's parent must be a Control")

	# Validate scene topology and tree ordering.
	assert(
		target.get_viewport() == map.sub_viewport,
		"invalid config; 'target' must live inside 'map.sub_viewport'",
	)

	# NOTE: The tracker reads `canvas_transform` in `_process`, which the camera writes
	# during its own. Godot runs `_process` in depth-first tree order, so a tracker
	# placed before the `SubViewport` reads a stale transform and lags by a frame.
	assert(
		is_greater_than(map.sub_viewport),
		(
			"invalid config; KitWorldTracker must be in a subtree later than"
			+ " 'map.sub_viewport' (typically inside a UI layer that is a later"
			+ " sibling of the SubViewportContainer)"
		),
	)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _get_map returns the `KitMap` whose `SubViewport` hosts the target. Overridden
## by subclasses to expose their dimension-typed `map` export.
func _get_map() -> KitMap:
	assert(false, "unimplemented; subclass must override '_get_map'")
	return null


## _get_target returns the world-space node being tracked. Overridden by subclasses to
## expose their dimension-typed `target` export.
func _get_target() -> Node:
	assert(false, "unimplemented; subclass must override '_get_target'")
	return null


## _project_target returns the target's projected screen position — non-finite when
## it cannot be projected (e.g. behind a 3D camera). Overridden by subclasses.
func _project_target() -> Vector2:
	assert(false, "unimplemented; subclass must override '_project_target'")
	return Vector2.INF


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _clamp_to_edge pins the host to the `viewport_margin`-inset edge of `screen_rect`,
## along the ray from the rect's center toward the tracked point. The edge is inset
## further by the host's extent so the whole widget stays on-screen, not just its
## origin. Returns a non-finite vector when no room is left to clamp into.
func _clamp_to_edge(screen_position: Vector2, screen_rect: Rect2) -> Vector2:
	var bounds := screen_rect.grow(-viewport_margin)

	# Inset the edge by the host's half-extent so the whole widget stays on-screen,
	# not just its origin; the intersection then lands the host's center on the edge.
	var half := _host.get_global_rect().size / 2.0
	bounds = Rect2(bounds.position + half, bounds.size - half * 2.0)

	# Degrade gracefully when no room is left to clamp into (e.g. an oversized
	# `viewport_margin`); the non-finite result leaves the host where it is.
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.INF

	var center := bounds.get_center()
	var direction := _offscreen_direction(screen_position, center)
	if direction == Vector2.ZERO:
		return Vector2.INF
	return _intersect_rect_edge(center, direction, bounds) - half


## _intersect_rect_edge returns the point where the ray from `origin` along `direction`
## meets `rect`'s edge. `origin` must lie inside `rect`; `direction` must be non-zero.
func _intersect_rect_edge(origin: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	var factor_x := INF
	var edge_x := 0.0
	if direction.x != 0.0:
		edge_x = rect.end.x if direction.x > 0.0 else rect.position.x
		factor_x = (edge_x - origin.x) / direction.x

	var factor_y := INF
	var edge_y := 0.0
	if direction.y != 0.0:
		edge_y = rect.end.y if direction.y > 0.0 else rect.position.y
		factor_y = (edge_y - origin.y) / direction.y

	if factor_x <= factor_y:
		return Vector2(edge_x, origin.y + direction.y * factor_x)
	return Vector2(origin.x + direction.x * factor_y, edge_y)


## _offscreen_direction returns the bearing from `center` toward the off-screen point.
## The default aims at `screen_position`; 3D overrides it for behind-camera points.
func _offscreen_direction(screen_position: Vector2, center: Vector2) -> Vector2:
	return screen_position - center


## _resolve_offscreen returns the host's screen position while the tracked point is
## off-screen; `screen_position` is the offset-adjusted projection (non-finite when the
## target cannot be projected). Override to customize off-screen handling — the default
## honors `clamped`; return a non-finite vector to leave the host put.
func _resolve_offscreen(screen_position: Vector2, screen_rect: Rect2) -> Vector2:
	if not clamped:
		return screen_position
	return _clamp_to_edge(screen_position, screen_rect)
