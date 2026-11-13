@tool
extends EditorExportPlugin
# ProjectSettings는 내보내기 중에만 바꾸며 project.godot에는 저장하지 않는다.
const KEYS := ["application/config/version", "application/config/build_number"]
var original: Dictionary = {}
var web_path := ""
var displayed_version := ""


func _get_name() -> String:
	return "AppBuildVersion"


func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true


func _export_begin(features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
	for key in KEYS:
		original[key] = ProjectSettings.get_setting(key)
	var name: String = str(ProjectSettings.get_setting(KEYS[0], "0.1"))
	var number := 0
	if features.has("android") or features.has("Android"):
		var preset := get_export_preset()
		var android_name: String = str(preset.get("version/name"))
		if not android_name.is_empty():
			name = android_name
		number = int(preset.get("version/code"))
	elif features.has("web") or features.has("Web"):
		var root := ProjectSettings.globalize_path("res://")
		var output: Array = []
		if OS.execute("git", ["-C", root, "rev-parse", "--short=7", "HEAD"], output, true) == 0:
			var revision: String = str(output[0]).strip_edges()
			if not revision.is_empty():
				name += "+" + revision
				var changes: Array = []
				if (
					OS.execute("git", ["-C", root, "status", "--porcelain"], changes, true) == 0
					and not str(changes[0]).strip_edges().is_empty()
				):
					name += ".dev"
		web_path = path if path.get_extension().to_lower() in ["html", "htm"] else ""
	ProjectSettings.set_setting(KEYS[0], name)
	ProjectSettings.set_setting(KEYS[1], number)
	displayed_version = preload("res://scripts/platform/app_version.gd").label()


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with("res://addons/app_version/"):
		skip()


func _export_end() -> void:
	for key in original:
		ProjectSettings.set_setting(key, original[key])
	original.clear()
	var path := web_path
	web_path = ""
	# 엔진 다운로드 전에도 실행될 HTML에 동일한 표시값을 넣는다.
	if not path.is_empty() and FileAccess.file_exists(path):
		var html := FileAccess.get_file_as_string(path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("웹 로딩 화면의 앱 버전을 기록하지 못했습니다: " + path)
			return
		file.store_string(html.replace("<!--app-version-->", displayed_version.xml_escape()))
		file.close()
		write_web_offline(path)


func write_web_offline(path: String) -> bool:
	var folder := path.get_base_dir()
	var stem := path.get_file().get_basename()
	var core: Array[String] = [
		path.get_file(),
		stem + ".js",
		stem + ".offline.html",
		stem + ".png",
		stem + ".icon.png",
		stem + ".apple-touch-icon.png",
		stem + ".manifest.json",
		stem + ".144x144.png",
		stem + ".180x180.png",
		stem + ".512x512.png",
		stem + ".audio.worklet.js",
		stem + ".audio.position.worklet.js",
	]
	var engine_files: Array[String] = [stem + ".wasm", stem + ".pck"]
	var template := FileAccess.get_file_as_string("res://web/offline_worker.js.in")
	var bridge := FileAccess.get_file_as_string("res://web/offline_bridge.js")
	if template.is_empty() or bridge.is_empty() or template.count("__INITIALSJ_OFFLINE_CONFIG__") != 1:
		push_error("오프라인 원본 템플릿을 확인하세요")
		return false
	# 미커밋 내보내기도 실제 게시 바이트가 바뀌면 새 캐시를 사용한다.
	var fingerprint := HashingContext.new()
	fingerprint.start(HashingContext.HASH_SHA256)
	fingerprint.update(template.to_utf8_buffer())
	fingerprint.update(bridge.to_utf8_buffer())
	# 순환 해시를 피하려고 HTML의 연결점은 버전을 넣기 전 상태로 해시한다.
	for name in core + engine_files:
		var source := folder.path_join(name)
		if not FileAccess.file_exists(source):
			push_error("내보내기 오프라인 파일 누락: " + source)
			return false
		fingerprint.update((name + ":" + FileAccess.get_sha256(source) + "\n").to_utf8_buffer())
	var version := fingerprint.finish().hex_encode()
	var config := {
		"version": version,
		"index": path.get_file(),
		"offline": stem + ".offline.html",
		"coreFiles": core,
		"engineFiles": engine_files,
		"isolation": bool(get_export_preset().get("progressive_web_app/ensure_cross_origin_isolation_headers")),
	}
	var html := FileAccess.get_file_as_string(path)
	if html.count("/*offline-bridge*/") != 1 or html.count("<!--offline-version-->") != 1:
		push_error("웹 셸의 오프라인 연결점을 확인하세요")
		return false
	html = html.replace("<!--offline-version-->", version).replace("/*offline-bridge*/", bridge)
	var html_file := FileAccess.open(path, FileAccess.WRITE)
	if html_file == null:
		push_error("오프라인 웹 셸을 기록하지 못했습니다: " + path)
		return false
	html_file.store_string(html)
	html_file.close()
	var worker_path := folder.path_join(stem + ".service.worker.js")
	var worker_file := FileAccess.open(worker_path, FileAccess.WRITE)
	if worker_file == null:
		push_error("오프라인 워커를 기록하지 못했습니다: " + worker_path)
		return false
	# 기본 엔진 워커를 문자열 패치하지 않고 정본에서 전체 파일을 생성한다.
	worker_file.store_string(template.replace("__INITIALSJ_OFFLINE_CONFIG__", JSON.stringify(config)))
	worker_file.close()
	return true
