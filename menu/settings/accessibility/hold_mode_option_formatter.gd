##
## HoldModeOptionFormatter labels each `StdInputActionHold.Mode` in the hold mode row.
##

extends StdSettingsControllerOptionButtonFormatter

# -- DEFINITIONS --------------------------------------------------------------------- #

const MSGCTXT_HOLD_MODE := &"hold_mode"
const MSGID_HOLD_MODE_DEFAULT := &"kit_options_accessibility_hold_mode_default"
const MSGID_HOLD_MODE_HOLD := &"kit_options_accessibility_hold_mode_hold"
const MSGID_HOLD_MODE_TAP := &"kit_options_accessibility_hold_mode_tap"

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(mode: Variant) -> String:
	assert(mode is StdInputActionHold.Mode, "invalid argument; wrong type")

	var message_id: String = ""

	match mode:
		StdInputActionHold.MODE_INHERIT:
			message_id = MSGID_HOLD_MODE_DEFAULT
		StdInputActionHold.MODE_HOLD:
			message_id = MSGID_HOLD_MODE_HOLD
		StdInputActionHold.MODE_TOGGLE:
			message_id = MSGID_HOLD_MODE_TAP

	return tr(message_id, MSGCTXT_HOLD_MODE)
