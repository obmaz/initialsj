extends RefCounted
# 팩 추가는 해당 폴더의 definition.tres만으로 끝난다. 중앙 등록표를 수정하지 않는다.
const ROOTS := {
	"props":"res://models/props",
	"vegetation":"res://models/vegetation",
	"vehicles":"res://models/vehicles",
	"buildings":"res://models/buildings"
}
static var definitions: Dictionary = {}
static var ordered: Dictionary = {}
static var errors: Array[String] = []

static func all(category: String) -> Array[Resource]:
	if not definitions.has(category):
		var found: Dictionary = {}
		var directory: String = ROOTS[category]
		for entry in ResourceLoader.list_directory(directory):
			if not entry.ends_with("/"): continue
			var path := directory.path_join(entry).path_join("definition.tres")
			if not ResourceLoader.exists(path): continue
			var item: Resource = load(path)
			if item == null or item.get_script() != preload("res://models/model_definition.gd"):
				errors.append("모델 정의를 읽을 수 없다: "+path)
				continue
			if item.contract_version != 1 or item.id != entry.trim_suffix("/") or item.category != category or found.has(item.id):
				errors.append("모델 계약·폴더·ID·분류가 일치하지 않는다: "+path)
				continue
			found[item.id] = item
		definitions[category] = found
		var result: Array[Resource] = []
		result.assign(found.values())
		result.sort_custom(func(a: Resource,b: Resource): return a.order < b.order if a.order != b.order else a.id < b.id)
		result.make_read_only()
		ordered[category] = result
	return ordered[category]

static func find(category: String, id: String) -> Resource:
	all(category)
	return definitions[category].get(id)
