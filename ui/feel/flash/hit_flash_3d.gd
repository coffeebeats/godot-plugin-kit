##
## KitFeelHitFlash3D washes a mesh toward a flat color and back, the 3D counterpart of
## `KitFeelHitFlash2D`.
##
## It is a child of the thing it flashes, so nothing reaches sideways into another
## subtree:
##
##   Enemy                (Node3D)
##   ├── MeshInstance3D
##   │   └── KitFeelHitFlash3D
##   └── KitHudAnchor3D
##
## It drives a `material_overlay` rather than the mesh's own materials, so it needs
## nothing of whatever the game shades its meshes with, and leaves no trace once done.
##

class_name KitFeelHitFlash3D
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## config is the flash played when `play` is called without one.
@export var config: KitFeelFlash = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _host: GeometryInstance3D = null
var _overlay: StandardMaterial3D = null
var _overlay_rest: Material = null
var _tween: Tween = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## play flashes the parent, using `override` when given and the exported config
## otherwise. Calling it again restarts the flash rather than stacking.
func play(override: KitFeelFlash = null) -> void:
	var settings := override if override else config

	assert(settings, "invalid config; missing 'config'")
	if not settings or not _host or settings.duration <= 0.0:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_overlay.albedo_color = Color(settings.color, 0.0)
	_host.material_overlay = _overlay

	var peak := settings.color.a
	var rise := clampf(settings.rise, 0.05, 0.95)

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(_set_amount, 0.0, peak, settings.duration * rise)
	_tween.tween_method(_set_amount, peak, 0.0, settings.duration * (1.0 - rise))
	_tween.finished.connect(_clear_overlay)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not (get_parent() is GeometryInstance3D):
		warnings.append("Parent must be a GeometryInstance3D, such as a MeshInstance3D")

	return warnings


func _ready() -> void:
	_host = get_parent() as GeometryInstance3D
	assert(_host, "invalid config; parent must be a 'GeometryInstance3D'")
	if not _host:
		return

	# NOTE: Recorded so the flash gives back whatever the mesh already wore - an outline,
	# a rim light, a selection highlight - rather than clearing the slot it borrowed.
	_overlay_rest = _host.material_overlay

	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _clear_overlay puts back the overlay the mesh had before the flash, so a mesh at rest
## carries no extra pass and keeps whatever it wore of its own.
func _clear_overlay() -> void:
	if _host and is_instance_valid(_host):
		_host.material_overlay = _overlay_rest


func _set_amount(value: float) -> void:
	if not _overlay:
		return

	_overlay.albedo_color.a = value
