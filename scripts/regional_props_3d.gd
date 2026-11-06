extends Node3D
# Opaque, low-poly meshes shared by every instance. No camera-facing foreground art.
const FAMILIES := {
 "hawaii":["palm","palm","broadleaf"], "jeju":["basalt","pine","broadleaf"],
 "fuji":["pine","sakura","japanese_pine"], "bamboo":["bamboo","bamboo","basalt"],
 "snow":["snow_pine","snow_pine","basalt"], "volcano":["basalt","charred","basalt"],
 "desert":["cactus","sandstone","cactus"], "pyramid":["obelisk","palm","sandstone"],
 "canyon":["sandstone","cactus","sandstone"], "city":["broadleaf","street_shop","plane_tree"],
 "seoul":["ginkgo","street_shop","pine"], "neon":["street_shop","plane_tree","broadleaf"],
 "ruins":["broken_column","charred","basalt"], "harbor":["containers","palm","containers"],
 "amusement":["ticket_booth","broadleaf","sakura"]
}
static var mesh_cache: Dictionary = {}
static var shared_material: StandardMaterial3D
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
  shared_material = StandardMaterial3D.new()
  shared_material.vertex_color_use_as_albedo = true
  shared_material.vertex_color_is_srgb = true
  shared_material.roughness = 0.95
  shared_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
 var groups: Dictionary = {}
 for i in range(placements.size()):
  var p: Dictionary = placements[i]
  var family: Array = FAMILIES.get(theme,FAMILIES.hawaii)
  var kind: String = p.get("kind",family[int(p.get("variant",i))%family.size()])
  var group := kind+":"+str(floori(p.position.x/180))+":"+str(floori(p.position.z/180))
  if not groups.has(group): groups[group] = {"kind":kind,"poses":[]}
  var scale: float = p.get("scale",1.0)
  var transform := Transform3D(Basis(Vector3.UP,float(p.get("yaw",0))).scaled_local(Vector3.ONE*scale),p.position)
  groups[group].poses.append(transform)
  var bounds: AABB = transform*model(kind).get_aabb()
  world_bounds.append(bounds)
  if kind in ["palm","broadleaf","pine","snow_pine","sakura","bamboo","plane_tree","ginkgo","charred","japanese_pine"]: tree_count += 1
 for group in groups:
  var kind: String = groups[group].kind
  var poses: Array = groups[group].poses
  # Split long roads into small spatial batches, so a curve cannot make the
  # entire route's props submit every frame under one enormous MultiMesh AABB.
  for start in range(0,poses.size(),12):
   var multi := MultiMesh.new()
   multi.transform_format = MultiMesh.TRANSFORM_3D
   multi.mesh = model(kind)
   multi.instance_count = mini(12,poses.size()-start)
   for i in range(multi.instance_count): multi.set_instance_transform(i,poses[start+i])
   var node := MultiMeshInstance3D.new()
   node.name = "Regional3D_"+kind+"_"+str(start)
   node.multimesh = multi
   node.material_override = shared_material
   node.visibility_range_end = 400 if kind in ["palm","pine","snow_pine"] else 310
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
 return maxf(Vector2(bounds.position.x,bounds.position.z).length(),Vector2(bounds.end.x,bounds.end.z).length())
static func box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, yaw: float = 0) -> void:
 var mesh := BoxMesh.new()
 mesh.size = Vector3.ONE
 append(st,mesh,Transform3D(Basis(Vector3.UP,yaw).scaled_local(size),center),color)
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
static func append(st: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color) -> void:
 var data := mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
 var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
 var normal_basis := transform.basis.inverse().transposed()
 for i in range(indices.size() if not indices.is_empty() else vertices.size()):
  var index: int = indices[i] if not indices.is_empty() else i
  st.set_color(color)
  st.set_normal((normal_basis*normals[index]).normalized())
  st.add_vertex(transform*vertices[index])
