##
## KitTooltip renders its child node in a popover anchored to a `Control` - by default
## its parent, or the `anchor` node when one is set. It reveals and hides the popover in
## response to hover and focus events on configurable nodes (which may differ from the
## anchor).
##
## The popover is always displayed adjacent to one face of the anchor's bounding box (or
## centered on it) and is clamped so it never renders off-screen. The anchor may move
## freely - including every frame, e.g. a `KitWorldTracker`-driven host - but it must
## not be rotated.
##
## NOTE: It extends `CenterContainer` so that, regardless of its contents, the
## `KitTooltip` node's bounding box always matches its child's.
##

class_name KitTooltip
extends CenterContainer

# -- SIGNALS ------------------------------------------------------------------------- #

## tooltip_opened is emitted when the tooltip is first triggered to be shown. If
## animations are required, this will be triggered as they begin.
signal tooltip_opened

## tooltip_closed is emitted when the tooltip is first triggered to be hidden. If
## animations are required, this will be triggered as they begin.
signal tooltip_closed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## TooltipPosition defines one of the four faces of the anchor node's bounding box to
## which the tooltip can be anchored.
enum TooltipPosition {  # gdlint:ignore=class-definitions-order
	CENTERED = 0,
	ABOVE = 1,
	RIGHT = 2,
	BELOW = 3,
	LEFT = 4,
}

const TOOLTIP_POSITION_ABOVE := TooltipPosition.ABOVE
const TOOLTIP_POSITION_BELOW := TooltipPosition.BELOW
const TOOLTIP_POSITION_CENTERED := TooltipPosition.CENTERED
const TOOLTIP_POSITION_LEFT := TooltipPosition.LEFT
const TOOLTIP_POSITION_RIGHT := TooltipPosition.RIGHT

# -- CONFIGURATION ------------------------------------------------------------------- #

## anchor is the `Control` node the tooltip positions itself against. When left unset,
## the tooltip's parent node is used as the anchor.
@export var anchor: Control = null

@export_group("Display")

@export_subgroup("Positioning")

## tooltip_position is the target side of the anchor node at which to display the
## tooltip.
@export var tooltip_position: TooltipPosition = TooltipPosition.ABOVE

## tooltip_offset is a positional offset from the anchor when the tooltip is shown.
@export var tooltip_offset: Vector2 = Vector2.ZERO

@export_subgroup("Bounds")

## clamp_within constrains the tooltip to this `Control`'s global rect so it never
## renders off-screen. When left unset, the tooltip is clamped to the viewport instead.
@export var clamp_within: Control = null

## clamp_margin insets the clamp region (the viewport or `clamp_within`) by this many
## pixels on every side, keeping a gap between the tooltip and the region's edge.
@export var clamp_margin: float = 0.0

@export_group("Trigger")

@export_subgroup("Focus")

## focus_delay is a wait time prior to starting the "show" tooltip animation when the
## action is triggered by the focus target. Ignored when `show_when_focused` is `false`.
@export var focus_delay: float = 0.0

## focus_target is an alternative `Control` node which, when it grabs focus, will reveal
## the tooltip. Ignored if `show_when_focused` is set to `false`.
##
## NOTE: If set, the `anchor` node will *not* be listened to for hover events. Ignored
## when `show_when_focused` is `false`.
@export var focus_target: Control = null

## show_when_focused controls whether the tooltip will be revealed by focusing the
## anchor node (or `focus_target` if set).
@export var show_when_focused: bool = true

@export_subgroup("Hover")

## hover_hide_delay is a wait time prior to starting the "hide" tooltip animation. This
## is to allow time for the cursor to hover over the tooltip.
@export var hover_hide_delay: float = 0.0

## hover_show_delay is a wait time prior to starting the "show" tooltip animation when
## the action is triggered by the hover target. Ignored when `show_when_hovered` is
## `false`.
@export var hover_show_delay: float = 0.0

