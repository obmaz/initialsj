extends RefCounted
# 목록에는 경로만 보관한다. 곡을 추가할 때 재생 코드나 차량 음원은 수정하지 않는다.
const PATH := "res://assets/audio/music/catalog.json"


static func tracks(mode: String) -> Array[String]:
	var result: Array[String] = []
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not catalog is Dictionary or not catalog.get(mode) is Array:
		return result
	for path: Variant in catalog[mode]:
		if path is String and path.ends_with(".ogg") and not result.has(path):
			result.append(path)
	return result