static func model(kind: String) -> ArrayMesh:
 if mesh_cache.has(kind): return mesh_cache[kind]
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var bark := Color("73513a")
 var green := Color("367a48")
 match kind:
  "palm":
   for i in range(4):
    column(st,Vector3(sin(i*0.4)*0.5,1.15+i*2.1,0),2.3,0.31-i*0.035,0.28-i*0.035,bark)
   var center := Vector3(0.5,8.4,0)
   for leaf in range(9):
    var angle := leaf*TAU/9
    var f := Vector3(cos(angle),0,sin(angle))
    var right := Vector3(-f.z,0,f.x)
    for part in range(5):
     var t := part/5.0
     var u := (part+1)/5.0
     var a := center+f*t*4.7+Vector3.UP*(sin(t*PI)*1.3-t*1.2)
     var b := center+f*u*4.7+Vector3.UP*(sin(u*PI)*1.3-u*1.2)
     var points := [a-right*sin(t*PI)*0.6,a+right*sin(t*PI)*0.6,b-right*sin(u*PI)*0.6,b+right*sin(u*PI)*0.6]
     for n in [0,2,1,1,2,3,0,1,2,1,3,2]:
      st.set_color(Color("398452") if leaf%2 == 0 else Color("4a9a57"))
      st.set_normal(Vector3.UP)
      st.add_vertex(points[n])
   for i in range(3): round_part(st,center+Vector3(cos(i*2.0)*0.4,-0.2,sin(i*2.0)*0.4),Vector3.ONE*0.5,Color("756143"))
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
   box(st,Vector3(0,2.2,0),Vector3(7,4.4,6),Color("b4b2a0"))
   box(st,Vector3(0,2.2,3.04),Vector3(5.8,2.5,0.1),Color("285766"))
   box(st,Vector3(0,4.5,1),Vector3(8,0.5,8),Color("cb654a") if kind == "street_shop" else Color("d595b6"))
   box(st,Vector3(0,5.1,3.7),Vector3(5,0.8,0.18),Color("e1cc90"))
   box(st,Vector3(0,0.15,0),Vector3(8,0.3,7),Color("858c87"))
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
    box(st,Vector3(0,y,0),Vector3(w*0.7,2,w*0.7),Color("c0a17a"))
    box(st,Vector3(0,y,0),Vector3(w*0.78,0.5,w*0.78),Color("944637"))
    column(st,Vector3(0,y+1.5,0),1.4,w*0.8,w*0.22,Color("405754"),4)
   column(st,Vector3(0,9.7,0),2.0,0.15,0.05,Color("cfb76c"))
  "teahouse":
   box(st,Vector3(0,0.3,0),Vector3(10,0.6,8),Color("777e70"))
   box(st,Vector3(0,2.2,0),Vector3(8,3.8,6),Color("d5c4a5"))
   for side in [-1,1]:
    box(st,Vector3(side*3.8,2,3.1),Vector3(0.28,3.6,0.25),Color("77523e"))
   box(st,Vector3(0,2.2,3.1),Vector3(6.8,2.7,0.1),Color("4c6462"))
   column(st,Vector3(0,4.5,0),2.0,6.7,2.1,Color("3f5755"),4)
  "bridge":
   box(st,Vector3(0,2,0),Vector3(13,0.6,4),Color("9d4d3e"))
   for x in [-5.5,-2.8,0.0,2.8,5.5]:
    for side in [-1,1]: box(st,Vector3(x,2.8,side*1.8),Vector3(0.25,1.8,0.25),Color("c95e43"))
    box(st,Vector3(x,0.9,0),Vector3(0.7,1.8,3.5),Color("747d70"))
   for side in [-1,1]: box(st,Vector3(0,3.4,side*1.8),Vector3(13,0.25,0.3),Color("c95e43"))
  _:
   round_part(st,Vector3(0,1,0),Vector3(3,2,3),Color("596d59"))
 st.index()
 var result := st.commit()
 mesh_cache[kind] = result
 return result
