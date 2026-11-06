extends SceneTree
func _initialize() -> void:
	var version := Engine.get_version_info()
	var pinned := FileAccess.get_file_as_string("res://.godot-version").strip_edges()
	var actual := "%d.%d.%d" % [version.major,version.minor,version.patch]
	var correct := actual == pinned
	print("Engine version: ",version.string," / pinned ",pinned)
	if not correct: push_error("This project requires Godot "+pinned)
	quit(0 if correct else 1)
