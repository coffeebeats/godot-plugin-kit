##
## KitFeelLayer owns the camera-and-screen half of game feel: shakes, kicks, the freeze
## on impact, and the full-screen flash. Per-entity feel is not here; that is a node on
## the thing it affects, such as `KitFeelHitFlash2D` on a sprite.
##
##     feel.impulse(IMPULSE_HIT, Vector2.LEFT)
##     feel.hit_stop(HIT_STOP_LIGHT)
##     feel.flash(FLASH_WHITE)
##
## Every call takes a resource describing the effect, so how a hit feels is a data edit
## rather than a code change.
##
## **This layer owns the camera's offset.** That is a contract rather than an
## implementation detail, since a single scalar cannot tell "our shake is still applied"
## from "the controller overwrote it", so adding a delta each frame silently drifts. A
## camera controller follows its subject through `position` or `global_transform` and
## leaves the offset alone. This layer writes it absolutely and restores the value it
## found.
##
## Attach `KitFeelLayer2D` or `KitFeelLayer3D`, never this script.
##
## NOTE: Placed after the `SubViewportContainer` and before `UI`, so it writes the
## camera after the camera's own update and before the HUD's trackers read it, and so
## its flash draws over the world but under the HUD.
##
## NOTE: This node must be usable before its own `_ready`. A map readies its game world
## before its UI, so an entity placed in a map scene at author time can call `impulse`
## while this layer is still unready. All state here is initialized at declaration or in
## `_init`, and `_ready` starts nothing it may not also stop.
##

@tool
class_name KitFeelLayer
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## impulse_finished is emitted when the camera has returned to rest.
signal impulse_finished

## hit_stop_finished is emitted when the time scale has been restored.
signal hit_stop_finished

## flash_finished is emitted when the full-screen flash has faded out.
signal flash_finished

# -- DEFINITIONS --------------------------------------------------------------------- #

## KICK_EPSILON is the displacement below which a decaying kick is treated as spent.
const KICK_EPSILON: float = 0.01

## NOISE_LANES are the sample lanes for the horizontal, vertical and roll channels. They
## are far enough apart in noise space that the three read as independent.
const NOISE_LANES := Vector3(0.0, 64.0, 128.0)

# -- CONFIGURATION ------------------------------------------------------------------- #

## intensity scales every camera disturbance. It is the hook an accessibility setting
## would drive; at zero the camera never moves.
@export_range(0.0, 1.0, 0.05) var intensity: float = 1.0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _flash_rect: ColorRect = null
var _flash_tween: Tween = null
var _hit_stop_deadline: float = 0.0
var _hit_stop_restore: float = 1.0
var _impulse: KitFeelImpulse = null
var _kick: Vector2 = Vector2.ZERO
var _noise := FastNoiseLite.new()
var _noise_time: float = 0.0
var _owns_roll: bool = false
var _rest_offset: Vector2 = Vector2.ZERO
var _rest_roll: float = 0.0
var _trauma: float = 0.0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## impulse disturbs the camera. `config` gives the shake its character; a non-zero
## `direction` adds a one-shot kick along that camera-plane bearing, which is what makes
## a hit read as coming from somewhere.
func impulse(config: KitFeelImpulse, direction := Vector2.ZERO) -> void:
	assert(config, "invalid argument: missing config")
	if not config:
		return

	if not _is_disturbed():
		_capture_rest()

	_impulse = config
	_trauma = minf(_trauma + config.trauma, 1.0)

	if direction != Vector2.ZERO and config.kick_strength != 0.0:
		_kick += direction.normalized() * config.kick_strength

	if config.roll > 0.0:
		_owns_roll = true

	set_process(true)


## hit_stop freezes the world briefly by scaling engine time.
##
## Requests take the longest deadline rather than stacking, so a combo landing on many
## targets in one frame stalls once instead of many times over.
##
## NOTE: This is global, not scoped to this map. Only the active map should call it.
func hit_stop(config: KitFeelHitStop) -> void:
	assert(config, "invalid argument: missing config")
	if not config or config.duration <= 0.0:
		return

	var deadline := _now() + config.duration
	if deadline <= _hit_stop_deadline:
		return

	if not is_hit_stopped():
		# NOTE: Captured rather than assumed to be 1.0, so a driver running the game
		# fast-forward gets its own scale back rather than normal speed.
		_hit_stop_restore = Engine.time_scale

	_hit_stop_deadline = deadline
	Engine.time_scale = maxf(config.scale, 0.0)

	set_process(true)


## flash washes the whole game world in a color and fades it out.
func flash(config: KitFeelFlash) -> void:
	assert(config, "invalid argument: missing config")
	if not config or config.duration <= 0.0:
		return

	var rect := _ensure_flash_rect()
	_resize_flash_rect()

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	rect.color = Color(config.color, 0.0)

	var rise := clampf(config.rise, 0.05, 0.95)

	_flash_tween = create_tween()
	_flash_tween.set_ignore_time_scale(true)
	_flash_tween.tween_property(
		rect, ^"color:a", config.color.a, config.duration * rise
	)
	_flash_tween.tween_property(rect, ^"color:a", 0.0, config.duration * (1.0 - rise))
	_flash_tween.finished.connect(flash_finished.emit)


## is_hit_stopped reports whether a freeze is currently in effect.
func is_hit_stopped() -> bool:
	return _hit_stop_deadline > 0.0


## get_trauma returns the current shake trauma, from none to the maximum.
func get_trauma() -> float:
	return _trauma


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	# NOTE: A hit-stop outliving its map would leave the whole game in slow motion, so
	# the time scale is restored here as well as at the deadline.
	_end_hit_stop()


