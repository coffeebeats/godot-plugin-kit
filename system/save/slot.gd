##
## KitSaveSlot defines metadata about a single save slot.
##

class_name KitSaveSlot
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## changed is emitted whenever the status or save summary for this slot are modified.
signal changed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const STATUS_BROKEN := StdSaveFile.STATUS_BROKEN
const STATUS_EMPTY := StdSaveFile.STATUS_EMPTY
const STATUS_OK := StdSaveFile.STATUS_OK
const STATUS_UNKNOWN := StdSaveFile.STATUS_UNKNOWN

# -- CONFIGURATION ------------------------------------------------------------------- #

## status is the current status of the corresponding save slot.
var status: StdSaveFile.Status = STATUS_UNKNOWN:
	set(value):
		var should_emit := status != value
		status = value
		if should_emit:
			changed.emit()

## summary is a summary of the save data associated with this save slot. Note that this
## may be present even if the save slot is empty (though the corresponding properties
## would be set to their default values).
##
## NOTE: This property will only emit the `changed` signal upon reassignment. Changes to
## the underlying summary need to be manually broadcast.
var summary: StdSaveSummary = null:
	set(value):
		var should_emit := summary != value
		summary = value
		if should_emit:
			changed.emit()
