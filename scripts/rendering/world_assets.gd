extends RefCounted
# 기하 원본은 GLB, 배치·재질·동작 부품 연결은 코스별 PackedScene이 소유한다.
const State = preload("res://models/shared/scene_state.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const GeometryMap = preload("res://models/shared/world_geometry_map.gd")
const KEEP := [
	"curve",
	"length",
	"stage",
	"route_node",
	"entry_side",
	"start_heading",
	"start_point",
	"closed_loop",
	"course_id",
	"region_metadata",
	"staged",
	"warmed",
	"draining"
]
const SLICE := 8


static func folder(road: Node3D) -> String:
	var id := (
		"track_%d" % road.course_id
		if road.closed_loop
		else "tour_%d_%d_%d" % [road.stage, road.route_node, road.entry_side + 1]
	)
	return "res://models/world/" + id + "/"


static func placement(road: Node3D) -> Transform3D:
	if road.closed_loop:
		return Transform3D.IDENTITY
	var basis := Basis(Vector3.UP, road.start_heading + PI / 2)
	return Transform3D(basis, road.start_point - basis * Vector3(0, 6, 0))


static func profile(road: Node3D) -> void:
	var resource: Resource = load(folder(road) + "profile.tres")
	road.asset_paths.assign(resource.get_meta(&"dependencies", []))
	road.asset_paths = GeometryMap.dependencies(road.asset_paths)
	var data: Dictionary = resource.get_meta(&"profile")
	for key in data:
		if key == "curve":
			road.curve = data.curve.duplicate()
		elif road.get(key) is Array:
			road.get(key).assign(data[key])
		else:
			road.set(key, data[key])
	for key in resource.get_meta(&"course_metadata", {}):
		road.set_meta(key, resource.get_meta(&"course_metadata")[key])
	if not road.closed_loop:
		var transform := placement(road)
		for i in range(road.curve.point_count):
			road.curve.set_point_position(i, transform * road.curve.get_point_position(i))
			road.curve.set_point_in(i, transform.basis * road.curve.get_point_in(i))
			road.curve.set_point_out(i, transform.basis * road.curve.get_point_out(i))


static func nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child in root.get_children():
		result.append_array(nodes(child))
	return result


static func collect_refs(value: Variant, refs: Dictionary) -> void:
	if value is Dictionary:
		if value.has(&"$mesh"):
			refs[value[&"$mesh"]] = true
		else:
			for child in value.values():
				collect_refs(child, refs)
	elif value is Array:
		for child in value:
			collect_refs(child, refs)


static func prepare(root: Node3D) -> Dictionary:
	var refs := {}
	var members := nodes(root)
	for node in members:
		if node.has_meta(&"mesh_ref"):
			refs[node.get_meta(&"mesh_ref")] = true
		if node.has_meta(State.KEY):
			collect_refs(node.get_meta(State.KEY), refs)
	var files := {}
	for ref: String in refs:
		files[GeometryMap.resolve(ref).get_slice("#", 0)] = null
	return {
		"root": root, "members": members, "refs": refs, "files": files, "meshes": {}, "bound": {}, "material_keys": {}
	}


static func read_file(context: Dictionary, path: String) -> void:
	var packed: PackedScene
	if GeometryMap.shared(path) and Pool.shared_world_scenes.has(path):
		packed = Pool.shared_world_scenes[path]
	else:
		packed = Pool.fetch(GeometryMap.scene(path))
		if GeometryMap.shared(path):
			Pool.shared_world_scenes[path] = packed
	var scene: Node3D = packed.instantiate()
	for ref: String in context.refs:
		var resolved := GeometryMap.resolve(ref)
		if resolved.get_slice("#", 0) == path:
			context.meshes[ref] = scene.get_node(NodePath(resolved.get_slice("#", 1))).mesh
	scene.free()


static func bind_geometry(context: Dictionary, begin: int, end: int) -> void:
	for index in range(begin, end):
		var node: Node = context.members[index]
		if not node.has_meta(&"mesh_ref"):
			continue
		var ref: String = node.get_meta(&"mesh_ref")
		var mesh: Mesh = context.meshes[ref]
		var materials: Array = node.get_meta(&"surface_materials", [])
		if node is MultiMeshInstance3D:
			if node.material_override == null and not materials.is_empty():
				var resolved := GeometryMap.resolve(ref)
				var shared := GeometryMap.shared(resolved.get_slice("#", 0))
				var ids: Array = materials.map(func(m: Material) -> int: return m.get_instance_id())
				var identity := str(ids)
				if shared and not context.material_keys.has(identity):
					context.material_keys[identity] = GeometryMap.material_key(materials)
				var key: String = resolved + ":" + (context.material_keys[identity] if shared else identity)
				var bound: Dictionary = Pool.shared_world_materials if shared else context.bound
				if not bound.has(key):
					var copy := mesh.duplicate() as ArrayMesh
					for i in range(materials.size()):
						copy.surface_set_material(i, materials[i])
					bound[key] = copy
				mesh = bound[key]
			# 미터 UV를 쓰는 구조용 단위 상자는 모든 코스가 같은 GLB 자원을 공유한다.
			if (
				node.material_override is ShaderMaterial
				and node.material_override.get_shader_parameter("uv_projection") == true
				and mesh.get_aabb().size.is_equal_approx(Vector3.ONE)
			):
				mesh = Pool.unit_box()
			node.multimesh.mesh = mesh
		else:
			node.mesh = mesh
			if node is MeshInstance3D:
				for i in range(materials.size()):
					node.set_surface_override_material(i, materials[i])


static func geometry(root: Node3D) -> void:
	var context := prepare(root)
	for path in context.files:
		read_file(context, path)
	root.set_meta(&"scene_meshes", context.meshes)
	bind_geometry(context, 0, context.members.size())


# 광고 상태는 노드와 명세가 같은 사전을 사용해야 재시작 시 함께 갱신된다.
static func bind_records(members: Array[Node]) -> void:
	for owner in members:
		var manifest: Variant = owner.get("billboard_manifest")
		if not manifest is Array:
			continue
		for node in nodes(owner):
			if not node.has_meta(&"ad_record"):
				continue
			var saved: Dictionary = node.get_meta(&"ad_record")
			for entry in manifest:
				if entry.distance == saved.distance and entry.lane == saved.lane:
					node.set_meta(&"ad_record", entry)
					break


# 시각 노드의 로컬 좌표는 씬에 두고, 계측용 월드 좌표만 배치에 맞춰 변환한다.
static func rebase_metadata(node: Node, transform: Transform3D) -> void:
	if transform.is_equal_approx(Transform3D.IDENTITY):
		return
	for field in ["tree_positions", "positions", "texture_regions"]:
		var points: Variant = node.get(field)
		if points is Array:
			for i in range(points.size()):
				if points[i] is Vector3:
					points[i] = transform * points[i]
	for field in ["placements", "plantings", "billboard_manifest"]:
		var entries: Variant = node.get(field)
		if entries is Array:
			for entry in entries:
				if entry.has("position"):
					entry.position = transform * entry.position
				if entry.has("yaw"):
					entry.yaw += atan2(transform.basis.z.x, transform.basis.z.z)
	var bounds: Variant = node.get("world_bounds")
	if bounds is Array:
		for i in range(bounds.size()):
			bounds[i] = transform * bounds[i]


static func finish_state(context: Dictionary, road: Node3D) -> void:
	var root: Node3D = context.root
	for key in root.get_meta(State.KEY):
		if not KEEP.has(key):
			road.set(key, root.get(key))
	for node in context.members:
		rebase_metadata(node, placement(road))
		if node.has_meta(&"ad_record") or node.has_meta(&"ad_index"):
			node.add_to_group(&"racing_advertisement", true)
		if node.get_script() != null:
			for field in ["track", "road", "section"]:
				if node.get(field) == root:
					node.set(field, road)
		if node != root:
			node.owner = null
			node.remove_meta(State.KEY)
	for key in root.get_meta_list():
		if key not in [State.KEY, &"asset_root", &"scene_bound", &"scene_meshes"]:
			road.set_meta(key, root.get_meta(key))
	bind_records(context.members)


static func move_child(root: Node3D, road: Node3D, child: Node) -> void:
	root.remove_child(child)
	if child is Node3D:
		child.transform = placement(road) * child.transform
	road.add_child(child)


static func finish(context: Dictionary, road: Node3D) -> void:
	context.root.free()
	context.clear()
	if road.road_surface != null:
		road.road_surface.material_override = road.road_surface.material_override.duplicate()
		road.road_surface.material_override.set_shader_parameter(
			"rain_wetness", 1.0 if road.region_metadata.get("weather", "") == "rain" and not road.closed_loop else 0.0
		)


static func queue(road: Node3D) -> void:
	var root: Node3D = Pool.fetch(folder(road) + "model.tscn").instantiate()
	var context := prepare(root)
	road.asset_context = context
	var steps: Array[Callable] = []
	for path in context.files:
		steps.append(func(): read_file(context, path))
	steps.append(func(): root.set_meta(&"scene_meshes", context.meshes))
	for begin in range(0, context.members.size(), SLICE):
		steps.append(func(): bind_geometry(context, begin, mini(begin + SLICE, context.members.size())))
	for begin in range(0, context.members.size(), SLICE):
		steps.append(
			func():
				for index in range(begin, mini(begin + SLICE, context.members.size())):
					State.bind(context.members[index])
		)
	steps.append(func(): finish_state(context, road))
	for child in root.get_children():
		steps.append(func(): move_child(root, road, child))
	steps.append(func(): finish(context, road))
	road.queue_next(steps)


static func warm(road: Node3D) -> void:
	for path in road.asset_paths:
		Pool.warm(path)


static func available(road: Node3D) -> bool:
	for path in road.asset_paths:
		if (
			Pool.warming.has(path)
			and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
		):
			return false
	return true


static func cancel(road: Node3D) -> void:
	if not road.asset_context.is_empty():
		if is_instance_valid(road.asset_context.get("root")):
			road.asset_context.root.free()
		road.asset_context.clear()
	for path in road.asset_paths:
		Pool.release(path)
	road.build_queue.clear()
