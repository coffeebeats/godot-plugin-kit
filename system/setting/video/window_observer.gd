##
## WindowObserver is a `StdSettingsObserver` which handles changing the window mode and
## other window-related properties.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## fullscreen_property is a settings property for fullscreen mode.
@export var fullscreen_property: StdSettingsPropertyBool = null

## borderless_property is a settings property for borderless windows.
@export var borderless_property: StdSettingsPropertyBool = null

@export_category("Window")

## window_mode_property is a settings property for the project's explicit window mode.
##
## NOTE: This must be synced to project settings to work.
@export var window_mode_property: StdSettingsPropertyInt = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_resizable: bool = ProjectSettings.get_setting_with_override(
	&"display/window/size/resizable"
)

var _window_mode: Window.Mode = ProjectSettings.get_setting_with_override(
	&"display/window/size/mode"
)

var _logger := StdLogger.create(&"system/setting/window")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func set_borderless(value: bool, window_id: int = 0) -> void:
	_logger.debug("Updating window borderless state.", {&"state": value})

	(
		DisplayServer
		. window_set_flag(
			DisplayServer.WINDOW_FLAG_BORDERLESS,
			value,
			window_id,
		)
	)


func set_fullscreen(value: bool) -> void:
	var window := get_window()
	var window_id := window.get_window_id()

	var mode: Window.Mode = Window.MODE_FULLSCREEN if value else Window.MODE_WINDOWED

	# NOTE: Always save the window's current mode, in case window-level controls drove
	# the change instead of the settings UI.
	_save_window_mode(window.mode)

	# No change required, but some reconciliation is required if this change was driven
	# by window-level controls.
	if value == (window.mode >= Window.MODE_FULLSCREEN):
		call_deferred(&"_update_borderless")
		return

	_logger.debug("Updating window mode.", {&"mode": mode})

	if value:
		_logger.debug("Entering fullscreen mode.")

		# FIXME: On macOS, after entering fullscreen with borderless enabled, disabling
		# borderless and the exiting fullscreen causes the title bar to be inaccessible.
		# As a workaround, disable borderless prior to entering fullscreen (it will be
		# set correctly after exiting fullscreen anyway).
		if KitFeature.is_macos_platform():
			call_deferred(&"set_borderless", false, window_id)

		call_deferred(&"_set_window_mode", mode, window_id)

	else:
		_logger.debug("Exiting fullscreen mode.")

		# FIXME: On macOS, when exiting fullscreen with resizable enabled, the window
		# shrinks to a zero size. To fix, disable resize before exiting fullscreen.
		if KitFeature.is_macos_platform():
			call_deferred(&"_set_resizable", false, window_id)

		call_deferred(&"_set_window_mode", mode, window_id)
		call_deferred(&"_shrink_window", window_id)
		call_deferred(&"_update_borderless")
		call_deferred(&"_center_window", window_id)

		if KitFeature.is_macos_platform() and _is_resizable:
			call_deferred(&"_set_resizable", true, window_id)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	var window: Window = get_window()

	if window.mode != _window_mode:
		_handle_window_mode_change(window)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [fullscreen_property, borderless_property]


func _handle_value_change(property: StdSettingsProperty, value: Variant) -> void:
	if property == fullscreen_property:
		assert(fullscreen_property, "invalid state: missing property")
		assert(window_mode_property, "invalid state: missing property")

		set_fullscreen(value)

	if property == borderless_property:
		assert(borderless_property, "invalid state: missing property")

		set_borderless(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _center_window(window_id: int = 0) -> void:
	var size_screen := DisplayServer.screen_get_size()
	var size_window := DisplayServer.window_get_size_with_decorations(window_id)
	var size_title := _get_title_size(window_id)

	_logger.debug("Centering window.")

	(
		DisplayServer
		. window_set_position(
			(
				Vector2i((size_screen / 2.0 - size_window / 2.0).round())
				+ Vector2i(0, size_title.y)
			),
			window_id,
		)
	)


func _get_title_size(window_id: int = 0) -> Vector2i:
	var title := (
		DisplayServer
		. window_get_title_size(
			ProjectSettings.get_setting_with_override("application/config/name"),
			window_id,
		)
	)

	return Vector2i(0, title.y)


func _handle_window_mode_change(window: Window) -> void:
	var window_mode_prev := _window_mode
	_window_mode = window.mode

	if window.mode == window_mode_prev:
		return

	(
		_logger
		. debug(
			"Detected change in window mode.",
			{&"previous": window_mode_prev, &"next": window.mode},
		)
	)

	if not fullscreen_property.set_value(window.mode >= Window.MODE_FULLSCREEN):
		_update_fullscreen()


func _save_window_mode(mode: Window.Mode) -> void:
	assert(
		window_mode_property is StdSettingsPropertyInt,
		"invalid state; missing property"
	)

	window_mode_property.set_value(mode)


func _set_resizable(value: bool, window_id: int = 0) -> void:
	(
		DisplayServer
		. window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			not value,
			window_id,
		)
	)


func _set_window_mode(mode: DisplayServer.WindowMode, window_id: int = 0) -> void:
	if mode == DisplayServer.window_get_mode(window_id):
		return

	_window_mode = mode as Window.Mode
	DisplayServer.window_set_mode(mode, window_id)

	_save_window_mode(mode as Window.Mode)


func _shrink_window(window_id: int = 0) -> void:
	var size := DisplayServer.get_display_safe_area().size / 2.0
	if Vector2i(size.round()) == DisplayServer.window_get_size(window_id):
		return

	DisplayServer.window_set_size(size, window_id)


func _update_borderless() -> void:
	var is_borderless: bool = borderless_property.get_value()
	borderless_property.value_changed.emit(is_borderless)


func _update_fullscreen() -> void:
	var is_fullscreen: bool = fullscreen_property.get_value()
	fullscreen_property.value_changed.emit(is_fullscreen)
