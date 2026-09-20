##
## Unit tests for `KitFeelLayer`. The three properties that are easy to get wrong and
## silent when they are - returning the camera to *exactly* rest, running at the same
## rate whatever the frame rate, and never stranding the engine's time scale - each have
## a test of their own.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const HIT_STOP_LIGHT := preload("hit_stop_light.tres")
const IMPULSE_EXPLOSION := preload("impulse_explosion.tres")
const IMPULSE_HIT := preload("impulse_hit.tres")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _camera: Camera2D = null
var _container: SubViewportContainer = null
var _feel: KitFeelLayer2D = null
var _map: KitMap2D = null
var _root: Control = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_impulse_moves_the_camera() -> void:
	# Given: A camera at rest.
	assert_eq(_camera.offset, Vector2.ZERO)

	# When: An impulse lands.
	_feel.impulse(IMPULSE_EXPLOSION)
	await wait_process_frames(2)

	# Then: The camera has been displaced.
	assert_ne(_camera.offset, Vector2.ZERO)
	assert_gt(_feel.get_trauma(), 0.0)


func test_impulse_returns_the_camera_to_exactly_its_rest_offset() -> void:
	# Given: A camera the game has offset for its own reasons, such as a look-ahead.
	_camera.offset = Vector2(37.0, -11.0)

	# When: An impulse lands and fully decays.
	_feel.impulse(IMPULSE_HIT)
	await wait_for_signal(_feel.impulse_finished, 5.0)

	# Then: The camera is back at the value it had, to the bit, rather than at zero or
	# at a fading remainder.
	assert_eq(_camera.offset, Vector2(37.0, -11.0))
	assert_eq(_feel.get_trauma(), 0.0)


func test_impulse_is_framerate_independent() -> void:
	# Given: Two identical impulses, stepped with different frame times.
	var coarse := _drain_trauma(1.0 / 30.0, 6)
	_feel.impulse(IMPULSE_EXPLOSION)
	var fine := _drain_trauma(1.0 / 120.0, 24)

	# When: Each has been stepped over the same elapsed time.
	# Then: The trauma left is the same, so the shake does not run faster on a faster
	# machine, which the common per-frame recipe gets wrong.
	assert_almost_eq(fine, coarse, 0.02)


func test_impulse_leaves_roll_alone_by_default() -> void:
	# Given: A camera with a rotation the game set.
	_camera.rotation = 0.25

	# When: An impulse with no roll lands.
	_feel.impulse(IMPULSE_HIT)
	await wait_process_frames(2)

	# Then: The rotation is untouched, since rolling unasked fights a camera controller.
	assert_eq(_camera.rotation, 0.25)


func test_intensity_scales_the_shake() -> void:
	# Given: A layer with shake turned off, the accessibility hook at its limit.
	_feel.intensity = 0.0

	# When: An impulse lands.
	_feel.impulse(IMPULSE_EXPLOSION)
	await wait_process_frames(2)

	# Then: The camera never moves.
	assert_eq(_camera.offset, Vector2.ZERO)


func test_kick_throws_the_camera_along_its_direction() -> void:
	# Given: A camera at rest.
	# When: An impulse arrives with a direction, and no shake to muddy the reading.
	var config := KitFeelImpulse.new()
	config.trauma = 0.0
	config.kick_strength = 20.0
	config.kick_decay = 1.0
	_feel.impulse(config, Vector2.LEFT)
	await wait_process_frames(2)

	# Then: The camera is thrown that way, which is what makes a hit read as coming from
	# somewhere rather than as generic rumble.
	assert_lt(_camera.offset.x, -1.0)
	assert_almost_eq(_camera.offset.y, 0.0, 0.001)


func test_kick_decays_back_to_rest() -> void:
	# Given: A kick with no shake behind it.
	var config := KitFeelImpulse.new()
	config.trauma = 0.0
	config.kick_strength = 20.0
	config.kick_decay = 30.0

	# When: It lands and is allowed to settle.
	_feel.impulse(config, Vector2.LEFT)
	await wait_for_signal(_feel.impulse_finished, 5.0)

	# Then: The camera is exactly back.
	assert_eq(_camera.offset, Vector2.ZERO)


func test_hit_stop_scales_and_restores_time() -> void:
	# Given: Normal time.
	assert_eq(Engine.time_scale, 1.0)

	# When: A hit-stop lands.
	_feel.hit_stop(HIT_STOP_LIGHT)

	# Then: Time is scaled down at once, and restored when it ends.
	assert_lt(Engine.time_scale, 1.0)
	assert_true(_feel.is_hit_stopped())

	await wait_for_signal(_feel.hit_stop_finished, 5.0)

	assert_eq(Engine.time_scale, 1.0)
	assert_false(_feel.is_hit_stopped())


func test_hit_stop_takes_the_longest_deadline() -> void:
	# Given: A long hit-stop in progress.
	var long_stop := KitFeelHitStop.new()
	long_stop.duration = 0.3
	long_stop.scale = 0.05
	_feel.hit_stop(long_stop)

	# When: A shorter one lands while it runs, as a combo hitting many targets does.
	_feel.hit_stop(HIT_STOP_LIGHT)

	# NOTE: A real-time wait. GUT's own is scaled by the very time scale under test, so
	# it would sleep for seconds and wake after the freeze it meant to interrupt.
	await get_tree().create_timer(0.15, true, false, true).timeout

	# Then: The shorter one has not released the freeze early.
	assert_true(_feel.is_hit_stopped())
	assert_lt(Engine.time_scale, 1.0)

	await wait_for_signal(_feel.hit_stop_finished, 5.0)
	assert_eq(Engine.time_scale, 1.0)


