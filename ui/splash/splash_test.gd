##
## Unit tests for the splash screen script.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Splash := preload("splash.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _splash: Control = null
var _sender: GutInputSender = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_duration_setter_floors_to_duration_min() -> void:
	# Given: A splash screen with duration_min set to 2.0.
	_splash.duration_min = 2.0

	# When: Duration is set to 1.0, below duration_min.
	_splash.duration = 1.0

	# Then: Duration is clamped to duration_min.
	assert_eq(_splash.duration, 2.0)


func test_duration_min_setter_caps_to_duration() -> void:
	# Given: A splash screen with duration set to 2.0.
	_splash.duration = 2.0

	# When: Duration_min is set to 5.0, above duration.
	_splash.duration_min = 5.0

	# Then: Duration_min is capped to the current duration.
	assert_eq(_splash.duration_min, 2.0)


func test_setters_accept_valid_values() -> void:
	# Given/When: Duration_min and duration are set to valid, compatible values.
	_splash.duration_min = 1.0
	_splash.duration = 3.0

	# Then: Both values are accepted as-is.
	assert_eq(_splash.duration_min, 1.0)
	assert_eq(_splash.duration, 3.0)


func test_advance_emits_signal() -> void:
	# Given: A splash screen with watched signals.
	watch_signals(_splash)

	# When: The splash screen is advanced.
	_splash._advance()

	# Then: The "advanced" signal is emitted.
	assert_signal_emitted(_splash, "advanced")


func test_advance_only_fires_once() -> void:
	# Given: A splash screen with watched signals.
	watch_signals(_splash)

	# When: The splash screen is advanced twice.
	_splash._advance()
	_splash._advance()

	# Then: The "advanced" signal is emitted only once.
	assert_signal_emit_count(_splash, "advanced", 1)


func test_gui_input_left_click_advances() -> void:
	# Given: A splash screen with elapsed time past duration_min.
	_splash._elapsed = 1.0
	watch_signals(_splash)

	# When: A left mouse click is received.
	_sender.mouse_left_button_down()

	# Then: The "advanced" signal is emitted.
	assert_signal_emitted(_splash, "advanced")


func test_gui_input_right_click_ignored() -> void:
	# Given: A splash screen with watched signals.
	watch_signals(_splash)

	# When: A right mouse click is received.
	_sender.mouse_right_button_down()

	# Then: The "advanced" signal is not emitted.
	assert_signal_not_emitted(_splash, "advanced")


func test_input_action_press_advances() -> void:
	# Given: A splash screen with elapsed time past duration_min.
	_splash._elapsed = 1.0
	watch_signals(_splash)

	# When: The "ui_accept" action is pressed.
	_sender.action_down("ui_accept")

	# Then: The "advanced" signal is emitted.
	assert_signal_emitted(_splash, "advanced")


func test_input_blocked_before_duration_min() -> void:
	# Given: A splash screen with elapsed time below duration_min.
	_splash.duration = 10.0
	_splash.duration_min = 5.0
	_splash._elapsed = 0.0
	watch_signals(_splash)

	# When: The "ui_accept" action is pressed.
	_sender.action_down("ui_accept")

	# Then: The "advanced" signal is not emitted.
	assert_signal_not_emitted(_splash, "advanced")


func test_input_allowed_after_duration_min() -> void:
	# Given: A splash screen with elapsed time past duration_min.
	_splash.duration_min = 1.0
	_splash.duration = 10.0
	_splash._elapsed = 2.0
	watch_signals(_splash)

	# When: The "ui_accept" action is pressed.
	_sender.action_down("ui_accept")

	# Then: The "advanced" signal is emitted.
	assert_signal_emitted(_splash, "advanced")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	_sender = null


func before_each() -> void:
	_splash = partial_double(Splash).new()
	stub(_splash, "_ready").to_do_nothing()

	var action_set := StdInputActionSet.new()
	action_set.actions_digital = [&"ui_accept", &"ui_cancel"]
	_splash.action_set = action_set

	add_child_autofree(_splash)

	_splash.set_process(false)

	_sender = GutInputSender.new(_splash)
