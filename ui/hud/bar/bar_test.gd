##
## Unit tests for `KitHudBar`, which owns the trailing ghost behavior entirely; the HUD
## layer neither knows nor routes it.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const BAR := preload("bar.tscn")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _bar: KitHudBar = null
var _fill: ProgressBar = null
var _ghost: ProgressBar = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_a_bar_never_told_a_value_reads_full() -> void:
	# Given: A bar mounted for an entity that has not been damaged yet, so `set_value`
	# has never been called.
	# When: It is looked at.
	# Then: It reads full. An empty bar would say the entity is dead.
	assert_eq(_fill.value, _fill.max_value)
	assert_eq(_bar.get_value(), _bar.get_max_value())


func test_set_value_moves_the_fill_at_once() -> void:
	# Given: A full bar.
	_bar.set_value(10.0, 10.0)
	# When: It takes damage.
	_bar.set_value(6.0, 10.0)
	# Then: The fill is already at the new value, with no animation to wait on.
	assert_eq(_fill.value, 6.0)
	assert_eq(_fill.max_value, 10.0)


func test_ghost_holds_at_the_previous_value_after_a_loss() -> void:
	# Given: A full bar.
	_bar.set_value(10.0, 10.0)
	# When: It takes damage.
	_bar.set_value(6.0, 10.0)
	# Then: The ghost stays behind, which is what reads as the damage taken.
	assert_eq(_ghost.value, 10.0)


func test_ghost_drains_to_the_value() -> void:
	# Given: A bar whose style drains immediately, so the test does not wait on timing.
	_bar.style = _make_instant_style()
	_bar.set_value(10.0, 10.0)
	# When: It takes damage and the drain runs.
	_bar.set_value(6.0, 10.0)
	await wait_process_frames(2)
	# Then: The ghost has caught up with the fill.
	assert_almost_eq(_ghost.value, 6.0, 0.001)


func test_ghost_snaps_on_a_gain() -> void:
	# Given: A bar with a trailing ghost from earlier damage.
	_bar.set_value(10.0, 10.0)
	_bar.set_value(4.0, 10.0)
	assert_eq(_ghost.value, 10.0)
	# When: The value goes back up.
	_bar.set_value(8.0, 10.0)
	# Then: The ghost snaps to it rather than draining down through it.
	assert_eq(_ghost.value, 8.0)


func test_repeated_damage_extends_one_trail() -> void:
	# Given: A bar that has taken damage and is holding a ghost at full.
	_bar.set_value(10.0, 10.0)
	_bar.set_value(7.0, 10.0)
	# When: It is hit again before the ghost drains.
	_bar.set_value(3.0, 10.0)
	# Then: The ghost still shows the original value, so the two hits read as one trail
	# rather than restarting.
	assert_eq(_ghost.value, 10.0)
	assert_eq(_fill.value, 3.0)


func test_value_set_before_ready_is_applied() -> void:
	# Given: A bar that is not yet in the tree, which is what a group looks like between
	# instantiation and mounting.
	var bar: KitHudBar = BAR.instantiate()
	# When: A value is set and the bar then enters the tree.
	bar.set_value(3.0, 12.0)
	add_child_autofree(bar)
	# Then: The value is there, rather than silently lost.
	var fill: ProgressBar = bar.get_node("Fill")
	assert_eq(fill.value, 3.0)
	assert_eq(fill.max_value, 12.0)
	assert_eq(bar.get_value(), 3.0)
	assert_eq(bar.get_max_value(), 12.0)


func test_hide_at_full_hides_an_undamaged_bar() -> void:
	# Given: A bar styled to hide while undamaged.
	var style := _make_instant_style()
	style.hide_at_full = true
	_bar.style = style
	# When: It is at full.
	_bar.set_value(10.0, 10.0)
	# Then: It is hidden, and shows again once damaged.
	assert_false(_bar.visible)

	_bar.set_value(9.0, 10.0)
	assert_true(_bar.visible)


func test_value_is_clamped_to_the_maximum() -> void:
	# Given: A bar.
	# When: A value beyond the maximum is set.
	_bar.set_value(50.0, 10.0)
	# Then: It is clamped, so the fill cannot overrun its own bar.
	assert_eq(_bar.get_value(), 10.0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_bar = BAR.instantiate()
	add_child_autofree(_bar)

	_fill = _bar.get_node("Fill")
	_ghost = _bar.get_node("Ghost")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_instant_style returns a style whose ghost drains with no hold and no duration,
## so a test asserts the end state without waiting on real time.
func _make_instant_style() -> KitHudBarStyle:
	var curve := StdTweenCurve.new()
	curve.delay = 0.0
	curve.duration = 0.0

	var style := KitHudBarStyle.new()
	style.drain = curve

	return style
