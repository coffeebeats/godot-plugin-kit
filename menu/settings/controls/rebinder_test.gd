##
## Tests for the rebinder's prompt, which splits a translated template around the
## placeholder its glyph replaces.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Rebinder := preload("rebinder.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_split_placeholder_separates_the_text_around_the_placeholder() -> void:
	# Given: A translated template carrying its placeholder.
	var template := "Press any key now or %s to cancel."

	# When: The template is split.
	var parts := Rebinder._split_placeholder(template)

	# Then: The text leading up to the glyph and the text following it are returned.
	assert_eq(parts, PackedStringArray(["Press any key now or ", " to cancel."]))


func test_split_placeholder_keeps_a_template_which_carries_no_placeholder() -> void:
	# Given: A template with no placeholder, as an untranslated message ID has.
	var template := "kit_options_controls_rebinder_bind_or_exit"

	# When: The template is split.
	var parts := Rebinder._split_placeholder(template)

	# Then: The whole template is kept, with an empty remainder.
	assert_eq(parts, PackedStringArray([template, ""]))
