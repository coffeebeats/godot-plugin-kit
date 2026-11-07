##
## Tests for the hold mode setting's options and the formatter which labels them.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const HoldModeOptionFormatter := preload("hold_mode_option_formatter.tres")
const HoldModeOptionsProperty := preload(
	"res://system/setting/controls/hold_mode_options_property.tres"
)

# -- TEST METHODS -------------------------------------------------------------------- #


func test_hold_mode_options_offer_every_mode() -> void:
	# When: The hold mode setting's options are read.
	var options: PackedInt64Array = HoldModeOptionsProperty.get_value()

	# Then: They offer every mode.
	#
	# NOTE: The option button asserts that the stored value is among its options.
	assert_eq(Array(options), StdInputActionHold.Mode.values())


func test_hold_mode_option_formatter_labels_each_mode_apart() -> void:
	# Given: Every mode the setting offers.
	var options: PackedInt64Array = HoldModeOptionsProperty.get_value()

	# When: Each is formatted into its label.
	var labels := {}
	for mode in options:
		labels[HoldModeOptionFormatter.format_option(mode)] = mode

	# Then: Each mode has a label of its own.
	assert_eq(labels.size(), options.size())

	# Then: No label is empty.
	assert_does_not_have(labels, "")
