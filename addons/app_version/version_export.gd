@tool
extends EditorExportPlugin
# ProjectSettings는 내보내기 중에만 바꾸며 project.godot에는 저장하지 않는다.
const KEYS := ["application/config/version","application/config/build_number"]
var original: Dictionary = {}
var web_path := ""
var displayed_version := ""
func _get_name() -> String:
	return "AppBuildVersion"
func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true
func _export_begin(features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
	for key in KEYS: original[key] = ProjectSettings.get_setting(key)
	var name: String = str(ProjectSettings.get_setting(KEYS[0],"0.1"))
	var number := 0
	if features.has("android") or features.has("Android"):
		var preset := get_export_preset()
		var android_name: String = str(preset.get("version/name"))
		if not android_name.is_empty(): name = android_name
		number = int(preset.get("version/code"))
	elif features.has("web") or features.has("Web"):
		var root := ProjectSettings.globalize_path("res://")
		var output: Array = []
		if OS.execute("git",["-C",root,"rev-parse","--short=7","HEAD"],output,true) == 0:
			var revision: String = str(output[0]).strip_edges()
			if not revision.is_empty():
				name += "+"+revision
				var changes: Array = []
				if OS.execute("git",["-C",root,"status","--porcelain"],changes,true) == 0 and not str(changes[0]).strip_edges().is_empty(): name += ".dev"
		web_path = path if path.get_extension().to_lower() in ["html","htm"] else ""
	ProjectSettings.set_setting(KEYS[0],name)
	ProjectSettings.set_setting(KEYS[1],number)
	displayed_version = preload("res://scripts/app_version.gd").label()
func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with("res://addons/app_version/"): skip()
func _export_end() -> void:
	for key in original: ProjectSettings.set_setting(key,original[key])
	original.clear()
	var path := web_path
	web_path = ""
	# 엔진 다운로드 전에도 실행될 HTML에 동일한 표시값을 넣는다.
	if not path.is_empty() and FileAccess.file_exists(path):
		var html := FileAccess.get_file_as_string(path)
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file == null:
			push_error("웹 로딩 화면의 앱 버전을 기록하지 못했습니다: "+path)
			return
		file.store_string(html.replace("<!--app-version-->",displayed_version.xml_escape()))
