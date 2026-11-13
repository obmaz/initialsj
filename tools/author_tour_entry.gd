extends SceneTree
# 기존 GLB를 보존하고 고정 진입 연결부와 콘텐츠 변환을 주행 프로필에 기록한다.
const RUNUP := preload("res://scripts/track/route_library.gd").ENTRY_RUNUP
const TURN := .06
const CONNECTOR_FOLDER := "res://models/shared/tour_entry/"
var entries := {}


func _initialize() -> void:
	call_deferred("run")


func prefix(side: int, end_x: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = .5
	curve.up_vector_enabled = false
	var end := Vector3(end_x, 6, side * 4.0)
	var forward := Basis(Vector3.UP, side * TURN) * Vector3.RIGHT
	var a := Vector3(0, 6, 0)
	var b := Vector3(end_x / 3, 6, 0)
	var c := end - forward * end_x / 3
	curve.add_point(a, Vector3.ZERO, b - a)
	curve.add_point(end, c - end, Vector3.ZERO)
	return curve


func entry(side: int) -> Dictionary:
	var lo := RUNUP * .95
	var hi := RUNUP + .1
	for i in range(22):
		var middle := (lo + hi) * .5
		if prefix(side, middle).get_baked_length() > RUNUP:
			hi = middle
		else:
			lo = middle
	var curve := prefix(side, (lo + hi) * .5)
	var end := curve.get_point_position(curve.point_count - 1)
	var basis := Basis(Vector3.UP, side * TURN)
	return {"curve": curve, "content": Transform3D(basis, end - basis * Vector3(0, 6, 0))}


func shift_profile(data: Dictionary, offset: float) -> void:
	for feature in data.features:
		feature.distance += offset
	for field in ["skyway_spans"]:
		for i in range(data[field].size()):
			data[field][i] += Vector2.ONE * offset


# 기본 진입 길이가 0이면 원래 씬의 중심선으로 복구한다. 편집 원본·GLB는 건드리지 않는다.
func restore(profile: Resource, saved: Dictionary, path: String) -> void:
	var offset: float = profile.get_meta("entry_buffer_length", 0.0)
	if offset <= 0:
		return
	var source: Dictionary = profile.get_meta("profile").duplicate(true)
	source.curve = saved.curve.duplicate()
	source.length = source.curve.get_baked_length()
	shift_profile(source, -offset)
	profile.set_meta("profile", source)
	var tunnel: Vector2 = profile.get_meta("tour_underpass", Vector2.ZERO)
	if tunnel.y > tunnel.x:
		profile.set_meta("tour_underpass", tunnel - Vector2.ONE * offset)
	var caches := {}
	for field in ["_steep_cache", "_pinch_cache", "_gimmicks_ready"]:
		caches[field] = saved[field]
	profile.set_meta("entry_gimmick_state", caches)
	for key in ["entry_buffer_length", "entry_content_transform", "entry_scene_path"]:
		profile.remove_meta(key)
	var paths: Array[String] = profile.get_meta("dependencies")
	for dependency in paths.duplicate():
		if dependency.begins_with(CONNECTOR_FOLDER):
			paths.erase(dependency)
	profile.set_meta("dependencies", paths)
	ResourceSaver.save(profile, path)
	print("TOUR_ENTRY_RESTORE ", path)


func run() -> void:
	var exported := {}
	for side in [-1, 0, 1] if RUNUP > 0 else []:
		entries[side] = entry(side)
		var curve: Curve3D = entries[side].curve
		var points := []
		for i in range(241):
			var p := curve.sample_baked(curve.get_baked_length() * i / 240.0) - Vector3.UP * 6
			points.append([p.x, p.y, p.z])
		exported[str(side)] = {"points": points, "length": curve.get_baked_length()}
	if RUNUP > 0:
		DirAccess.make_dir_recursive_absolute("res://build/reports/tour-entry")
		FileAccess.open("res://build/reports/tour-entry/curves.json", FileAccess.WRITE).store_string(
			JSON.stringify(exported)
		)
	for id in DirAccess.get_directories_at("res://models/world"):
		if not id.begins_with("tour_"):
			continue
		var parts := id.split("_")
		if int(parts[1]) == 0:
			continue
		var side := int(parts[3]) - 1
		var path := "res://models/world/" + id + "/profile.tres"
		var profile: Resource = load(path)
		var scene: SceneState = load("res://models/world/" + id + "/model.tscn").get_state()
		var caches := {}
		var saved := {}
		for j in range(scene.get_node_property_count(0)):
			if scene.get_node_property_name(0, j) != "metadata/scene_state":
				continue
			saved = scene.get_node_property_value(0, j)
			for field in ["_steep_cache", "_pinch_cache", "_gimmicks_ready"]:
				caches[field] = preload("res://scripts/track/tour_entry.gd").shift_value(saved[field], field, RUNUP)
		if RUNUP <= 0:
			restore(profile, saved, path)
			continue
		profile.set_meta("entry_gimmick_state", caches)
		var previous_offset: float = profile.get_meta("entry_buffer_length", 0.0)
		var source: Dictionary = profile.get_meta("profile").duplicate(true)
		var original: Curve3D = saved.curve
		var curve: Curve3D = entries[side].curve.duplicate()
		curve.bake_interval = 2
		var transform: Transform3D = entries[side].content
		for i in range(1, original.point_count):
			curve.add_point(
				transform * original.get_point_position(i),
				transform.basis * original.get_point_in(i),
				transform.basis * original.get_point_out(i)
			)
		source.curve = curve
		source.length = curve.get_baked_length()
		shift_profile(source, RUNUP - previous_offset)
		profile.set_meta("profile", source)
		profile.set_meta("entry_buffer_length", RUNUP)
		profile.set_meta("entry_content_transform", transform)
		profile.set_meta("entry_scene_path", CONNECTOR_FOLDER + "entry_%d.tscn" % (side + 1))
		var tunnel: Vector2 = profile.get_meta("tour_underpass", Vector2.ZERO)
		if tunnel.y > tunnel.x:
			profile.set_meta("tour_underpass", tunnel + Vector2.ONE * (RUNUP - previous_offset))
		var paths: Array[String] = profile.get_meta("dependencies")
		for dependency in [CONNECTOR_FOLDER.path_join("model.glb"), profile.get_meta("entry_scene_path")]:
			if not paths.has(dependency):
				paths.append(dependency)
		profile.set_meta("dependencies", paths)
		ResourceSaver.save(profile, path)
		print("TOUR_ENTRY ", id, " +", RUNUP, "m")
	quit()
