##
## KitHudIndicator draws an arrow pointing toward its entity, for a group pinned to the
## viewport edge while that entity is off-screen.
##
## It does no tracking of its own. Its group's `KitWorldTracker` clamps along the ray
## from the centre of the screen toward the entity, so the arrow's bearing is simply the
## direction from that centre to where the group has been put.
##
## The group it lives in is the mirror of a nameplate's: `clamped` on the tracker, and
## `hide_offscreen` off, so it appears only when the entity cannot be seen.
##
## It draws itself rather than shipping a texture, so the template needs no art.
##

class_name KitHudIndicator
extends Control

# -- CONFIGURATION ------------------------------------------------------------------- #

## color is the arrow's fill.
@export var color: Color = Color(1.0, 1.0, 1.0, 0.85)

## hide_in_view hides the arrow while the entity is on screen, which is the usual
## behavior; the group stays visible so the arrow can reappear.
@export var hide_in_view: bool = true

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _draw() -> void:
	var center := size / 2.0
	var half := size / 2.0

	var points := PackedVector2Array(
		[
			center + Vector2(half.x, 0.0),
			center + Vector2(-half.x, -half.y),
			center + Vector2(-half.x, half.y),
		]
	)

	draw_colored_polygon(points, color)


func _process(_delta: float) -> void:
	var layer := KitHudLayer.of(self)
	if not layer:
		return

	var group := KitHudGroup.of(self)

	# NOTE: The bearing is taken from the entity's *unclamped* projection, not from this
	# node's own rect. Its rect has already been clamped onto the viewport edge, so it
	# answers where the arrow is rather than where it should point.
	var bearing := _get_bearing(layer, group)
	if bearing.length_squared() > 0.0:
		rotation = bearing.angle()

	if hide_in_view:
		# NOTE: The group is clamped inside the rect and so always looks "in view";
		# whether the entity can be seen is what the group records from its tracker.
		visible = not group.is_target_in_view if group else true


func _ready() -> void:
	_center_pivot()

	# NOTE: Connected rather than set once, since `rotation` turns the arrow about this
	# point and a stale pivot swings it around a corner instead of its middle.
	resized.connect(_center_pivot)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _center_pivot puts the rotation pivot at the middle of the arrow.
func _center_pivot() -> void:
	pivot_offset = size / 2.0


## _get_bearing returns the screen-space direction from the centre of the game world
## toward the tracked entity, falling back to this node's own position when there is no
## group to ask.
func _get_bearing(layer: KitHudLayer, group: KitHudGroup) -> Vector2:
	var centre := layer.get_screen_rect().get_center()

	var projected := group.project_target() if group else Vector2.INF
	if not projected.is_finite():
		return get_global_rect().get_center() - centre

	return projected - centre
