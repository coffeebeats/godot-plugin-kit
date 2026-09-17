##
## KitHudNumber is one floating number, spawned by `KitHudNumbers` and freed when it
## finishes.
##
## It knows nothing about maps, dimensions or projection. Its origin arrives as a
## `Callable` returning a screen position, which is what lets the same element stay
## pinned to a spot in a 2D world, a 3D world, or a fixed point on screen without a
## branch of its own.
##

class_name KitHudNumber
extends Label

# -- INITIALIZATION ------------------------------------------------------------------ #

var _drift: Vector2 = Vector2.ZERO
var _origin: Callable = Callable()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## play shows `value` and animates it away, freeing the node when it finishes. `origin`
## returns the screen position the number drifts from, re-read every frame so the number
## holds its place while the camera moves.
func play(value: float, style: KitHudNumberStyle, origin: Callable) -> void:
	assert(style, "invalid argument: missing style")
	assert(origin.is_valid(), "invalid argument: missing origin")
	if not style or not origin.is_valid():
		queue_free()
		return

	_origin = origin

	text = style.format % value
	if style.theme_variation != &"":
		theme_type_variation = style.theme_variation

	# NOTE: The label sizes itself from its text, and both the centering below and the
	# scale pivot need that size now rather than on the next layout pass.
	reset_size()
	pivot_offset = size / 2.0

	_update_position()

	var spread := style.spread_degrees / 2.0
	var travel := style.travel.rotated(deg_to_rad(randf_range(-spread, spread)))

	var tween := create_tween()
	tween.set_parallel(true)

	if style.motion:
		style.motion.tween_property(tween, self, ^"_drift", travel, style.duration)
	else:
		tween.tween_property(self, ^"_drift", travel, style.duration)

	if style.fade:
		style.fade.tween_property(tween, self, ^"modulate:a", 0.0, style.duration)
	else:
		tween.tween_property(self, ^"modulate:a", 0.0, style.duration)

	if style.punch > 0.0:
		scale = Vector2.ONE * (1.0 + style.punch)
		(
			tween
			. tween_property(self, ^"scale", Vector2.ONE, style.duration / 2.0)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)

	tween.finished.connect(queue_free)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	_update_position()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _update_position re-reads the origin and re-centers the label on it, so a number
## spawned in the world stays over the spot it came from as the camera pans.
func _update_position() -> void:
	if not _origin.is_valid():
		return

	var screen_position: Vector2 = _origin.call()
	if not screen_position.is_finite():
		return

	global_position = screen_position + _drift - size / 2.0
