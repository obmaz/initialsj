extends Node3D
# Opaque, low-poly meshes shared by every instance. No camera-facing foreground art.
const FAMILIES := {
	"hawaii":["palm","palm","broadleaf"], "jeju":["hareubang","tangerine","dol_wall","palm","hareubang","dol_wall"],
	"fuji":["pine","sakura","japanese_pine"], "bamboo":["bamboo","bamboo","basalt"],
	"snow":["snow_pine","snow_pine","basalt"], "volcano":["basalt","charred","basalt"],
	"desert":["cactus","sandstone","cactus"], "pyramid":["obelisk","palm","sandstone"],
	"canyon":["sandstone","cactus","sandstone"],
	"city":["convenience_store","apartment","broadleaf","gas_station","billboard","plane_tree","bus_shelter","street_shop","apartment"],
	"seoul":["apartment","ginkgo","convenience_store","billboard","bus_shelter","street_shop","gas_station","pine"],
	"neon":["billboard","convenience_store","apartment","plane_tree","gas_station","street_shop","bus_shelter"],
	"ruins":["broken_column","charred","basalt"],
	"harbor":["containers","dock_crane","container_stack","warehouse_shed","fuel_tank","container_stack","palm","cargo_ship"],
	"amusement":["ticket_booth","broadleaf","sakura"]
}
const Ads = preload("res://scripts/advertisement_library.gd")
const Models = preload("res://models/prop_models.gd")
static var RURAL_KINDS: Array[String] = Models.ids_with_tag("rural")
static var BUILDING_DIMS: Dictionary = Models.building_dimensions()
static var mesh_cache: Dictionary = {}
static var shared_materials: Dictionary = {}
static var material_keys: Dictionary = {}
var theme := "hawaii"
var placements: Array[Dictionary] = []
var batches: Array[MultiMeshInstance3D] = []
var kinds: Array[String] = []
var world_bounds: Array[AABB] = []
var tree_count := 0
func configure(region: String, points: Array[Dictionary]) -> void:
	theme = region
	placements.assign(points)
func _ready() -> void:
	var groups: Dictionary = {}
	for i in range(placements.size()):
		var p: Dictionary = placements[i]
		var family: Array = FAMILIES.get(theme,FAMILIES.hawaii)
		var kind: String = p.get("kind",family[int(p.get("variant",i))%family.size()])
		var group := kind+":"+str(floori(p.position.x/180))+":"+str(floori(p.position.z/180))
		var ad_index: int = Ads.choose() if kind == "billboard" else -1
		if kind == "billboard": group += ":ad"+str(ad_index)
		if not groups.has(group): groups[group] = {"kind":kind,"poses":[],"ad_index":ad_index}
		var scale: float = p.get("scale",1.0)
		var transform := Transform3D(Basis(Vector3.UP,float(p.get("yaw",0))).scaled_local(Vector3.ONE*scale),p.position)
		groups[group].poses.append(transform)
		var bounds: AABB = transform*model(kind).get_aabb()
		world_bounds.append(bounds)
		if Models.definition(kind).tags.has("tree"): tree_count += 1
	for group in groups:
		var kind: String = groups[group].kind
		var poses: Array = groups[group].poses
		# Split long roads into small spatial batches, so a curve cannot make the
		# entire route's props submit every frame under one enormous MultiMesh AABB.
		for start in range(0,poses.size(),12):
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			# Compatibility의 COLOR 경로는 흰색 인스턴스 색상이 있어야 정점색을 보존한다.
			multi.use_colors = true
			multi.use_custom_data = true
			multi.mesh = model(kind)
			multi.instance_count = mini(12,poses.size()-start)
			for i in range(multi.instance_count):
				multi.set_instance_transform(i,poses[start+i])
				multi.set_instance_color(i,Color.WHITE)
				var origin: Vector3 = poses[start+i].origin
				var appearance := posmod(floori(origin.x*.017)+floori(origin.z*.031),8)
				multi.set_instance_custom_data(i,Color(float(appearance)/7,0,0,1))
			var node := MultiMeshInstance3D.new()
			node.name = "Regional3D_"+kind+"_"+str(start)
			node.multimesh = multi
			node.material_override = Ads.prop_material(groups[group].ad_index) if kind == "billboard" else material_for(kind)
			if kind == "billboard":
				node.add_to_group("racing_advertisement")
				node.set_meta("ad_index",groups[group].ad_index)
			node.visibility_range_end = Models.definition(kind).visibility_range
			node.visibility_range_end_margin = 24
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			batches.append(node)
			if not kinds.has(kind): kinds.append(kind)
static func material_for(kind: String) -> Material:
	var definition: Resource = Models.definition(kind)
	if not definition.material_path.is_empty():
		var key: String = "material:"+definition.material_path
		if not shared_materials.has(key): shared_materials[key] = load(definition.material_path)
		return shared_materials[key]
	var embedded: Material = model(kind).surface_get_material(0)
	if embedded != null: return embedded
	if not material_keys.has(kind):
		var needed := {}
		var data: Array = model(kind).surface_get_arrays(0)
		var marks: PackedVector2Array = data[Mesh.ARRAY_TEX_UV2] if data[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		for mark in marks:
			if mark.x > 59.5:
				needed["container_skins"] = "res://assets/environment/container-elevations.png"
			elif mark.x > 39.5:
				needed["rural_fronts"] = "res://assets/environment/rural-fronts.png"
				needed["rural_sides"] = "res://assets/environment/rural-sides.png"
			elif mark.x > 21.5:
				needed["restaurant_facades"] = "res://assets/environment/restaurant-elevations.png"
			elif mark.x > 9.5:
				needed["building_fronts"] = "res://assets/environment/building-front-elevations.png"
				needed["building_sides"] = "res://assets/environment/building-side-elevations.png"
		var keys := needed.keys()
		keys.sort()
		var key := ",".join(PackedStringArray(keys))
		material_keys[kind] = key
		if not shared_materials.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/prop_facade.gdshader")
			for uniform_name in needed: mat.set_shader_parameter(uniform_name,load(needed[uniform_name]))
			shared_materials[key] = mat
	return shared_materials[material_keys[kind]]
static func clear_cache() -> void:
	mesh_cache.clear()
	shared_materials.clear()
	material_keys.clear()

func set_shadow_quality(_enabled: bool) -> void:
	# Small prop shadows are deliberately omitted; nearby car/architecture shadows
	# retain depth without submitting hundreds of extra shadow casters on phones.
	pass
static func radius(kind: String) -> float:
	var bounds := model(kind).get_aabb()
	# 비대칭 주유소의 가격표 지주처럼 서로 반대쪽 축에 돌출한 모서리도 포함한다.
	return Vector2(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z))).length()
static func model(kind: String) -> ArrayMesh:
	if not mesh_cache.has(kind): mesh_cache[kind] = Models.build(kind)
	return mesh_cache[kind]

static func placement_scale(kind: String, requested: float) -> float:
	var limits: Vector2 = Models.definition(kind).placement_limits
	return clampf(requested,limits.x,limits.y) if limits.y > 0 else requested