func test_hit_stop_restores_the_scale_it_found() -> void:
	# Given: A game already running fast-forward, as a catch-up driver would.
	Engine.time_scale = 3.0

	# When: A hit-stop lands and ends.
	_feel.hit_stop(HIT_STOP_LIGHT)
	await wait_for_signal(_feel.hit_stop_finished, 5.0)

	# Then: The fast-forward is given back, rather than being reset to normal speed.
	assert_eq(Engine.time_scale, 3.0)


func test_impulse_survives_the_layers_own_ready() -> void:
	# Given: A layer that has not entered the tree, so its `_ready` has not run. A map
	# readies its game world before its UI, so an entity placed in a map scene at author
	# time calls `impulse` from a `_ready` that lands in exactly this window.
	var layer := KitFeelLayer2D.new()
	layer.map = _map
	layer.camera = _camera
	assert_false(layer.is_node_ready())

	# When: An impulse lands, and only then is the layer mounted and readied.
	layer.impulse(IMPULSE_EXPLOSION)
	_map.add_child(layer)
	assert_true(layer.is_node_ready())

	# Then: The shake is still in flight rather than having been switched off by the
	# layer's own `_ready`, which would lose the impulse and never return the camera.
	assert_gt(layer.get_trauma(), 0.0)
	assert_true(layer.is_processing())

	await wait_for_signal(layer.impulse_finished, 5.0)
	assert_eq(_camera.offset, Vector2.ZERO)

	layer.queue_free()


func test_hit_stop_is_restored_when_the_map_is_paused() -> void:
	# Given: A hit-stop in progress.
	_feel.hit_stop(HIT_STOP_LIGHT)
	assert_lt(Engine.time_scale, 1.0)

	# When: The map is disabled mid-freeze, which is what `pause_when_covered` does when
	# the pause menu opens over it.
	_map.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_process_frames(2)

	# Then: The freeze is released rather than stranded by a layer that has stopped
	# processing, which would leave the pause menu itself running in slow motion.
	assert_eq(Engine.time_scale, 1.0)
	assert_false(_feel.is_hit_stopped())


func test_hit_stop_is_restored_when_the_layer_leaves() -> void:
	# Given: A hit-stop in progress.
	_feel.hit_stop(HIT_STOP_LIGHT)
	assert_lt(Engine.time_scale, 1.0)

	# When: The map is torn down mid-freeze, as a screen change would do.
	_feel.get_parent().remove_child(_feel)

	# Then: The whole game is not left in slow motion.
	assert_eq(Engine.time_scale, 1.0)

	_feel.free()
	_feel = null


func test_layer_without_a_map_warns_in_the_editor() -> void:
	# Given: A feel layer whose map was never wired, as a botched inherited scene has.
	var layer := KitFeelLayer2D.new()

	# When: The editor asks it for configuration warnings.
	var warnings: PackedStringArray = layer._get_configuration_warnings()

	# Then: It names the missing map. At runtime there is no camera to find and every
	# call quietly does nothing.
	assert_true("Missing property: 'map'" in warnings)

	layer.free()


func test_flash_rises_and_returns_to_transparent() -> void:
	# Given: A flash config.
	var config := KitFeelFlash.new()
	config.color = Color(1.0, 1.0, 1.0, 0.75)
	config.duration = 0.12

	# When: It plays.
	_feel.flash(config)
	var rect := _find_flash_rect()
	assert_not_null(rect)

	await wait_for_signal(_feel.flash_finished, 5.0)

	# Then: It has faded out completely, leaving nothing over the game.
	assert_almost_eq(rect.color.a, 0.0, 0.001)


func test_flash_covers_only_the_game_world() -> void:
	# Given: A map whose world occupies part of the window, as a pixel-art map letterboxed
	# inside a larger one does.
	_container.position = Vector2(100.0, 50.0)

	# When: A flash plays.
	_feel.flash(preload("flash_white.tres"))

	# Then: It covers the world's rect and not the letterbox around it.
	var rect := _find_flash_rect()
	assert_eq(rect.get_global_rect(), _map.get_screen_rect())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920, 1080)
	add_child_autofree(_root)

	_map = partial_double(KitMap2D).new()
	stub(_map, "_ready").to_do_nothing()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)
	_map.sub_viewport = _viewport

	_camera = Camera2D.new()
	_viewport.add_child(_camera)

	_feel = KitFeelLayer2D.new()
	_feel.map = _map
	_feel.camera = _camera
	_map.add_child(_feel)
	_map.feel = _feel


func after_each() -> void:
	# NOTE: The time scale is global, so a test that fails mid-freeze would otherwise
	# slow every test after it.
	Engine.time_scale = 1.0


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _drain_trauma steps the layer by hand for a fixed number of frames of a fixed length,
## and returns the trauma left, so two frame rates can be compared over equal time.
func _drain_trauma(step: float, frames: int) -> float:
	_feel.impulse(IMPULSE_EXPLOSION)

	for i in frames:
		_feel._process(step)

	var remaining := _feel.get_trauma()
	_feel._process(100.0)

	return remaining


## _find_flash_rect returns the layer's flash overlay, which it creates on first use.
func _find_flash_rect() -> ColorRect:
	for child in _feel.get_children():
		var rect := child as ColorRect
		if rect:
			return rect

	return null
