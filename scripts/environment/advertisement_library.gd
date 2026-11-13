extends RefCounted
# 새 광고36종과 기존 광고12종을 한 순환 안에서 중복 없이 섞는다.
const PACKS := [
	{
		"atlas": "res://assets/environment/project-promo-ads.png",
		"grid": Vector2(3, 2),
		"count": 6,
		"categories": ["sjrpg", "kingword"]
	},
	{
		"atlas": "res://assets/environment/product-ads-home.png",
		"grid": Vector2(3, 2),
		"count": 6,
		"categories": ["cola", "bed"]
	},
	{
		"atlas": "res://assets/environment/product-ads-tech.png",
		"grid": Vector2(3, 2),
		"count": 6,
		"categories": ["chair", "phone"]
	},
	{
		"atlas": "res://assets/environment/product-ads-play.png",
		"grid": Vector2(3, 2),
		"count": 6,
		"categories": ["console", "headphone"]
	},
	{
		"atlas": "res://assets/environment/product-ads-life.png",
		"grid": Vector2(3, 2),
		"count": 6,
		"categories": ["coffee", "shoe"]
	},
	{
		"atlas": "res://assets/environment/product-ads-travel.png",
		"grid": Vector2(3, 2),
		"count": 6,
		"categories": ["backpack", "ebike"]
	},
	{
		"atlas": "res://assets/environment/generated-racing-ads.png",
		"grid": Vector2(2, 2),
		"count": 4,
		"categories": ["motoring"]
	},
	{
		"atlas": "res://assets/environment/ad-print-atlas.svg",
		"grid": Vector2(4, 2),
		"count": 8,
		"categories": ["motoring"]
	}
]
static var rng := RandomNumberGenerator.new()
static var deck: Array[int] = []
static var last := -1
static var materials: Array[ShaderMaterial] = []
static var night_materials: Array[ShaderMaterial] = []
static var night_prop_prints: Array[ShaderMaterial] = []
static var prop_prints: Array[ShaderMaterial] = []
static var atlases: Dictionary = {}


static func _static_init() -> void:
	rng.randomize()


static func count() -> int:
	return 48


static func choose() -> int:
	if deck.is_empty():
		for i in range(count()):
			deck.append(i)
	var at := rng.randi_range(0, deck.size() - 1)
	if deck[at] == last and deck.size() > 1:
		at = (at + 1) % deck.size()
	last = deck[at]
	deck.remove_at(at)
	return last


static func selection(index: int) -> Dictionary:
	var cell := posmod(index, count())
	for pack_index in range(PACKS.size()):
		var pack: Dictionary = PACKS[pack_index]
		if cell < int(pack.count):
			var columns := int(pack.grid.x)
			if not atlases.has(pack_index):
				atlases[pack_index] = preload("res://scripts/rendering/render_resources.gd").fetch(pack.atlas)
			return {
				"atlas": atlases[pack_index],
				"grid": pack.grid,
				"tile": Vector2(cell % columns, cell / columns),
				"pack": pack_index,
				"cell": cell,
				"category": pack.categories[cell / 3] if pack.categories.size() > 1 else pack.categories[0]
			}
		cell -= int(pack.count)
	return {}


# 주행 중 처음 나오는 광고 아틀라스를 미리 읽기 시작한다.
static func warm() -> void:
	for pack_index in range(PACKS.size()):
		if not atlases.has(pack_index):
			preload("res://scripts/rendering/render_resources.gd").warm(PACKS[pack_index].atlas)


static func make_print(index: int, shader: Shader) -> ShaderMaterial:
	var info := selection(index)
	var printed := ShaderMaterial.new()
	printed.shader = shader
	printed.set_shader_parameter("ad_atlas", info.atlas)
	printed.set_shader_parameter("ad_grid", info.grid)
	printed.set_shader_parameter("ad_tile", info.tile)
	return printed


static func material(index: int, night: bool = false) -> ShaderMaterial:
	if night:
		if night_materials.is_empty():
			night_materials.resize(count())
		var slot := posmod(index, count())
		if night_materials[slot] == null:
			night_materials[slot] = make_print(slot, preload("res://shaders/billboard_ad.gdshader"))
			night_materials[slot].set_shader_parameter("night_lighting", 1.0)
		return night_materials[slot]
	if materials.is_empty():
		materials.resize(count())
	var slot := posmod(index, count())
	if materials[slot] == null:
		materials[slot] = make_print(slot, preload("res://shaders/billboard_ad.gdshader"))
	return materials[slot]


static func prop_material(index: int, night: bool = false) -> ShaderMaterial:
	if night:
		if night_prop_prints.is_empty():
			night_prop_prints.resize(count())
		var slot := posmod(index, count())
		if night_prop_prints[slot] == null:
			night_prop_prints[slot] = make_print(slot, preload("res://shaders/prop_advertisement.gdshader"))
			night_prop_prints[slot].set_shader_parameter("night_lighting", 1.0)
		return night_prop_prints[slot]
	if prop_prints.is_empty():
		prop_prints.resize(count())
	var slot := posmod(index, count())
	if prop_prints[slot] == null:
		prop_prints[slot] = make_print(slot, preload("res://shaders/prop_advertisement.gdshader"))
	return prop_prints[slot]


static func clear_cache() -> void:
	materials.clear()
	prop_prints.clear()
	night_materials.clear()
	night_prop_prints.clear()
	atlases.clear()
	deck.clear()
	last = -1


static func reshuffle(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("racing_advertisement"):
		if node.is_queued_for_deletion():
			continue
		if node is MultiMeshInstance3D:
			var index := choose()
			node.material_override = prop_material(index, node.get_meta("advertisement_night", false))
			node.set_meta("ad_index", index)
		elif node is MeshInstance3D:
			var index := choose()
			node.material_override = material(index, node.get_meta("advertisement_night", false))
			var record: Dictionary = node.get_meta("ad_record", {})
			record.ad_index = index


# 투어의 다음 지역도 자기 시간대로 인쇄면과 GLB 렌즈만 준비한다. 동적 광원은 늘리지 않는다.
static func configure_tour_section(road: Node3D) -> void:
	var use_ad_lighting: bool = road.region_metadata.get("time_of_day", "day") in ["night", "dawn"]
	for node in road.get_tree().get_nodes_in_group("racing_advertisement"):
		if not road.is_ancestor_of(node):
			continue
		node.set_meta("advertisement_night", use_ad_lighting)
		if node is MultiMeshInstance3D:
			node.material_override = prop_material(node.get_meta("ad_index", 0), use_ad_lighting)
		elif node is MeshInstance3D:
			node.material_override = material(node.get_meta("ad_record", {}).get("ad_index", 0), use_ad_lighting)
