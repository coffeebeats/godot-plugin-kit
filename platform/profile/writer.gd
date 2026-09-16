##
## platform/profile/config_writer.gd
##
## ProfileConfigWriter is a `StdConfigWriterBinary` subclass that resolves the
## configured `path` relative to the current user profile's directory.
##

extends StdConfigWriterBinary

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_filepath() -> String:
	var path_rel := path.trim_prefix("profile://")

	if path_rel.is_absolute_path():
		assert(false, "invalid config; expected relative path")
		return ""

	var profile := Platform.get_user_profile()
	if not profile:
		return ""

	return ("user://profiles/%s" % profile.id).path_join(path_rel)