## hover_target is an alternative `CanvasItem` node which, when hovered, will reveal the
## tooltip. Ignored if `show_when_hovered` is set to `false`.
##
## NOTE: If set, the `anchor` node will *not* be listened to for hover events. Ignored
## when `show_when_hovered` is `false`.
@export var hover_target: CanvasItem = null

## keep_open_when_tooltip_hovered controls whether the tooltip will remain open when the
## user hovers over it.
@export var keep_open_when_tooltip_hovered: bool = true

## show_when_hovered controls whether the tooltip will be revealed by hovering over the
## anchor node (or `hover_target` if set).
@export var show_when_hovered: bool = true

@export_group("Animation")

@export_subgroup("Fade")

## fade_in is an incoming fade animation to apply to the tooltip.
@export var fade_in: KitAnimationFade = null

## fade_out is an outgoing fade animation to apply to the tooltip.
@export var fade_out: KitAnimationFade = null

@export_subgroup("Slide")

## slide_in is an incoming slide animation to apply to the tooltip.
@export var slide_in: KitAnimationSlide = null

## slide_out is an outgoing slide animation to apply to the tooltip.
@export var slide_out: KitAnimationSlide = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _anchor: Control = null
var _anim_offset: Vector2 = Vector2.ZERO
var _is_focused: bool = false
var _is_hover_target_hovered: bool = false
var _is_tooltip_hovered: bool = false
var _is_visible: bool = false
var _is_waiting_to_hide: bool = false
var _mouse_filter: MouseFilter = MouseFilter.MOUSE_FILTER_IGNORE
var _tween: Tween = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## hide_tooltip hides the tooltip after animating its outgoing effects. If `animate` is
## `false`, then animations will be skipped.
##
## NOTE: This method should be preferred over `hide`, which won't handle animations.
func hide_tooltip(delay: float = 0.0, animate: bool = true) -> void:
	if not _is_visible:
		return

	_reset_animation()
	_is_visible = false

	if animate:
		_hide_tooltip(delay)
	else:
		visible = false

	tooltip_closed.emit()


## show_tooltip reveals the tooltip after animating its incoming effects.
##
## NOTE: This method should be preferred over `show`, which will immediately toggle
## visibility - ignoring animations.
func show_tooltip(delay: float = 0.0) -> void:
	if _is_visible:
		return

	_reset_animation()
	_is_visible = true

	_show_tooltip(delay)

	tooltip_opened.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	# Reposition when the tooltip's own size changes (e.g. dynamic content); the face-
	# positioning math depends on the tooltip's rect, and no other signal fires for a
	# steady-state self-resize.
	if what == NOTIFICATION_RESIZED and _is_visible:
		_update_position()


func _ready() -> void:
	_mouse_filter = mouse_filter
	mouse_filter = MOUSE_FILTER_IGNORE

	visible = false
	top_level = true

	_anchor = anchor if anchor else get_parent() as Control
	assert(_anchor, "invalid config; 'anchor' must be a 'Control' (or parent one)")
	assert(_anchor.is_inside_tree(), "invalid state; anchor must be in scene tree")
	assert(clamp_margin >= 0.0, "invalid config; 'clamp_margin' must be non-negative")

	Signals.connect_safe(_anchor.item_rect_changed, _on_anchor_rect_changed)
	Signals.connect_safe(_anchor.visibility_changed, _on_anchor_visibility_changed)

	if keep_open_when_tooltip_hovered:
		Signals.connect_safe(mouse_entered, _on_tooltip_mouse_entered)
		Signals.connect_safe(mouse_exited, _on_tooltip_mouse_exited)

	if show_when_hovered:
		var hover_node := hover_target if hover_target else _anchor
		assert(
			hover_node.mouse_filter != MOUSE_FILTER_IGNORE,
			"invalid config; hover target cannot ignore mouse",
		)

		Signals.connect_safe(hover_node.mouse_entered, _on_hover_target_mouse_entered)
		Signals.connect_safe(hover_node.mouse_exited, _on_hover_target_mouse_exited)

	if show_when_focused:
		var focus_node := focus_target if focus_target else _anchor
		Signals.connect_safe(focus_node.focus_entered, _on_focus_target_focus_entered)
		Signals.connect_safe(focus_node.focus_exited, _on_focus_target_focus_exited)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _clamp_to_bounds(global_pos: Vector2) -> Vector2:
	var bounds := get_viewport_rect()
	if is_instance_valid(clamp_within):
		bounds = clamp_within.get_global_rect()

	bounds = bounds.grow(-clamp_margin)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return global_pos

	# NOTE: Pin to the region's top-left when the tooltip is larger than the clamp
	# region; this keeps `clampf`'s minimum bound at or below its maximum.
	var extent := get_global_rect().size
	var max_x := maxf(bounds.position.x, bounds.end.x - extent.x)
	var max_y := maxf(bounds.position.y, bounds.end.y - extent.y)

	return Vector2(
		clampf(global_pos.x, bounds.position.x, max_x),
		clampf(global_pos.y, bounds.position.y, max_y),
	)


