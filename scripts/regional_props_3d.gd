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
const Models = preload("res://scripts/quaternius_props.gd")
const RURAL_KINDS := ["rural_farmhouse","rural_stone_cottage","rural_brick_house","rural_timber_house","rural_chalet","rural_grocer","rural_bakery","rural_fruit_shop","rural_cafe","rural_garage"]
const RURAL_DIMS := [Vector3(14,6.4,10),Vector3(10,3.7,8),Vector3(12,3.9,9),Vector3(11,5.8,8),Vector3(10,5.5,9),Vector3(14,4.2,10),Vector3(12,4.3,9),Vector3(13,3.8,9),Vector3(12,6,9),Vector3(16,4.5,12)]
const BUILDING_DIMS := {"coffee_shop":Vector3(8,3.8,6),"convenience_store":Vector3(10,3.6,6.4),"street_shop":Vector3(7,4.4,6),"ticket_booth":Vector3(7,4.4,6),"gas_station":Vector3(8,3.4,4.5),"apartment":Vector3(11,17,9),"warehouse_shed":Vector3(14,6.4,26),"ryokan":Vector3(17,8.6,9),"teahouse":Vector3(8,3.8,6),"noodle_house":Vector3(9,3,7),"souvenir_shop":Vector3(9,3.6,6)}
# 건물 템플릿의 로컬 치수를 도로와 같은 미터 단위로 보정한다.
# 가로·깊이는 매장과 전정을 확보하고 높이는 층고와 급유기 비례를 유지한다.
const METRE_SCALE := {
 "coffee_shop":Vector3(1.5,1.15,1.5), "convenience_store":Vector3(1.6,1.2,1.65),
 "street_shop":Vector3(1.6,1.1,1.5), "ticket_booth":Vector3(1.3,1.05,1.3),
 "gas_station":Vector3(1.6,1.15,1.7), "apartment":Vector3(1.65,1.15,1.6),
 "warehouse_shed":Vector3(1.25,1.1,1.2), "ryokan":Vector3(1.3,1.1,1.4),
 "teahouse":Vector3(1.3,1.1,1.3), "noodle_house":Vector3(1.5,1.3,1.4),
 "souvenir_shop":Vector3(1.5,1.2,1.5), "billboard":Vector3(1.35,1.2,1.3),
 "palm":Vector3(1.1,1.65,1.1), "pine":Vector3(1.2,1.6,1.2),
 "snow_pine":Vector3(1.2,1.6,1.2), "japanese_pine":Vector3(1.3,1.5,1.3),
 "broadleaf":Vector3(1.3,1.5,1.3), "sakura":Vector3(1.25,1.35,1.25),
 "plane_tree":Vector3(1.3,1.6,1.3), "ginkgo":Vector3(1.25,1.6,1.25),
 "bamboo":Vector3(1.15,1.4,1.15), "charred":Vector3(1.2,1.5,1.2)
}
const MATURE_TREE_HEIGHT := {"lake_pine_1":22.0,"lake_pine_2":20.0,"lake_pine_3":24.0,"lake_oak_1":16.0,"lake_oak_2":18.0,"lake_willow_1":14.0,"lake_willow_2":16.0,"lake_willow_3":18.0}
static var mesh_cache: Dictionary = {}
static var shared_material: ShaderMaterial
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
 if shared_material == null:
  shared_material = ShaderMaterial.new()
  shared_material.shader = preload("res://shaders/prop_facade.gdshader")
  shared_material.set_shader_parameter("building_fronts",preload("res://assets/environment/building-front-elevations.png"))
  shared_material.set_shader_parameter("building_sides",preload("res://assets/environment/building-side-elevations.png"))
  shared_material.set_shader_parameter("rural_fronts",preload("res://assets/environment/rural-fronts.png"))
  shared_material.set_shader_parameter("rural_sides",preload("res://assets/environment/rural-sides.png"))
  shared_material.set_shader_parameter("restaurant_facades",preload("res://assets/environment/restaurant-elevations.png"))
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
  if kind in ["palm","broadleaf","pine","snow_pine","sakura","bamboo","plane_tree","ginkgo","charred","japanese_pine","tangerine"] or Models.is_tree(kind): tree_count += 1
 for group in groups:
  var kind: String = groups[group].kind
  var poses: Array = groups[group].poses
  # Split long roads into small spatial batches, so a curve cannot make the
  # entire route's props submit every frame under one enormous MultiMesh AABB.
  for start in range(0,poses.size(),12):
   var multi := MultiMesh.new()
   multi.transform_format = MultiMesh.TRANSFORM_3D
   multi.use_custom_data = true
   multi.use_colors = true
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
   node.material_override = Ads.prop_material(groups[group].ad_index) if kind == "billboard" else shared_material
   if kind == "billboard":
    node.add_to_group("racing_advertisement")
    node.set_meta("ad_index",groups[group].ad_index)
   node.visibility_range_end = 400 if kind in ["palm","pine","snow_pine"] else (190 if kind.begins_with("lake_bush") or kind.begins_with("lake_rock") else (330 if Models.is_tree(kind) else 310))
   node.visibility_range_end_margin = 24
   node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   add_child(node)
   batches.append(node)
   if not kinds.has(kind): kinds.append(kind)
