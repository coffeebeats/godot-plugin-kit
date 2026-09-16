##
## platform/error.gd
##
## A canonical error descriptor for both pending errors (enqueued before the UI exists)
## and runtime errors. The game drains the queue and decides how to present them.
##

class_name KitError
extends RefCounted

# -- DEFINITIONS --------------------------------------------------------------------- #

## Severity is a visual classification (icon, color, sound). Reserved for future use;
## does not drive dialog buttons.
enum Severity { WARNING, ERROR, CRITICAL }

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _pending: Array[KitError] = []

var message: String
var severity: Severity
var title: String

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## enqueue appends an error to the pending queue for later display.
static func enqueue(error: KitError) -> void:
	_pending.append(error)


## drain_pending returns all pending errors and clears the queue.
static func drain_pending() -> Array[KitError]:
	var errors := _pending
	_pending = []
	return errors


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(
	p_title: String,
	p_message: String,
	p_severity: Severity,
) -> void:
	title = p_title
	message = p_message
	severity = p_severity
