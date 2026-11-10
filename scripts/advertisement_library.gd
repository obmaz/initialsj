extends RefCounted
# 새 광고36종과 기존 광고12종을 한 순환 안에서 중복 없이 섞는다.
const PACKS := [
 {"atlas":preload("res://assets/environment/project-promo-ads.png"),"grid":Vector2(3,2),"count":6,"categories":["sjrpg","kingword"]},
 {"atlas":preload("res://assets/environment/product-ads-home.png"),"grid":Vector2(3,2),"count":6,"categories":["cola","bed"]},
 {"atlas":preload("res://assets/environment/product-ads-tech.png"),"grid":Vector2(3,2),"count":6,"categories":["chair","phone"]},
 {"atlas":preload("res://assets/environment/product-ads-play.png"),"grid":Vector2(3,2),"count":6,"categories":["console","headphone"]},
 {"atlas":preload("res://assets/environment/product-ads-life.png"),"grid":Vector2(3,2),"count":6,"categories":["coffee","shoe"]},
 {"atlas":preload("res://assets/environment/product-ads-travel.png"),"grid":Vector2(3,2),"count":6,"categories":["backpack","ebike"]},
 {"atlas":preload("res://assets/environment/generated-racing-ads.png"),"grid":Vector2(2,2),"count":4,"categories":["motoring"]},
 {"atlas":preload("res://assets/environment/ad-print-atlas.svg"),"grid":Vector2(4,2),"count":8,"categories":["motoring"]}
]
static var rng := RandomNumberGenerator.new()
static var deck: Array[int] = []
static var last := -1
static var materials: Array[ShaderMaterial] = []
static var prop_prints: Array[ShaderMaterial] = []
static func _static_init() -> void:
 rng.randomize()
static func count() -> int:
 return 48
static func choose() -> int:
 if deck.is_empty():
  for i in range(count()): deck.append(i)
 var at := rng.randi_range(0,deck.size()-1)
 if deck[at] == last and deck.size()>1: at = (at+1)%deck.size()
 last = deck[at]
 deck.remove_at(at)
 return last
static func selection(index: int) -> Dictionary:
 var cell := posmod(index,count())
 for pack_index in range(PACKS.size()):
  var pack: Dictionary = PACKS[pack_index]
  if cell < int(pack.count):
   var columns := int(pack.grid.x)
   return {"atlas":pack.atlas,"grid":pack.grid,"tile":Vector2(cell%columns,cell/columns),"pack":pack_index,"cell":cell,"category":pack.categories[cell/3] if pack.categories.size()>1 else pack.categories[0]}
  cell -= int(pack.count)
 return {}
static func make_print(index: int, shader: Shader) -> ShaderMaterial:
 var info := selection(index)
 var printed := ShaderMaterial.new()
 printed.shader = shader
 printed.set_shader_parameter("ad_atlas",info.atlas)
 printed.set_shader_parameter("ad_grid",info.grid)
 printed.set_shader_parameter("ad_tile",info.tile)
 return printed
static func material(index: int) -> ShaderMaterial:
 # 고정된 재질 풀을 공유해 재시작 때 누적되지 않게 한다.
 if materials.is_empty():
  for i in range(count()): materials.append(make_print(i,preload("res://shaders/billboard_ad.gdshader")))
 return materials[posmod(index,count())]
static func prop_material(index: int) -> ShaderMaterial:
 # 일반 간판도 인쇄 재질을 직접 선택한다. GPU custom data의 정밀도에 의존하지 않는다.
 if prop_prints.is_empty():
  for i in range(count()): prop_prints.append(make_print(i,preload("res://shaders/prop_advertisement.gdshader")))
 return prop_prints[posmod(index,count())]
static func reshuffle(tree: SceneTree) -> void:
 for node in tree.get_nodes_in_group("racing_advertisement"):
  if node.is_queued_for_deletion(): continue
  if node is MultiMeshInstance3D:
   var index := choose()
   node.material_override = prop_material(index)
   node.set_meta("ad_index",index)
  elif node is MeshInstance3D:
   var index := choose()
   node.material_override = material(index)
   var record: Dictionary = node.get_meta("ad_record",{})
   record.ad_index = index