func set_shadow_quality(_enabled: bool) -> void:
 # Small prop shadows are deliberately omitted; nearby car/architecture shadows
 # retain depth without submitting hundreds of extra shadow casters on phones.
 pass
static func radius(kind: String) -> float:
 var bounds := model(kind).get_aabb()
 # 비대칭 주유소의 가격표 지주처럼 서로 반대쪽 축에 돌출한 모서리도 포함한다.
 return Vector2(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z))).length()
static func box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, yaw: float = 0, facade: int = -1) -> void:
 var mesh := BoxMesh.new()
 mesh.size = Vector3.ONE
 append(st,mesh,Transform3D(Basis(Vector3.UP,yaw).scaled_local(size),center),color,facade)
static func round_part(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
 var mesh := SphereMesh.new()
 mesh.radius = 0.5
 mesh.height = 1
 mesh.radial_segments = 9
 mesh.rings = 4
 append(st,mesh,Transform3D(Basis.IDENTITY.scaled(size),center),color)
static func column(st: SurfaceTool, center: Vector3, height: float, bottom: float, top: float, color: Color, sides: int = 7) -> void:
 var mesh := CylinderMesh.new()
 mesh.height = height
 mesh.bottom_radius = bottom
 mesh.top_radius = top
 mesh.radial_segments = sides
 mesh.rings = 1
 append(st,mesh,Transform3D(Basis.IDENTITY,center),color)
static func append(st: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color, facade: int = -1) -> void:
 var data := mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
 var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
 var normal_basis := transform.basis.inverse().transposed()
 for i in range(indices.size() if not indices.is_empty() else vertices.size()):
  var index: int = indices[i] if not indices.is_empty() else i
  st.set_color(color)
  var v := vertices[index]
  var n := normals[index]
  st.set_uv(Vector2(v.z+.5,.5-v.y) if absf(n.x)>.5 else Vector2((.5-v.x) if n.z>0 else (v.x+.5),.5-v.y))
  st.set_uv2(Vector2(10+facade,1 if n.z>.5 else 0) if facade>=0 and absf(n.y)<.5 else Vector2.ZERO)
  st.set_normal((normal_basis*normals[index]).normalized())
  st.add_vertex(transform*vertices[index])
static func model(kind: String) -> ArrayMesh:
 if mesh_cache.has(kind): return mesh_cache[kind]
 if kind in RURAL_KINDS:
  mesh_cache[kind] = rural_model(RURAL_KINDS.find(kind))
  return mesh_cache[kind]
 if Models.has(kind):
  mesh_cache[kind] = metre_mesh(Models.build(kind),kind)
  return mesh_cache[kind]
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_uv(Vector2.ZERO)
 st.set_uv2(Vector2.ZERO)
 var bark := Color("73513a")
 var green := Color("367a48")
 match kind:
  "palm":
   # 연속된 곡선 줄기와 잎맥·소엽으로 판자처럼 보이는 큰 잎을 교체합니다.
   for ring in range(16):
    for side in range(12):
     var points: Array[Vector3] = []
     var normals: Array[Vector3] = []
     for row in [ring,ring+1]:
      var t: float = row/16.0
      var center := Vector3(.5*t*t,8.4*t,.12*sin(t*PI))
      var radius := lerpf(.32,.16,t)
      for segment in [side,side+1]:
       var angle: float = segment*TAU/12
       var normal := Vector3(cos(angle),0,sin(angle))
       points.append(center+normal*radius)
       normals.append(normal)
     for n in [0,1,2,1,3,2]:
      st.set_color(bark.lightened(.08 if ring%3 == 0 else -.04))
      st.set_normal(normals[n])
      st.add_vertex(points[n])
   var center := Vector3(.5,8.4,0)
   for leaf in range(11):
    var angle := leaf*TAU/11
    var f := Vector3(cos(angle),0,sin(angle))
    var right := Vector3(-f.z,0,f.x)
    var color := Color("2f6840").lightened((leaf%3)*.055)
    for part in range(12):
     var t := part/12.0
     var u := (part+1)/12.0
     var a := center+f*t*4.7+Vector3.UP*(sin(t*PI)*1.6-t*1.8)
     var b := center+f*u*4.7+Vector3.UP*(sin(u*PI)*1.6-u*1.8)
     var points := [a-right*.12,a+right*.12,b-right*.075,b+right*.075]
     for n in [0,2,1,1,2,3,0,1,2,1,3,2]:
      st.set_color(color.lightened(.06))
      st.set_normal(Vector3.UP)
      st.add_vertex(points[n])
     if part == 0: continue
     for sign_x in [-1.0,1.0]:
      var tip: Vector3 = a+right*sign_x*sin(t*PI)*1.15-f*.48-Vector3.UP*.32
      var mid: Vector3 = a.lerp(tip,.48)
      var points_leaf := [a,mid+f*.16,tip,mid-f*.16]
      for n in [0,1,3,1,2,3,0,3,1,1,3,2]:
       st.set_color(color)
       st.set_normal(Vector3.UP)
       st.add_vertex(points_leaf[n])
   for i in range(3): round_part(st,center+Vector3(cos(i*2.0)*.3,-.2,sin(i*2.0)*.3),Vector3.ONE*.4,Color("625037"))
  "japanese_pine":
   column(st,Vector3(0,3.7,0),7.4,0.4,0.16,bark)
   for i in range(5):
    var angle := i*2.4
    var p := Vector3(cos(angle)*1.9,5.7+i*0.65,sin(angle)*1.9)
    box(st,Vector3(p.x*0.5,p.y-0.6,p.z*0.5),Vector3(3.6,0.2,0.25),bark,angle)
    round_part(st,p,Vector3(4.8,1.6,3.8),Color("3b6e4f").lightened((i%3)*0.05))
  "pine", "snow_pine":
   column(st,Vector3(0,5.2,0),10.4,0.3,0.18,bark)
   for tier in range(4):
    var y := 4.1+tier*1.9
    column(st,Vector3(0,y,0),4.5-tier*0.3,3.5-tier*0.65,0,Color("326746") if tier%2 else Color("3c7952"),9)
    if kind == "snow_pine": column(st,Vector3(0,y+0.6,0),3.2-tier*0.25,2.6-tier*0.5,0,Color("e5edf0"),9)
  "hareubang":
   # Jeju stone guardian: porous basalt body, round head, brimmed cap, big eyes, hands on the belly.
   # Drawn larger than life so it reads from the road. Local -Z faces the road.
   var stone := Color("4f5352")
   column(st,Vector3(0,1.3,0),2.6,0.78,0.62,stone,9)
   round_part(st,Vector3(0,3.15,0),Vector3(1.45,1.6,1.4),stone.lightened(0.05))
   column(st,Vector3(0,3.95,0),0.18,0.95,0.95,stone.darkened(0.1),12)
   round_part(st,Vector3(0,4.25,0),Vector3(1.2,0.85,1.2),stone.darkened(0.05))
   for x in [-0.32,0.32]:
    round_part(st,Vector3(x,3.35,-0.62),Vector3(0.42,0.36,0.3),stone.lightened(0.18))
    box(st,Vector3(x*0.9,1.9,-0.62),Vector3(0.5,0.22,0.24),stone.lightened(0.12),0.4 if x < 0 else -0.4)
   box(st,Vector3(0,3.0,-0.68),Vector3(0.36,0.6,0.32),stone.lightened(0.1))
   column(st,Vector3(0,0.15,0),0.3,1.0,1.0,Color("3c3f3e"),9)
  "dol_wall":
   # A dry-stacked black basalt field wall.
   for i in range(9):
    var x := -5.6+i*1.4
    round_part(st,Vector3(x,0.45,sin(i*1.7)*0.12),Vector3(1.5,0.95,1.0),Color("2f3333").lightened((i%3)*0.06))
    round_part(st,Vector3(x+0.7,1.15,sin(i*2.3)*0.1),Vector3(1.3,0.75,0.9),Color("383d3c").lightened((i%2)*0.05))
  "tangerine":
   column(st,Vector3(0,0.9,0),1.8,0.24,0.16,bark)
   round_part(st,Vector3(0,2.6,0),Vector3(3.2,2.6,3.2),Color("2f6e3a"))
   round_part(st,Vector3(0.6,3.3,0.3),Vector3(2.2,1.8,2.2),Color("3a7d44"))
   for i in range(8):
    var angle := i*TAU/8
    round_part(st,Vector3(cos(angle)*1.45,2.3+0.5*sin(i*1.3),sin(angle)*1.45),Vector3.ONE*0.38,Color("f08a1c"))
  "broadleaf", "sakura", "plane_tree", "ginkgo":
   column(st,Vector3(0,3.2,0),6.4,0.38,0.22,bark)
   var crown_color := Color("edacc5") if kind == "sakura" else (Color("b8ac42") if kind == "ginkgo" else green)
   var top := 7.0 if kind == "sakura" else (9.0 if kind == "plane_tree" else 8.0)
   for i in range(5):
    var angle := i*TAU/5
    var p := Vector3(cos(angle)*1.6,top+0.4*sin(angle*2),sin(angle)*1.6)
    round_part(st,p,Vector3(3.8 if kind == "plane_tree" else 4.7,3.4 if kind == "sakura" else (5.5 if kind == "plane_tree" else 4.5),3.8 if kind == "plane_tree" else 4.7),crown_color.lightened((i%3)*0.06))
   round_part(st,Vector3(0,top+1.6,0),Vector3(4.5,4,4.5),crown_color)
  "bamboo":
   for stalk in range(5):
    var p := Vector3(cos(stalk*2.4)*1.25,0,sin(stalk*2.4)*1.25)
    var height := 7.0+(stalk%3)*1.5
    column(st,p+Vector3.UP*height*0.5,height,0.12,0.09,Color("67984c"),6)
    for ring in range(1,int(height)):
     column(st,p+Vector3.UP*ring,0.06,0.14,0.14,Color("aec477"),6)
    for branch in range(3):
     var angle := stalk*2.1+branch*1.8
     round_part(st,p+Vector3(cos(angle)*0.8,height-branch*1.3,sin(angle)*0.8),Vector3(2.4,0.5,1.1),green)
  "cactus":
   column(st,Vector3(0,3,0),6,0.55,0.48,Color("718a4e"),7)
   for side in [-1,1]:
    box(st,Vector3(side*0.8,2.8+side*0.5,0),Vector3(1.6,0.6,0.6),Color("668046"))
    column(st,Vector3(side*1.5,3.6+side*0.5,0),1.9,0.31,0.28,Color("718a4e"),6)
  "basalt", "sandstone":
   for i in range(4):
    var height := 1.4+(i%3)*0.8
    round_part(st,Vector3(cos(i*2.1)*1.8,height*0.45,sin(i*2.1)*1.8),Vector3(3,height,3.5),Color("394649") if kind == "basalt" else Color("ba8156"))
  "charred":
   column(st,Vector3(0,3.3,0),6.6,0.45,0.12,Color("51463f"))
   box(st,Vector3(0.8,4,0),Vector3(2.2,0.3,0.3),Color("51463f"),0.5)
   box(st,Vector3(-0.8,5,0),Vector3(2,0.2,0.2),Color("51463f"),-0.5)
  "obelisk":
   box(st,Vector3(0,0.4,0),Vector3(3,0.8,3),Color("c5aa75"))
   column(st,Vector3(0,4.5,0),7.4,1,0.7,Color("d7ba7b"),4)
   column(st,Vector3(0,8.8,0),1.3,0.7,0,Color("e5cf93"),4)
  "broken_column":
   for i in range(3):
    var p := Vector3((i-1)*3,0,0)
    box(st,p+Vector3.UP*0.3,Vector3(2.5,0.6,2.5),Color("918d7e"))
    column(st,p+Vector3.UP*(2+i*0.8),3.7+i*1.6,0.8,0.8,Color("9d9989"),8)
   box(st,Vector3(1.5,6.5,0),Vector3(6.5,0.8,1.9),Color("8b8679"),0.05)
  "street_shop", "ticket_booth":
   box(st,Vector3(0,2.2,0),Vector3(7,4.4,6),Color("b4b2a0"),0,8 if kind == "ticket_booth" else 2)
   box(st,Vector3(0,4.5,1),Vector3(8,0.5,8),Color("cb654a") if kind == "street_shop" else Color("d595b6"))
   box(st,Vector3(0,5.1,3.7),Vector3(5,0.8,0.18),Color("e1cc90"))
   box(st,Vector3(0,0.15,0),Vector3(8,0.3,7),Color("858c87"))
  "convenience_store":
   box(st,Vector3(0,1.8,0),Vector3(10,3.6,6.4),Color("e8ebec"),0,1)
   box(st,Vector3(0,3.85,0),Vector3(10.4,0.55,6.8),Color("2fa36b"))
   box(st,Vector3(0,3.45,0),Vector3(10.45,0.12,6.85),Color("f08a1c"))
   box(st,Vector3(0,3.0,3.3),Vector3(8,0.5,0.2),Color("fff1a8"))
   box(st,Vector3(2,5.2,-1.6),Vector3(2.4,1.8,1.6),Color("8b9296"))
   box(st,Vector3(-3.4,4.8,3.0),Vector3(2.8,1.5,0.2),Color("ffd34a"))
   box(st,Vector3(0,0.1,1.5),Vector3(12,0.2,11),Color("6c7176"))
   # 최종 실척: 주차 간격 2.72m, 스토퍼 1.7×0.14×0.22m. 전정 상면에 놓는다.
   for x in [-3.4,-1.7,0.0,1.7,3.4]: box(st,Vector3(x,.2583,4.4),Vector3(1.0625,.1167,.1333),Color("d9d9d4"))
  "gas_station":
   box(st,Vector3(0,5.4,0),Vector3(14,0.7,9),Color("f2f2ee"))
   box(st,Vector3(0,5.0,0),Vector3(14.2,0.35,9.2),Color("d6342b"))
   for x in [-5.5,5.5]:
    for z in [-3.2,3.2]: column(st,Vector3(x,2.6,z),5.2,0.16,0.16,Color("c9ccce"),6)
   for x in [-2.6,2.6]:
    box(st,Vector3(x,.8774,0),Vector3(.625,1.4348,.4118),Color("d6342b"))
    box(st,Vector3(x,1.3478,0),Vector3(.6438,.3043,.4235),Color("1c2b36"))
    box(st,Vector3(x,.08,0),Vector3(.78125,.16,2.3529),Color("8e948f"))
   box(st,Vector3(0,1.7,-8),Vector3(8,3.4,4.5),Color("d8d5c8"),0,3)
   box(st,Vector3(0,3.6,-8),Vector3(8.4,0.4,4.9),Color("d6342b"))
   column(st,Vector3(8.5,4.5,3.5),9.0,0.14,0.14,Color("737a7e"),6)
   box(st,Vector3(8.5,8.6,3.5),Vector3(3.2,2.8,0.4),Color("ffd34a"))
   box(st,Vector3(8.5,8.6,3.72),Vector3(2.7,0.6,0.1),Color("d6342b"))
   box(st,Vector3(0,0.06,-1),Vector3(17,0.12,17),Color("5e6468"))
  "apartment":
   var wall := Color("c9bfae")
   box(st,Vector3(0,8.5,0),Vector3(11,17,9),wall,0,4)
   box(st,Vector3(0,17.2,0),Vector3(11.6,0.5,9.6),Color("8d8a82"))
  "billboard":
   for x in [-3.0,3.0]: column(st,Vector3(x,5,0),10,0.28,0.24,Color("6f777c"),6)
   box(st,Vector3(0,10.4,0),Vector3(10.5,5.2,0.5),Color("33383d"))
   box(st,Vector3(0,10.4,0.28),Vector3(10,4.7,0.1),Color("f3f0e4"),0,20)
  "bus_shelter":
   box(st,Vector3(0,2.5,0),Vector3(5.2,0.42,2.2),Color("2a8aa3"))
   for x in [-2.4,2.4]: box(st,Vector3(x,1.25,0.9),Vector3(0.12,2.5,0.12),Color("3b4247"))
   box(st,Vector3(0,1.3,-0.95),Vector3(4.8,2.2,0.22),Color("a7c9d4"),0,9)
   box(st,Vector3(0,0.55,-0.5),Vector3(3.6,0.14,0.7),Color("7a5638"))
   box(st,Vector3(2.8,1.6,0.9),Vector3(0.1,3.2,0.1),Color("3b4247"))
   box(st,Vector3(2.8,3.0,0.9),Vector3(0.9,0.9,0.1),Color("2a8aa3"))
  "dock_crane":
   var steel := Color("e08a2c")
   for x in [-8.0,8.0]:
    for z in [-4.0,4.0]: column(st,Vector3(x,12,z),24,0.7,0.5,steel,6)
   for z in [-4.0,4.0]: box(st,Vector3(0,23,z),Vector3(17,1.6,1.4),steel)
   box(st,Vector3(0,12,-4),Vector3(16,0.5,0.5),steel.darkened(0.15))
   box(st,Vector3(0,12,4),Vector3(16,0.5,0.5),steel.darkened(0.15))
   box(st,Vector3(0,25.2,0),Vector3(5,3,10),Color("c8c9c2"))
   box(st,Vector3(0,24.9,-23),Vector3(2.2,2.0,38),steel)
   box(st,Vector3(0,24.9,22),Vector3(2.2,2.0,12),steel)
   for x in [-1.1,1.1]: box(st,Vector3(x,16,-10),Vector3(0.2,17,0.2),Color("3a3f44"))
   box(st,Vector3(0,12,-10),Vector3(3,1.8,6),Color("3d6f9e"))
   box(st,Vector3(0,27.5,0),Vector3(1.2,1.2,1.2),Color("e8332a"))
  "container_stack":
   var paints := [Color("a45540"),Color("466f7f"),Color("c49c4f"),Color("2f7a62"),Color("8a8f93"),Color("c9553f")]
   for row in range(3):
    for tier in range(4 if row != 1 else 3):
     var paint: Color = paints[(row*2+tier*3)%paints.size()]
     box(st,Vector3(row*2.7-2.7,1.3+tier*2.65,0),Vector3(2.5,2.55,12),paint)
     for rib in range(6): box(st,Vector3(row*2.7-2.7,1.3+tier*2.65,-5.4+rib*2.15),Vector3(2.55,2.4,0.1),paint.darkened(0.25))
  "warehouse_shed":
   box(st,Vector3(0,3.2,0),Vector3(14,6.4,26),Color("8c97a0"),0,5)
   box(st,Vector3(0,6.8,0),Vector3(14.6,0.5,26.6),Color("5f6a73"))
   box(st,Vector3(0,7.3,0),Vector3(7,0.9,26.2),Color("6f7b84"))
   for z in [-9.0,-3.0,3.0,9.0]: box(st,Vector3(7.05,3,z),Vector3(0.1,5.2,0.35),Color("6e7983"))
   box(st,Vector3(7.08,2.2,0),Vector3(0.1,4.2,5),Color("d9a73a"))
  "fuel_tank":
   for i in range(3):
    column(st,Vector3(i*9.5-9.5,4.2,0),8.4,4.2,4.2,Color("d9d9d4") if i != 1 else Color("c4472f"),12)
    column(st,Vector3(i*9.5-9.5,8.7,0),0.7,4.0,3.2,Color("9fa6a8"),12)
    box(st,Vector3(i*9.5-9.5,4.2,4.3),Vector3(0.5,8.4,0.5),Color("6f777c"))
   box(st,Vector3(0,9.6,0),Vector3(21,0.35,0.5),Color("6f777c"))
  "cargo_ship":
   box(st,Vector3(0,3.2,0),Vector3(18,6.4,86),Color("2d3e57"))
   box(st,Vector3(0,6.7,0),Vector3(18.4,0.5,86.4),Color("a8362b"))
   box(st,Vector3(0,3.5,-43.5),Vector3(10,6,2.5),Color("2d3e57"))
   box(st,Vector3(0,12,34),Vector3(12,11,10),Color("e9e9e2"))
   box(st,Vector3(0,18.2,34),Vector3(13,2,10.5),Color("2c4a66"))
   box(st,Vector3(0,22.5,34),Vector3(3,7,3),Color("c4472f"))
   var paints2 := [Color("a45540"),Color("466f7f"),Color("c49c4f"),Color("2f7a62"),Color("c9553f"),Color("8a8f93")]
   for row in range(3):
    for bay in range(7):
     for tier in range(1+(row+bay)%3):
      box(st,Vector3(row*5.4-5.4,8.2+tier*2.65,-34+bay*8.4),Vector3(5.1,2.55,8.1),paints2[(row*3+bay+tier)%paints2.size()])
  "coffee_shop":
   box(st,Vector3(0,1.9,0),Vector3(8,3.8,6),Color("b08a5e"),0,0)
   box(st,Vector3(0,3.95,0),Vector3(9,0.4,7),Color("4f3d30"))
   for i in range(6): box(st,Vector3(-3.75+i*1.5,3.2,4.2),Vector3(1.5,0.14,2.0),Color("2f8a5a") if i%2 == 0 else Color("f3eadb"),0.0)
   box(st,Vector3(-4.7,5.6,2.6),Vector3(0.12,1.8,0.12),Color("4f3d30"))
   box(st,Vector3(-4.7,5.7,2.9),Vector3(0.2,1.5,1.5),Color("f6f1e6"))
   round_part(st,Vector3(-4.7,5.5,3.7),Vector3(0.5,0.6,0.5),Color("6a4528"))
   box(st,Vector3(0,0.1,5.8),Vector3(9,0.2,4),Color("9a7a52"))
   for x in [-2.6,2.6]:
    column(st,Vector3(x,0.7,5.8),1.4,0.35,0.35,Color("f3eadb"),8)
    column(st,Vector3(x,2.2,5.8),2.6,0.04,0.04,Color("5b5148"),5)
    column(st,Vector3(x,3.3,5.8),0.5,1.6,0.0,Color("d6452f") if x < 0 else Color("2f8a5a"),8)
  "souvenir_shop":
   box(st,Vector3(0,1.8,0),Vector3(9,3.6,6),Color("efe7d6"),0,13)
   box(st,Vector3(0,3.9,0.2),Vector3(10,0.45,7.4),Color("b8432f"))
   box(st,Vector3(0,4.45,-0.2),Vector3(7,0.5,5),Color("a63a29"))
   for i in range(4):
    var x := -4.2+i*2.8
    box(st,Vector3(x,3.0,5.2),Vector3(0.1,6.0,0.1),Color("4f4a45"))
    box(st,Vector3(x+0.45,3.9,5.2),Vector3(0.8,3.4,0.05),Color("d6342b") if i%2 == 0 else Color("2c5fa6"))
  "noodle_house":
   box(st,Vector3(0,1.5,0),Vector3(9,3,7),Color("e4d9bf"),0,12)
   box(st,Vector3(0,3.3,0),Vector3(11,0.4,9),Color("3d4348"))
   box(st,Vector3(0,3.85,0),Vector3(8,0.7,6.4),Color("4a5158"))
   box(st,Vector3(0,4.4,0),Vector3(4,0.5,5),Color("3d4348"))
   for x in [-3.5,3.5]:
    round_part(st,Vector3(x,2.1,4.4),Vector3(0.7,1.0,0.7),Color("d6342b"))
    box(st,Vector3(x,2.9,4.4),Vector3(0.06,0.9,0.06),Color("3a3a3a"))
  "ryokan":
   box(st,Vector3(0,4.3,0),Vector3(17,8.6,9),Color("e9e1cf"),0,6)
   box(st,Vector3(0,5.2,0),Vector3(19,0.5,11),Color("4a5760"))
   box(st,Vector3(0,9.0,0),Vector3(17,0.6,10),Color("4a5760"))
   box(st,Vector3(0,9.7,0),Vector3(9,0.8,8),Color("3f4a52"))
  "vending_row":
   var cols := [Color("d6342b"),Color("2c5fa6"),Color("2f8a5a"),Color("e0a030")]
   for i in range(4):
    box(st,Vector3(-2.4+i*1.6,1.1,0),Vector3(1.2,2.2,0.9),cols[i])
    box(st,Vector3(-2.4+i*1.6,1.3,0.47),Vector3(0.9,1.3,0.05),Color("f4f6f2"))
   box(st,Vector3(0,2.5,0.1),Vector3(7.4,0.2,2.0),Color("5b5148"))
   box(st,Vector3(0,0.06,0.4),Vector3(7.6,0.12,2.6),Color("858c87"))
  "containers":
   for i in range(3):
    box(st,Vector3((i%2)*3.3,1.5+(i/2)*3.1,0),Vector3(3.1,3,8),Color(["a45540","466f7f","c49c4f"][i]))
    for rib in range(8): box(st,Vector3((i%2)*3.3+1.58,1.5+(i/2)*3.1,-3.5+rib),Vector3(0.08,2.8,0.1),Color("73867e"))
  "torii":
   for side in [-1,1]:
    column(st,Vector3(side*2.6,3.2,0),6.4,0.32,0.24,Color("bc493a"))
    box(st,Vector3(side*2.6,0.3,0),Vector3(1.2,0.6,1.2),Color("626762"))
   box(st,Vector3(0,5.0,0),Vector3(6.3,0.5,0.5),Color("bf4b39"))
   box(st,Vector3(0,6.4,0),Vector3(8.2,0.5,1.0),Color("393f3c"))
   box(st,Vector3(0,5.8,0),Vector3(0.4,0.9,0.4),Color("d1a95c"))
  "pagoda":
   box(st,Vector3(0,0.4,0),Vector3(7,0.8,7),Color("7b8077"))
   for tier in range(3):
    var w := 6.0-tier*1.2
    var y := 1.8+tier*2.5
    box(st,Vector3(0,y,0),Vector3(w*0.7,2,w*0.7),Color("c0a17a"),0,10)
    box(st,Vector3(0,y,0),Vector3(w*0.78,0.5,w*0.78),Color("944637"))
    column(st,Vector3(0,y+1.5,0),1.4,w*0.8,w*0.22,Color("405754"),4)
   column(st,Vector3(0,9.7,0),2.0,0.15,0.05,Color("cfb76c"))
  "teahouse":
   box(st,Vector3(0,0.3,0),Vector3(10,0.6,8),Color("777e70"))
   box(st,Vector3(0,2.2,0),Vector3(8,3.8,6),Color("d5c4a5"),0,7)
   for side in [-1,1]:
    box(st,Vector3(side*3.8,2,3.1),Vector3(0.28,3.6,0.25),Color("77523e"))
   column(st,Vector3(0,4.5,0),2.0,6.7,2.1,Color("3f5755"),4)
  "bridge":
   box(st,Vector3(0,2,0),Vector3(13,0.6,4),Color("9d4d3e"))
   for x in [-5.5,-2.8,0.0,2.8,5.5]:
    for side in [-1,1]: box(st,Vector3(x,2.8,side*1.8),Vector3(0.25,1.8,0.25),Color("c95e43"))
    box(st,Vector3(x,0.9,0),Vector3(0.7,1.8,3.5),Color("747d70"))
   for side in [-1,1]: box(st,Vector3(0,3.4,side*1.8),Vector3(13,0.25,0.3),Color("c95e43"))
  _:
   round_part(st,Vector3(0,1,0),Vector3(3,2,3),Color("596d59"))
 if BUILDING_DIMS.has(kind): architectural_mass(st,kind)
 st.index()
 var result := metre_mesh(st.commit(),kind)
 mesh_cache[kind] = result
 return result

static func rural_model(index: int) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_uv(Vector2.ZERO)
 st.set_uv2(Vector2.ZERO)
 var size: Vector3 = RURAL_DIMS[index]
 var roof_height: float = [2.1,1.8,1.5,2.8,3.2,.45,1.4,.6,2.2,1.0][index]
 var roof_color := Color(["944d36","516b59","70544b","69554a","3f657c","52725d","a95036","7c7c55","536f82","7c8280"][index])
 box(st,Vector3(0,.1,0),Vector3(size.x+.8,.55,size.z+.8),Color("858375"))
 box(st,Vector3(0,size.y*.5+.35,0),size,Color.WHITE,0,30+index)
 var roof := PrismMesh.new()
 roof.size = Vector3(size.x+1.2,roof_height,size.z+1.2)
 append(st,roof,Transform3D(Basis.IDENTITY,Vector3(0,size.y+.35+roof_height*.5,0)),roof_color)
 # 처마 끝·석재 기단·모서리는 텍스처와 별개의 실제 부피를 가진다.
 for side in [-1.0,1.0]:
  box(st,Vector3(side*size.x*.5,size.y*.5+.35,size.z*.5+.06),Vector3(.18,size.y,.2),Color("aaa18b"))
 box(st,Vector3(0,size.y+.35,size.z*.5+.15),Vector3(size.x+1.3,.2,.3),roof_color.darkened(.2))
 if index in [0,2,3,4,8]:
  var y := 3.2
  box(st,Vector3(0,y,size.z*.5+1.1),Vector3(size.x*.85,.2,2.8),roof_color)
  for side in [-1.0,1.0]: box(st,Vector3(side*size.x*.38,y*.5,size.z*.5+2.1),Vector3(.18,y,.18),Color("b5a78a"))
 if index in [1,2,4]:
  box(st,Vector3(size.x*.28,size.y+roof_height*.6,0),Vector3(.85,2.2,1),Color("81786c"))
 if index in [3,8]:
  box(st,Vector3(0,3.3,size.z*.5+1),Vector3(size.x*.7,.22,2.4),Color("695143"))
  box(st,Vector3(0,4.3,size.z*.5+2),Vector3(size.x*.7,.12,.13),Color("594534"))
  for post in range(9): box(st,Vector3((post-4)*size.x*.075,3.8,size.z*.5+2),Vector3(.08,1,.08),Color("594534"))
 if index in [5,6,7,8]:
  for strip in range(6):
   var x: float = -size.x*.45+(strip+.5)*size.x*.15
   box(st,Vector3(x,3.25,size.z*.5+1.1),Vector3(size.x*.15,.18,2.6),roof_color if strip%2==0 else Color("e5d6b5"))
  if index in [5,7]:
   for crate in range(3):
    var at := Vector3((crate-1)*2.3,.65,size.z*.5+1.1)
    box(st,at,Vector3(1.8,.7,1.1),Color("8b653c"))
    for fruit in range(9): round_part(st,at+Vector3((fruit%3-1)*.48,.5,(fruit/3-1)*.3),Vector3.ONE*.28,Color("d3a43d") if crate%2==0 else Color("9f5137"))
 if index == 9:
  for tire in range(3): column(st,Vector3(-size.x*.38,.3+tire*.35,size.z*.5+.8),.3,.55,.55,Color("303638"),10)
 st.index()
 return st.commit()

static func metre_mesh(source: ArrayMesh, kind: String) -> ArrayMesh:
 var factor: Vector3 = METRE_SCALE.get(kind,Vector3.ONE)
 if MATURE_TREE_HEIGHT.has(kind): factor = Vector3.ONE*float(MATURE_TREE_HEIGHT[kind])/source.get_aabb().size.y
 if factor == Vector3.ONE: return source
 var arrays: Array = source.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 for i in range(vertices.size()):
  vertices[i] *= factor
  normals[i] = (normals[i]/factor).normalized()
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 var result := ArrayMesh.new()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result

static func placement_scale(kind: String, requested: float) -> float:
 # 매장·간판은 실제 치수를 유지하고 나무만 제한된 생장 변형을 허용한다.
 if BUILDING_DIMS.has(kind) or kind == "billboard": return clampf(requested,.97,1.08)
 if METRE_SCALE.has(kind) or Models.is_tree(kind): return clampf(requested,.9,1.18)
 return requested

static func architectural_mass(st: SurfaceTool, kind: String) -> void:
 # 외벽 이미지를 평면 카드로 두지 않고 기단·모서리 기둥·깊은 창턱을 실제 메시로 만든다.
 var size: Vector3 = BUILDING_DIMS[kind]
 var offset := Vector3(0,0,-8) if kind == "gas_station" else Vector3.ZERO
 var stone := Color("797971")
 var trim := Color("b2aaa0")
 box(st,offset+Vector3.UP*.22,Vector3(size.x+.65,.44,size.z+.65),stone)
 box(st,offset+Vector3.UP*.52,Vector3(size.x+.2,.2,size.z+.2),stone.lightened(.12))
 for x in [-1.0,1.0]:
  for z in [-1.0,1.0]:
   box(st,offset+Vector3(x*(size.x*.5-.05),size.y*.5,z*(size.z*.5-.05)),Vector3(.34,size.y,.34),trim)
 box(st,offset+Vector3(0,size.y-.12,0),Vector3(size.x+.35,.28,size.z+.35),trim.darkened(.15))
 var floors := 5 if kind == "apartment" else (2 if kind == "ryokan" else 1)
 var columns := 4 if kind == "apartment" else (6 if kind == "ryokan" else 3)
 for floor_index in range(floors):
  var y: float = (floor_index+.22)*size.y/floors+.45
  for column_index in range(columns):
   var x: float = -size.x*.5+(column_index+.5)*size.x/columns
   var w: float = size.x/columns*.76
   box(st,offset+Vector3(x,y,size.z*.5+.12),Vector3(w,.16,.48),stone)
   if floors > 1:
    box(st,offset+Vector3(x,y+2.1,size.z*.5+.09),Vector3(w,.18,.34),trim)
    for side in [-1.0,1.0]: box(st,offset+Vector3(x+side*w*.5,y+1,size.z*.5+.08),Vector3(.13,2.1,.24),trim)
    box(st,offset+Vector3(x,y,size.z*.5+.6),Vector3(w+.2,.22,1.25),stone)
    box(st,offset+Vector3(x,y+.95,size.z*.5+1.1),Vector3(w+.2,.09,.09),Color("444c4e"))
    for bar in range(3): box(st,offset+Vector3(x+(bar-1)*w*.4,y+.48,size.z*.5+1.1),Vector3(.055,.9,.055),Color("444c4e"))
