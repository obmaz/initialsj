extends RefCounted


# APK는 Android 프리셋, 웹은 프로젝트 버전+소스 커밋을 내보내기 때 기록한다.
static func label() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "0.1"))
	var number: int = int(ProjectSettings.get_setting("application/config/build_number", 0))
	return "v%s (%d)" % [version, number] if number > 0 else "v" + version
