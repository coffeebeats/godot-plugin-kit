##
## FontScalingObserver is a `StdSettingsObserver` that handles scaling the default font
## size and the specified list of theme type variations.
##

extends StdSettingsObserver

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Debounce := preload("res://addons/std/timer/debounce.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const PROPERTY_FONT_SIZE := &"font_size"

# -- CONFIGURATION ------------------------------------------------------------------- #

## font_scaling_property is a settings property defining the font scaling value.
@export var font_scaling_property: StdSettingsPropertyFloatRange = null

## debounce is a debounce timer node which is used to prevent scaling the text size
## until the user has paused updating the target value.
@export var debounce: Debounce = null

@export_subgroup("Theme ")

## theme is a theme resource which will have its font size scaled.
@export var theme: Theme = null

## theme_types is a list of theme types which should have their font size scaled (in
## addition to the default font size).
@export var theme_types := PackedStringArray()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _font_size_default: int = 0
var _font_sizes: Dictionary = {}
var _logger := StdLogger.create(&"system/setting/interface")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(debounce is Debounce, "invalid config; missing debounce timer")
	Signals.connect_safe(debounce.timeout, _on_debounce_timeout)

	# NOTE: The theme is the game's to supply. With none there is nothing to scale,
	# which is a configuration rather than a fault.
	if not theme:
		return

	_font_size_default = theme.default_font_size
	assert(_font_size_default, "invalid state; missing base font size")

	for theme_type in theme_types:
		if not theme.has_font_size(PROPERTY_FONT_SIZE, theme_type):
			continue

		_font_sizes[theme_type] = theme.get_font_size(PROPERTY_FONT_SIZE, theme_type)

	# NOTE: Call this *after* initializing default font sizes, otherwise values on theme
	# will be scaled using a base value of `0`.
	super._ready()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(
		font_scaling_property is StdSettingsPropertyFloatRange,
		"invalid config: missing property"
	)

	return [font_scaling_property]


func _handle_value_change(property: StdSettingsProperty, _value: float) -> void:
	if property == font_scaling_property:
		debounce.start()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _scale_font_sizes(scalar: float) -> void:
	_logger.debug("Updating font scale.", {&"scale": scalar})

	var size := int(_font_size_default * scalar)

	theme.default_font_size = size

	for theme_type: String in _font_sizes:
		size = int(_font_sizes[theme_type] * scalar)
		theme.set_font_size(PROPERTY_FONT_SIZE, theme_type, size)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_debounce_timeout() -> void:
	_scale_font_sizes(font_scaling_property.get_value())
