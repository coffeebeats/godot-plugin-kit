##
## KitFeelHitFlash2D blends a sprite toward a flat color and back, the hit flash that
## reads as a blow landing.
##
## It is a child of the thing it flashes rather than a method on the feel layer, so no
## layer reaches sideways into another subtree, and so the effect is visible in the
## editor on the scene that has it:
##
##   Enemy                (Node2D)
##   ├── Sprite2D
##   │   └── KitFeelHitFlash2D
##   └── KitHudAnchor2D
##
## It drives per-instance shader parameters, so one shared material serves every sprite
## and flashing one leaves the rest alone. A parent with no material of its own is given
## the template's; a parent with its own shader needs the two `instance uniform` lines
## from `flash.gdshader` in it, and is warned about and left alone if it does not have
## them, since driving a parameter nothing declares would otherwise fail silently.
##

class_name KitFeelHitFlash2D
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

## PARAM_AMOUNT is the shader parameter holding how far the sprite is blended.
const PARAM_AMOUNT := &"flash_amount"

## PARAM_COLOR is the shader parameter holding the color blended toward.
const PARAM_COLOR := &"flash_color"

# -- CONFIGURATION ------------------------------------------------------------------- #

## config is the flash played when `play` is called without one.
@export var config: KitFeelFlash = null

## material is assigned to the parent when it has none. Leave it as the template's
## unless the game ships a shader of its own carrying the same two parameters.
@export var material: ShaderMaterial = null

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"ui/feel")  # gdlint:ignore=class-definitions-order,max-line-length

var _host: CanvasItem = null
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

	_host.set_instance_shader_parameter(PARAM_COLOR, settings.color)

	var peak := settings.color.a
	var rise := clampf(settings.rise, 0.05, 0.95)

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(_set_amount, 0.0, peak, settings.duration * rise)
	_tween.tween_method(_set_amount, peak, 0.0, settings.duration * (1.0 - rise))


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not (get_parent() is CanvasItem):
		warnings.append("Parent must be a CanvasItem, such as a Sprite2D")

	return warnings


func _ready() -> void:
	_host = get_parent() as CanvasItem
	assert(_host, "invalid config; parent must be a 'CanvasItem'")
	if not _host:
		return

	if not _host.material:
		_host.material = material
	elif not (_host.material is ShaderMaterial):
		var context := {&"path": get_path()}
		_logger.warn("Parent has a non-shader material; hit flash disabled.", context)

		_host = null
		return

	# NOTE: Checked rather than assumed. Driving a parameter no shader declares is a
	# silent no-op: the call succeeds, the sprite never flashes, and nothing says why.
	var shader_material := _host.material as ShaderMaterial
	var shader := shader_material.shader if shader_material else null

	if not _declares_parameter(shader, PARAM_AMOUNT):
		var context := {&"path": get_path(), &"parameter": PARAM_AMOUNT}
		_logger.warn("Parent's shader lacks the flash uniform; disabled.", context)

		_host = null
		return

	_set_amount(0.0)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _declares_parameter reports whether `shader` declares `parameter` as an instance
## uniform.
##
## NOTE: Read from the source rather than from `Shader.get_shader_uniform_list`, which
## does not report instance uniforms at all. It answers an empty list for
## `flash.gdshader`, whose only two uniforms are exactly these.
static func _declares_parameter(shader: Shader, parameter: StringName) -> bool:
	if not shader:
		return false

	for line in shader.code.split("\n", false):
		var declaration := line.strip_edges()
		if not declaration.begins_with("instance uniform "):
			continue

		# The name is the fourth word, once the hint, default and terminator are gone:
		# `instance uniform <type> <name> : <hint> = <default>;`
		var words := declaration.replace(":", " ").replace("=", " ").replace(";", " ")
		var tokens := words.split(" ", false)

		if tokens.size() >= 4 and tokens[3] == String(parameter):
			return true

	return false


func _set_amount(value: float) -> void:
	if not _host or not is_instance_valid(_host):
		return

	_host.set_instance_shader_parameter(PARAM_AMOUNT, value)
