##
## ButtonPromptOptionFormatter is a type which describes how to format a device type
## enum value into a label.
##

extends StdSettingsControllerOptionButtonFormatter

# -- DEFINITIONS --------------------------------------------------------------------- #

const MSGCTXT_BUTTON_PROMPT := &"button_prompt"
const MSGID_BUTTON_PROMPT_AUTO := &"kit_options_controls_button_prompt_auto"
const MSGID_BUTTON_PROMPT_KBM := &"kit_options_controls_button_prompt_kbm"
const MSGID_BUTTON_PROMPT_XBOX := &"kit_options_controls_button_prompt_xbox"
const MSGID_BUTTON_PROMPT_PS := &"kit_options_controls_button_prompt_ps"
const MSGID_BUTTON_PROMPT_SWITCH := &"kit_options_controls_button_prompt_switch"
const MSGID_BUTTON_PROMPT_STEAM := &"kit_options_controls_button_prompt_steam"

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(device_type: Variant) -> String:
	assert(device_type is StdInputDevice.DeviceType, "invalid argument; wrong type")

	var message_id: String = ""

	match device_type:
		StdInputDevice.DEVICE_TYPE_UNKNOWN:
			message_id = MSGID_BUTTON_PROMPT_AUTO
		StdInputDevice.DEVICE_TYPE_KEYBOARD:
			message_id = MSGID_BUTTON_PROMPT_KBM
		StdInputDevice.DEVICE_TYPE_XBOX_ONE:
			message_id = MSGID_BUTTON_PROMPT_XBOX
		StdInputDevice.DEVICE_TYPE_PS_5:
			message_id = MSGID_BUTTON_PROMPT_PS
		StdInputDevice.DEVICE_TYPE_SWITCH_PRO:
			message_id = MSGID_BUTTON_PROMPT_SWITCH
		StdInputDevice.DEVICE_TYPE_STEAM_DECK:
			message_id = MSGID_BUTTON_PROMPT_STEAM

	return tr(message_id, MSGCTXT_BUTTON_PROMPT)