func _get_slide_offset(animation: KitAnimationSlide) -> Vector2:
	if not animation:
		return Vector2.ZERO

	var animation_offset: Vector2
	var motion := animation.translation

	# NOTE: `motion` is authored in canonical RIGHT-face orientation; `x` runs from
	# the anchor toward the tooltip and `y` runs along the face. Each branch rotates
	# or reflects it onto that face's axes so one authored `KitAnimationSlide` reads
	# correctly regardless of `tooltip_position`.
	match tooltip_position:
		TOOLTIP_POSITION_CENTERED:
			animation_offset = motion
		TOOLTIP_POSITION_ABOVE:
			animation_offset = Vector2(motion.y, -motion.x)
		TOOLTIP_POSITION_BELOW:
			animation_offset = Vector2(motion.y, motion.x)
		TOOLTIP_POSITION_RIGHT:
			animation_offset = motion
		TOOLTIP_POSITION_LEFT:
			animation_offset = Vector2(-motion.x, motion.y)

	return animation_offset


func _get_target_tooltip_global_position() -> Vector2:
	assert(
		not _anchor.get_rotation(),
		"invalid config; rotated anchor not supported",
	)

	var target_rect := _anchor.get_global_rect()
	var tooltip_rect := get_global_rect()

	var distance := (target_rect.size / 2.0) + (tooltip_rect.size / 2.0)

	match tooltip_position:
		TOOLTIP_POSITION_CENTERED:
			distance = Vector2.ZERO
		TOOLTIP_POSITION_ABOVE:
			distance = Vector2(0.0, -distance.y)
		TOOLTIP_POSITION_RIGHT:
			distance = Vector2(distance.x, 0.0)
		TOOLTIP_POSITION_BELOW:
			distance = Vector2(0.0, distance.y)
		TOOLTIP_POSITION_LEFT:
			distance = Vector2(-distance.x, 0.0)

	return (
		target_rect.get_center() + distance - tooltip_rect.size / 2.0 + tooltip_offset
	)


func _hide_tooltip(delay: float) -> void:
	assert(not _tween, "invalid state; already animating")
	assert(not _is_visible, "invalid state; conflicting visible state")

	var parallel: bool = false
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)

	_is_waiting_to_hide = true
	_tween.tween_interval(delay)
	_tween.tween_callback(func() -> void: _is_waiting_to_hide = false)

	if fade_out:
		fade_out.apply_tween_property(_tween, self, false)

	if slide_out:
		parallel = fade_out != null
		_tween_slide_offset(slide_out, _get_slide_offset(slide_out), parallel)

	if parallel:
		_tween.chain()

	_tween.tween_callback(func() -> void: mouse_filter = MOUSE_FILTER_IGNORE)
	_tween.tween_callback(hide)
	_tween.tween_callback(_reset_animation)  # Kills tween so must be last.


func _reset_animation() -> void:
	_is_waiting_to_hide = false

	if not _tween:
		return

	_tween.kill()
	_tween = null


