##
## Splash implements a splash screen scene. It emits a signal when the splash advances,
## either by user input or after a timeout.
##

extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## advanced is emitted once when the splash advances (user input or timeout).
signal advanced

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set is the input action set loaded during the splash screen. All digital
## actions in it trigger advancement.
@export var action_set: StdInputActionSet = null

## player_id is the player whose input slot loads the action set.
@export var player_id: int = 1

@export_group("Duration")

## duration is the auto-advance timeout in seconds. Floored to 'duration_min'.
@export var duration: float = 3.0:
	set(value):
		duration = maxf(value, duration_min)

## duration_min is the minimum elapsed time before user input can advance the splash.
## Capped to 'duration'.
@export var duration_min: float = 0.5:
	set(value):
		duration_min = minf(value, duration)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _elapsed: float = 0.0
var _has_advanced: bool = false
var _has_skipped: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _gui_input(event: InputEvent) -> void:
	if _has_advanced or _has_skipped:
		return

	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		accept_event()

		_has_skipped = true
		if _elapsed >= duration_min:
			_advance()


func _process(delta: float) -> void:
	_elapsed += delta

	if _has_skipped and _elapsed >= duration_min:
		_advance()


func _ready() -> void:
	assert(action_set is StdInputActionSet, "invalid config; missing action set")

	var slot := StdInputSlot.for_player(player_id)
	if slot:
		slot.load_action_set(action_set)

	get_tree().create_timer(duration).timeout.connect(_advance)


func _unhandled_input(event: InputEvent) -> void:
	if _has_advanced or _has_skipped:
		return

	if not action_set:
		assert(false, "invalid state; missing action set")
		return

	for action in action_set.actions_digital:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()

			_has_skipped = true
			if _elapsed >= duration_min:
				_advance()
				return


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _advance() -> void:
	if _has_advanced:
		return

	set_process_unhandled_input(false)
	set_process(false)

	_has_advanced = true
	advanced.emit()
