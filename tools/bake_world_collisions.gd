extends SceneTree
# GLB·프로필에서 정적 충돌 자료를 저장한다. 편집 원본과 시각 모델은 수정하지 않는다.
const Section = preload("res://scripts/track/road_section.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const Collision = preload("res://scripts/physics/world_collision.gd")
const Data = preload("res://scripts/physics/world_collision_data.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const GeometryMap = preload("res://models/shared/world_geometry_map.gd")
const INPUTS := [
	"res://tools/bake_world_collisions.gd",
	"res://scripts/physics/world_collision.gd",
	"res://scripts/physics/world_collision_data.gd",
	"res://scripts/track/road_section.gd",
	"res://scripts/track/harbor_corridor.gd",
	"res://scripts/track/riviera_profile.gd",
	"res://scripts/track/route_library.gd",
	"res://scripts/track/circuit_runoff.gd",
	"res://scripts/rendering/world_assets.gd",
	"res://models/shared/scene_state.gd",
	"res://models/shared/world_geometry_map.gd",
	"res://models/shared/world_vegetation/references.json",
	"res://models/shared/render_primitives/model.glb",
]


func _initialize() -> void:
	call_deferred("run")


func inputs_for(road: Node3D) -> Dictionary:
	var paths: Array[String] = []
	paths.assign(INPUTS)
	paths.append_array([Assets.folder(road) + "model.tscn", Assets.folder(road) + "profile.tres"])
	for path in road.asset_paths:
		if path.begins_with(Assets.folder(road) + "assembly/") and not paths.has(path):
			paths.append(path)
	for node in Assets.nodes(road):
		if not (
			node == road.road_surface
			or node.name in ["RoadBase", "DirtShoulders"]
			or node.get_meta("world_ground", false)
			or node.get_meta("world_barrier", false)
		):
			continue
		var ref: String = node.get_meta("mesh_ref", "")
		if not ref.is_empty():
			var path := GeometryMap.resolve(ref).get_slice("#", 0)
			if not paths.has(path):
				paths.append(path)
	var hashes := {}
	paths.sort()
	for path in paths:
		if path.ends_with(".glb"):
			var config := ConfigFile.new()
			if config.load(path + ".import") != OK:
				push_error("GLB 가져오기 자료가 없습니다: " + path)
				return {}
			var imported: String = config.get_value("remap", "path", "")
			var stamp := FileAccess.get_file_as_string(imported.get_basename() + ".md5")
			if not stamp.contains('source_md5="%s"' % FileAccess.get_md5(path)):
				push_error("먼저 --headless --editor --import --quit으로 GLB를 가져오세요: " + path)
				return {}
		hashes[path] = FileAccess.get_sha256(path)
	return hashes


func run() -> void:
	Pool.acquire_owner()
	var count := 0
	var bytes := 0
	for id in DirAccess.get_directories_at("res://models/world"):
		if not FileAccess.file_exists("res://models/world/" + id + "/profile.tres"):
			continue
		var parts := id.split("_")
		var road: Node3D
		if parts[0] == "track":
			road = Section.new()
			road.closed_loop = true
			road.course_id = int(parts[1])
		else:
			road = Section.new(Vector3(0, 6, 0), -PI / 2, int(parts[1]), int(parts[2]), int(parts[3]) - 1)
		root.add_child(road)
		var inputs := inputs_for(road)
		if inputs.is_empty():
			push_error("충돌 자료 입력 목록을 읽지 못했습니다: " + id)
			road.free()
			Pool.release_owner()
			quit(1)
			return
		var path := Assets.folder(road) + "collision.res"
		var metadata_path := Assets.folder(road) + "collision.sources.json"
		var old: Variant = (
			JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
			if FileAccess.file_exists(metadata_path)
			else null
		)
		if (
			old is Dictionary
			and old.get("inputs") == inputs
			and FileAccess.file_exists(path)
			and old.get("sha256") == FileAccess.get_sha256(path)
		):
			road.free()
			count += 1
			continue
		var collision: Node3D = Collision.build(road, false)
		var data := Data.new()
		data.ground = collision.get_node("RoadSurfaceBody").get_child(0).shape
		data.barriers = collision.get_node("BarrierBody").get_child(0).shape
		data.ground_triangles = collision.get_meta("ground_triangles")
		data.barrier_triangles = collision.get_meta("barrier_triangles")
		assert(ResourceSaver.save(data, path, ResourceSaver.FLAG_COMPRESS) == OK)
		var metadata := {
			"schema": 1,
			"inputs": inputs,
			"sha256": FileAccess.get_sha256(path),
			"groundTriangles": data.ground_triangles,
			"barrierTriangles": data.barrier_triangles,
		}
		var file := FileAccess.open(metadata_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(metadata, "  ", true) + "\n")
		bytes += FileAccess.get_file_as_bytes(path).size()
		collision.free()
		road.free()
		count += 1
		print("정적 충돌 저장: ", id)
		await process_frame
	Pool.release_owner()
	print("정적 충돌 자료 ", count, "개 검증/생성, 새 파일 ", bytes, " bytes")
	quit()