func _init() -> void:
	# NOTE: The default frequency of 0.01 has a wavelength of about a hundred units, so
	# a time coordinate advanced by seconds would barely move within it. At one, the
	# coordinate advances by the configured oscillations per second directly.
	#
	# Set here rather than in `_ready`, because `impulse` may be called before that.
	_noise.frequency = 1.0

	set_process(false)


func _notification(what: int) -> void:
	# NOTE: A hit-stop is ended by the deadline check in `_process`, so a layer that
	# stops processing would strand the freeze and leave the whole game - the pause menu
	# that caused it included - in slow motion. `pause_when_covered` disables the map
	# subtree, which is exactly this notification.
	if what == NOTIFICATION_PAUSED:
		_end_hit_stop()


func _process(delta: float) -> void:
	# NOTE: Real seconds, so a shake keeps running at full speed through a hit-stop,
	# and so its rate does not depend on the frame rate.
	var seconds := delta / maxf(Engine.time_scale, 0.001)

	var is_busy := _step_hit_stop()

	if _step_impulse(seconds):
		is_busy = true

	if not is_busy:
		set_process(false)


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	resized.connect(_resize_flash_rect)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _get_map returns the `KitMap` this layer draws over. Overridden by subclasses to
## expose their dimension-typed `map` export.
func _get_map() -> KitMap:
	assert(false, "unimplemented; subclass must override '_get_map'")
	return null


## _read_offset returns the camera's current offset in camera-plane screen coordinates.
## Overridden by subclasses, which know the concrete camera type.
func _read_offset() -> Vector2:
	assert(false, "unimplemented; subclass must override '_read_offset'")
	return Vector2.ZERO


## _read_roll returns the camera's current roll in radians. Overridden by subclasses.
func _read_roll() -> float:
	assert(false, "unimplemented; subclass must override '_read_roll'")
	return 0.0


## _write_offset sets the camera's offset and, when this layer owns it, its roll.
## Overridden by subclasses, which know the concrete camera type.
func _write_offset(_offset: Vector2, _roll: float) -> void:
	assert(false, "unimplemented; subclass must override '_write_offset'")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _capture_rest records where the camera sits before a disturbance, so it can be put
## back exactly rather than eased toward zero.
func _capture_rest() -> void:
	_rest_offset = _read_offset()
	_rest_roll = _read_roll()


## _end_hit_stop restores the captured time scale, if a freeze is in effect.
func _end_hit_stop() -> void:
	if not is_hit_stopped():
		return

	Engine.time_scale = _hit_stop_restore
	_hit_stop_deadline = 0.0

	hit_stop_finished.emit()


func _ensure_flash_rect() -> ColorRect:
	if _flash_rect and is_instance_valid(_flash_rect):
		return _flash_rect

	_flash_rect = ColorRect.new()
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_flash_rect)

	return _flash_rect


## _get_debug_state reports the layer's live state to the debug bridge, so a change
## can be checked without a human watching the window.
##
## NOTE: Nothing in a shipped build calls this; the bridge finds it by method name.
func _get_debug_state() -> Dictionary:
	return {
		&"trauma": _trauma,
		&"kick": _kick,
		&"offset": _read_offset(),
		&"rest_offset": _rest_offset,
		&"intensity": intensity,
		&"time_scale": Engine.time_scale,
		&"hit_stopped": is_hit_stopped(),
		&"hit_stop_remaining": maxf(_hit_stop_deadline - _now(), 0.0),
	}


func _is_disturbed() -> bool:
	return _trauma > 0.0 or _kick != Vector2.ZERO


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## _step_hit_stop ends a freeze whose deadline has passed, and reports whether one is
## still in effect.
##
## NOTE: Checked here rather than awaited on a timer, so no coroutine or generation
## counter is needed; `_notification` covers a layer that stops processing before the
## deadline arrives.
func _step_hit_stop() -> bool:
	if not is_hit_stopped():
		return false

	if _now() < _hit_stop_deadline:
		return true

	_end_hit_stop()

	return false


## _step_impulse advances the camera disturbance by `seconds` and writes the result,
## reporting whether one is still in flight.
func _step_impulse(seconds: float) -> bool:
	var config := _impulse
	if not config:
		return false

	_noise_time += seconds * config.frequency
	_trauma = maxf(_trauma - config.decay * seconds, 0.0)
	_kick *= exp(-config.kick_decay * seconds)

	if _kick.length() < KICK_EPSILON:
		_kick = Vector2.ZERO

	if not _is_disturbed():
		# Write the captured rest exactly, rather than leaving a fading remainder.
		_write_offset(_rest_offset, _rest_roll)

		_impulse = null
		_owns_roll = false

		impulse_finished.emit()

		return false

	var amount := pow(_trauma, config.power) * intensity

	var shake := Vector2(
		config.amplitude.x * amount * _noise.get_noise_2d(NOISE_LANES.x, _noise_time),
		config.amplitude.y * amount * _noise.get_noise_2d(NOISE_LANES.y, _noise_time),
	)

	var roll := _rest_roll
	if _owns_roll:
		roll += config.roll * amount * _noise.get_noise_2d(NOISE_LANES.z, _noise_time)

	_write_offset(_rest_offset + shake + _kick * intensity, roll)

	return true


## _resize_flash_rect matches the flash to the game world's rect, so the letterbox
## around a pixel-art map is not washed along with it.
func _resize_flash_rect() -> void:
	if not _flash_rect or not is_instance_valid(_flash_rect):
		return

	var map := _get_map()
	var screen_rect := map.get_screen_rect() if map else get_global_rect()

	_flash_rect.global_position = screen_rect.position
	_flash_rect.size = screen_rect.size
