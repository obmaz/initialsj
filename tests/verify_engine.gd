extends SceneTree


func _initialize() -> void:
	var version := Engine.get_version_info()
	var pinned := FileAccess.get_file_as_string("res://.godot-version").strip_edges()
	var actual := "%d.%d.%d" % [version.major, version.minor, version.patch]
	# A release candidate or dev build of the pinned number is a different engine.
	var correct: bool = actual == pinned and version.status == "stable"
	print("Engine version: ", version.string, " / pinned ", pinned)
	if not correct:
		push_error("This project requires Godot " + pinned + " stable")
	quit(0 if correct else 1)
