extends RefCounted
# 코스의 편집용 노드 이름을 유지하면서 배포 형상만 공통 식생으로 연결한다.
const PATH := "res://models/shared/world_vegetation/references.json"
static var manifest: Dictionary = {}
static var modified := 0


static func data() -> Dictionary:
	var stamp := FileAccess.get_modified_time(PATH) if Engine.is_editor_hint() else 0
	if manifest.is_empty() or stamp != modified:
		manifest = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		assert(manifest.get("schema") == 1, "공통 식생 연결 자료를 재생성하세요")
		modified = stamp
	return manifest


static func resolve(ref: String) -> String:
	return data().references.get(ref, ref)


static func scene(path: String) -> String:
	return data().scenes.get(path, path)


static func shared(path: String) -> bool:
	return data().scenes.has(path)


static func dependencies(paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for path in paths:
		for entry in data().dependencies.get(path, [path]):
			if not result.has(entry):
				result.append(entry)
	return result


static func clear() -> void:
	manifest.clear()
	modified = 0


# 임베디드 재질의 서로 다른 인스턴스 ID 대신 실제 저장 속성을 비교한다.
# 재질 슬롯별 색·텍스처·양면 설정이 다르면 같은 형상에도 독립 메시 바인딩을 사용한다.
static func material_key(materials: Array) -> String:
	var values: Array = []
	for material: Material in materials:
		var fields := {}
		for property in material.get_property_list():
			var name: String = property.name
			if (property.usage & PROPERTY_USAGE_STORAGE) == 0 or name.begins_with("resource_") or name == "script":
				continue
			var value: Variant = material.get(name)
			if value is Resource:
				# 경로 없는 전용 자원은 다른 개체와 섣불리 합치지 않는다.
				value = value.resource_path if not value.resource_path.is_empty() else value.get_instance_id()
			fields[name] = value
		values.append(fields)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(values))
	return digest.finish().hex_encode()
