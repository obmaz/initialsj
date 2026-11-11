extends Node3D
const Catalog = preload("res://models/model_catalog.gd")
const LEAVES = "res://models/shared/foliage/tree-leaves.webp"
const BARK = "res://models/shared/foliage/bark.webp"
const NEEDLES = "res://models/shared/foliage/needle-sprays.webp"
var scenery: Node3D
var plantings: Array[Dictionary] = []
var tree_count := 0
var variant_counts := {}
var bank_counts := {-1: 0, 1: 0}
const RenderResources = preload("res://scripts/rendering/render_resources.gd")
const BARE_THEMES := ["pyramid", "canyon", "volcano", "harbor"]
# 변형별 메시·재질은 모든 구간이 공유한다. 마지막 게임 씬이 나갈 때 비운다.
static var piece_cache := {}


static func clear_cache() -> void:
	piece_cache.clear()


# 이 지역의 식생이 읽을 모델과 텍스처. 주행 중에 만드는 구간이 미리 읽기 시작한다.
static func warm_paths(region: String) -> Array[String]:
	var paths: Array[String] = []
	if region in BARE_THEMES:
		return paths
	var definitions := Catalog.all("vegetation")
	var variants := [0, 1, 5, 6] if region in ["hawaii", "jeju", "jungle"] else range(definitions.size())
	for variant in variants:
		var item: Resource = definitions[variant]
		if not piece_cache.has(item.id):
			paths.append(item.scene_path)
	paths.append_array([LEAVES, BARK, NEEDLES])
	return paths


const PLANTING_SLICE := 8
var definitions: Array[Resource] = []
var groups := {}
var planning_slices := 0
var batch_slices := 0


func _ready() -> void:
	if preload("res://models/shared/scene_state.gd").bind(self):
		return
	definitions = Catalog.all("vegetation")
	if not plantings.is_empty():
		for p in plantings:
			var v: int = p.variant
			var key := str(v) + ":" + str(floori(p.position.x / 120)) + ":" + str(floori(p.position.z / 120))
			if not groups.has(key):
				groups[key] = {"variant": v, "poses": []}
			groups[key].poses.append(
				Transform3D(Basis(Vector3.UP, p.yaw).scaled_local(Vector3.ONE * p.scale), p.position)
			)
			tree_count += 1
		queue_batches()
		return
	var theme: String = scenery.theme
	if theme in BARE_THEMES:
		return
	var road: Node3D = scenery.track
	var spacing := 12 if theme == "jungle" else (24 if theme in ["amusement", "fuji", "bamboo", "snow"] else 42)
	var planting_start := 75.0 if theme == "jungle" else 180.0
	var count := int((road.length - planting_start - 160) / spacing)
	var steps: Array[Callable] = []
	for begin in range(0, count, PLANTING_SLICE):
		steps.append(func(): plant_range(begin, mini(count, begin + PLANTING_SLICE), spacing, planting_start))
	steps.append(plant_park)
	steps.append(queue_batches)
	schedule(steps)


func schedule(steps: Array[Callable]) -> void:
	if is_instance_valid(scenery):
		scenery.track.queue_next(steps)
	else:
		for step in steps:
			step.call()


func plant_range(begin: int, end: int, spacing: int, planting_start: float) -> void:
	var theme: String = scenery.theme
	var road: Node3D = scenery.track
	planning_slices += 1
	for i in range(begin, end):
		var d := planting_start + i * spacing
		if road.in_tunnel(d):
			continue
		if road.bridge_span.y > road.bridge_span.x and d > road.bridge_span.x - 80 and d < road.bridge_span.y + 80:
			continue
		var v := (i % 3) + 2 if theme in ["snow", "bamboo"] else i % 7
		if theme in ["hawaii", "jeju", "jungle"]:
			v = (5 + i % 2) if i % 7 >= 5 else i % 2
		if theme in ["snow", "bamboo"] and i % 7 >= 5:
			v = 5 + i % 2
		var item: Resource = definitions[v]
		var side := 1.0 if theme in ["hawaii", "jeju", "fuji"] else (-1.0 if i % 2 else 1.0)
		var sides := [-1.0, 1.0] if theme == "jungle" else [side]
		if road.entry_side != 0 and d < (240 if theme == "jungle" else 650):
			sides = [float(road.entry_side)]
		for bank in sides:
			for row in range(3 if theme == "jungle" else 1):
				var at_d: float = d + row * 4 + (sin(i * 2.39 + bank) * 2 if theme == "jungle" else 0)
				var lane: float = (
					bank
					* (
						road.half_width(at_d)
						+ road.rail_setback(at_d, bank)
						+ (7 + row * 11 + (i % 3) * 2 if theme == "jungle" else 12 + (i % 4) * 6)
					)
				)
				var point: Vector3 = road.roadside_point(at_d, lane)
				var nearest: float = road.curve.get_closest_offset(point)
				if (
					Vector2(point.x - road.point(nearest).x, point.z - road.point(nearest).z).length()
					< road.half_width(nearest) + 9
				):
					continue
				var key := str(v) + ":" + str(floori(point.x / 120)) + ":" + str(floori(point.z / 120))
				if not groups.has(key):
					groups[key] = {"variant": v, "poses": []}
				var scale := .85 + fposmod(i * .17 + row * .23 + bank, .32) if theme == "jungle" else 1.0
				groups[key].poses.append(
					Transform3D(Basis(Vector3.UP, i * 2.399 + row + bank).scaled_local(Vector3.ONE * scale), point)
				)
				variant_counts[item.id] = int(variant_counts.get(item.id, 0)) + 1
				bank_counts[int(bank)] += 1
				tree_count += 1
			if theme == "jungle":
				var shrub := 5 if i % 3 == 0 else 6
				var point: Vector3 = road.roadside_point(
					d + 6, bank * (road.half_width(d) + road.rail_setback(d, bank) + 5.5)
				)
				var key := str(shrub) + ":" + str(floori(point.x / 120)) + ":" + str(floori(point.z / 120))
				if not groups.has(key):
					groups[key] = {"variant": shrub, "poses": []}
				groups[key].poses.append(Transform3D(Basis(Vector3.UP, i * 2.399), point))
				variant_counts[definitions[shrub].id] = int(variant_counts.get(definitions[shrub].id, 0)) + 1
				bank_counts[int(bank)] += 1
				tree_count += 1