func _show_tooltip(delay: float) -> void:
	assert(not _tween, "invalid state; already animating")
	assert(_is_visible, "invalid state; conflicting visible state")

	# Begin displaced by the slide-in offset; the tween eases `_anim_offset` back to
	# zero while `_update_position` keeps it composed against the anchor.
	_anim_offset = _get_slide_offset(slide_in)
	_update_position()

	modulate.a = 1  # Ensure the alpha value has been restored.
	show()

	var parallel: bool = false
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	_tween.tween_interval(delay)

	if fade_in:
		modulate.a = 0
		fade_in.apply_tween_property(_tween, self, false)

	if slide_in:
		parallel = fade_in != null
		_tween_slide_offset(slide_in, Vector2.ZERO, parallel)

	if parallel:
		_tween.chain()

	_tween.tween_callback(func() -> void: mouse_filter = _mouse_filter)
	_tween.tween_callback(_reset_animation)  # Kills tween so must be last.


func _tween_slide_offset(slide: KitAnimationSlide, to: Vector2, parallel: bool) -> void:
	if parallel:
		_tween.parallel()

	# NOTE: The slide drives `_anim_offset` through a method tweener rather than a
	# property tweener on `position`, so each step recomposes the tooltip's position
	# against the anchor's *current* location. This lets the popover animate smoothly
	# even while the anchor is moving (e.g. a `KitWorldTracker`-driven host).
	(
		_tween
		. tween_method(_set_anim_offset, _anim_offset, to, slide.duration)
		. set_delay(slide.delay)
		. set_ease(slide.ease_type)
		. set_trans(slide.transition_type)
	)


func _update_position() -> void:
	var target := _get_target_tooltip_global_position() + _anim_offset
	set_global_position(_clamp_to_bounds(target))


# -- SETTERS/GETTERS ----------------------------------------------------------------- #


func _set_anim_offset(offset: Vector2) -> void:
	_anim_offset = offset
	_update_position()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_anchor_rect_changed() -> void:
	if _is_visible:
		_update_position()


func _on_anchor_visibility_changed() -> void:
	assert(_anchor.is_inside_tree(), "invalid state; anchor must be in scene tree")

	if _is_visible and not _anchor.visible:
		hide_tooltip(0.0, false)

	elif not _is_visible and _anchor.visible:
		var anchor_rect := _anchor.get_global_rect()
		var global_mouse_position := get_global_mouse_position()

		# FIXME(https://github.com/godotengine/godot/issues/87203): Remove workaround.
		# Note that this solution fails if the anchor is blocked by another node.
		if anchor_rect.has_point(global_mouse_position):
			_update_position()
			_on_hover_target_mouse_entered()


func _on_focus_target_focus_entered() -> void:
	_is_focused = true
	if not _is_visible:
		show_tooltip(focus_delay)


func _on_focus_target_focus_exited() -> void:
	_is_focused = false
	if not _is_hover_target_hovered and not _is_tooltip_hovered and _is_visible:
		hide_tooltip()


func _on_hover_target_mouse_entered() -> void:
	_is_hover_target_hovered = true

	if _is_waiting_to_hide:
		assert(visible, "invalid state; expected visible tooltip")

		_is_visible = true
		_reset_animation()

	if not _is_visible:
		show_tooltip(hover_show_delay)


func _on_hover_target_mouse_exited() -> void:
	_is_hover_target_hovered = false
	if not _is_focused and _is_visible:
		hide_tooltip(hover_hide_delay)


func _on_tooltip_mouse_entered() -> void:
	_is_tooltip_hovered = true

	if _is_waiting_to_hide:
		assert(visible, "invalid state; expected visible tooltip")

		_is_visible = true
		_reset_animation()


func _on_tooltip_mouse_exited() -> void:
	_is_tooltip_hovered = false
	if not _is_focused and not _is_hover_target_hovered and _is_visible:
		hide_tooltip(hover_hide_delay)
