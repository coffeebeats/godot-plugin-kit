##
## Tests for the cursor confinement property, which follows fullscreen until the player
## sets it.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const CursorConfinedProperty := preload("cursor_confined_property.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _confined: CursorConfinedProperty = null
var _fullscreen: StdSettingsPropertyBool = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_cursor_confined_unset_follows_fullscreen() -> void:
	# Given: The game is fullscreen, and the player never set confinement.
	assert_true(_fullscreen.get_value(), "precondition")

	# Then: The cursor is confined.
	assert_true(_confined.get_value())

	# When: The game leaves fullscreen.
	watch_signals(_confined)
	_fullscreen.set_value(false)

	# Then: The cursor is free, and its observers hear so.
	assert_false(_confined.get_value())
	assert_signal_emitted_with_parameters(_confined, "value_changed", [false])


func test_cursor_confined_set_holds_across_fullscreen_changes() -> void:
	# Given: The game is fullscreen, and the player confines the cursor.
	assert_true(_fullscreen.get_value(), "precondition")
	_confined.set_value(true)

	# When: The game leaves fullscreen.
	watch_signals(_confined)
	_fullscreen.set_value(false)

	# Then: The cursor stays confined, and its observers hear nothing.
	assert_true(_confined.get_value())
	assert_signal_not_emitted(_confined, "value_changed")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	var scope := StdSettingsScope.new()

	_fullscreen = StdSettingsPropertyBool.new()
	_fullscreen.category = &"display"
	_fullscreen.name = &"fullscreen"
	_fullscreen.default = true
	_fullscreen.scope = scope

	_confined = CursorConfinedProperty.new()
	_confined.category = &"controls"
	_confined.name = &"cursor/confined"
	_confined.scope = scope
	_confined.fullscreen = _fullscreen