func plant_park() -> void:
	var theme: String = scenery.theme
	if theme == "amusement":
		for park in scenery.get_children():
			if park.get_script() != preload("res://scripts/environment/tour_amusement.gd"):
				continue
			for i in range(12):
				var v := i % 5
				var point: Vector3 = park.to_global(Vector3(-70 + (i % 6) * 28, 0, 52 if i < 6 else -106))
				var key := str(v) + ":" + str(floori(point.x / 120)) + ":" + str(floori(point.z / 120))
				if not groups.has(key):
					groups[key] = {"variant": v, "poses": []}
				groups[key].poses.append(Transform3D(Basis(Vector3.UP, i * 2.399), point))
				variant_counts[definitions[v].id] = int(variant_counts.get(definitions[v].id, 0)) + 1
				tree_count += 1


func queue_batches() -> void:
	var steps: Array[Callable] = []
	var prepared := {}
	for key in groups:
		var group: Dictionary = groups[key]
		var item: Resource = definitions[group.variant]
		if not prepared.has(item.id):
			steps.append(func(): prepare_variant(item))
			prepared[item.id] = true
		for begin in range(0, group.poses.size(), 12):
			steps.append(func(): build_batch(group, item, begin))
	steps.append(func(): groups.clear())
	schedule(steps)


func prepare_variant(item: Resource) -> void:
	if not piece_cache.has(item.id):
		var resource: Resource = RenderResources.fetch(item.scene_path)
		var mesh: Mesh
		if resource is PackedScene:
			var scene: Node = resource.instantiate()
			mesh = preload("res://models/shared/scene_source.gd").collect_meshes(scene)[0].mesh
			scene.free()
		else:
			mesh = resource
		var scale: float = item.parameters.height / mesh.get_aabb().size.y
		# 표면 배열을 새로 만들면 GLB에 생성된 LOD가 사라진다. 메시를 복제해 두 표면·LOD를 보존한다.
		var combined := mesh.duplicate() as ArrayMesh
		for surface in range(mesh.get_surface_count()):
			var leaf: bool = mesh.surface_get_material(surface).resource_name.begins_with("LeafSprays")
			var material := StandardMaterial3D.new()
			material.albedo_texture = RenderResources.fetch(
				BARK if not leaf else (NEEDLES if item.parameters.needles else LEAVES)
			)
			material.vertex_color_use_as_albedo = true
			material.roughness = .96
			if leaf:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = .28 if item.parameters.needles else .42
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
			combined.surface_set_material(surface, material)
		piece_cache[item.id] = [{"mesh": combined, "material": null, "scale": scale}]


func build_batch(group: Dictionary, item: Resource, begin: int) -> void:
	batch_slices += 1
	for piece in piece_cache[item.id]:
		var part: ArrayMesh = piece.mesh
		var material: Material = piece.material
		var scale: float = piece.scale
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = part
		multi.instance_count = mini(12, group.poses.size() - begin)
		for j in range(multi.instance_count):
			multi.set_instance_transform(j, group.poses[begin + j].scaled_local(Vector3.ONE * scale))
			multi.set_instance_color(j, Color.WHITE)
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = material
		node.visibility_range_end = (
			100 if group.variant >= 5 else (190 if is_instance_valid(scenery) and scenery.theme == "jungle" else 240)
		)
		node.visibility_range_end_margin = 25
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
