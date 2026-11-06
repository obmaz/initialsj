extends RefCounted
# Test artifacts live under the ignored build directory, never source docs.
static func path(relative: String) -> String:
	var output := "res://build/reports/"+relative
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	assert(error == OK, "Cannot create test report directory: "+output.get_base_dir())
	return output
