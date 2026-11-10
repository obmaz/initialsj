extends Node3D
var scenery: Node3D
var swing: Node3D
var elapsed := 0.0
var carousel: Node3D
var coaster_samples := 0
func beam(a: Vector3,b: Vector3,width: float) -> Transform3D:
 var axis := (b-a).normalized()
 var x := axis.cross(Vector3.FORWARD).normalized()
 if x.length_squared() < .01: x = axis.cross(Vector3.UP).normalized()
 return Transform3D(Basis(x,axis,x.cross(axis)).scaled_local(Vector3(width,a.distance_to(b),width)),(a+b)*.5)
func _ready() -> void:
 var road: Node3D = scenery.track
 var site_distance := 1120.0
 var lane := -180.0
 for candidate in range(6):
  var site: Vector3 = scenery.terrain_point(site_distance,lane)
  var nearest: float = road.curve.get_closest_offset(site)
  if site.distance_to(road.point(nearest)) > 135: break
  lane -= 60
 position = scenery.terrain_point(site_distance,lane)
 rotation.y = road.heading(1120)
 var red: Material = scenery.mat(Color("b64335"),.5)
 var steel: Material = scenery.mat(Color("c3c9cb"),.6)
 var wood: Material = scenery.mat(Color("775338"))
 var rails: Array[Transform3D] = []
 var ties: Array[Transform3D] = []
 var posts: Array[Transform3D] = []
 for i in range(160):
  var a := TAU*i/160.0
  var b := TAU*(i+1)/160.0
  var p := Vector3(cos(a)*68,26+12*sin(a*2)+7*cos(a*3),sin(a)*43)
  var q := Vector3(cos(b)*68,26+12*sin(b*2)+7*cos(b*3),sin(b)*43)
  var across := (q-p).cross(Vector3.UP).normalized()
  for side in [-1,1]: rails.append(beam(p+across*side*1.1,q+across*side*1.1,.34))
  ties.append(beam(p-across*1.5,p+across*1.5,.28))
  if i%5 == 0:
   posts.append(beam(Vector3(p.x,0,p.z),p,.65))
   posts.append(beam(Vector3(p.x+5,0,p.z),p,.4))
  coaster_samples += 1
 boxes(red,rails)
 boxes(steel,ties)
 boxes(steel,posts)
 # 역 플랫폼, 열차 5량과 안전 난간.
 var platform: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(Vector3(25,1.2,10)),Vector3(0,18,48))]
 boxes(wood,platform)
 var cars: Array[Transform3D] = []
 for i in range(5):
  var a := .2+i*.055
  var p := Vector3(cos(a)*68,27.3+12*sin(a*2)+7*cos(a*3),sin(a)*43)
  cars.append(Transform3D(Basis(Vector3.UP,atan2(-sin(a)*68,cos(a)*43)).scaled_local(Vector3(2.3,1.6,3)),p))
 boxes(scenery.mat(Color("f0b82c"),.3),cars)
 # 바이킹: 4개 A형 지주, 회전축과 실제 두께의 선체·벤치.
 var base := Vector3(-26,0,-78)
 var frame: Array[Transform3D] = []
 for x in [-7,7]:
  for z in [-6,6]: frame.append(beam(base+Vector3(x,0,z),base+Vector3(0,20,z),.9))
 frame.append(beam(base+Vector3(0,20,-7),base+Vector3(0,20,7),1.1))
 boxes(steel,frame)
 swing = Node3D.new()
 swing.position = base+Vector3.UP*20
 add_child(swing)
 var arms: Array[Transform3D] = []
 for z in [-5,5]: arms.append(beam(Vector3(0,0,z),Vector3(0,-13,z),.45))
 boxes(red,arms,swing)
 var boat: Array[Transform3D] = []
 for i in range(11):
  var x := (i-5)*1.6
  var rise := pow(absf(x)/8,2)*3
  boat.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.7,1.0+rise,6)),Vector3(x,-14+rise*.5,0)))
  for z in [-3,3]: boat.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.7,1.4,.35)),Vector3(x,-12.9+rise,z)))
 boxes(wood,boat,swing)
 # 회전목마: 단단한 원형 기단·원뿔 지붕·좌석·황동 기둥.
 carousel = Node3D.new()
 carousel.position = Vector3(45,0,-78)
 add_child(carousel)
 for layer in range(3):
  var node := MeshInstance3D.new()
  var mesh := CylinderMesh.new()
  mesh.bottom_radius = 13 if layer != 1 else .65
  mesh.top_radius = 0 if layer == 2 else mesh.bottom_radius
  mesh.height = 6 if layer == 2 else (10 if layer == 1 else 1)
  mesh.radial_segments = 24
  node.mesh = mesh
  node.position.y = 11 if layer == 2 else (5 if layer == 1 else .6)
  node.material_override = scenery.mat(Color("b95575") if layer == 2 else Color("d5b469"),.3)
  carousel.add_child(node)
 var seats: Array[Transform3D] = []
 var poles: Array[Transform3D] = []
 for i in range(10):
  var p := Vector3(cos(i*TAU/10)*9,0,sin(i*TAU/10)*9)
  seats.append(Transform3D(Basis(Vector3.UP,-i*TAU/10).scaled_local(Vector3(1.8,1.5,3)),p+Vector3.UP*2))
  poles.append(beam(p+Vector3.UP,p+Vector3.UP*9,.16))
 boxes(wood,seats,carousel)
 boxes(steel,poles,carousel)
 # 야외 광장·매점·벤치·조명 기둥. 주행로와 분리된 공원 부지.
 var paving: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(Vector3(170,.4,190)),Vector3(0,.25,-15))]
 var paving_material: StandardMaterial3D = scenery.mat(Color("b0aaa0"))
 paving_material.albedo_texture = load("res://assets/environment/asphalt.png")
 paving_material.uv1_scale = Vector3(24,24,24)
 boxes(paving_material,paving)
 for i in range(12):
  var at := Vector3(-75+i*13,0,72)
  var kiosk: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(Vector3(8,4,7)),at+Vector3.UP*2),Transform3D(Basis.IDENTITY.scaled(Vector3(9,.6,8)),at+Vector3.UP*4.2)]
  boxes(scenery.mat(Color.from_hsv(i/12.0,.42,.78)),kiosk)
 var benches: Array[Transform3D] = []
 for i in range(16):
  var p := Vector3(-76+i*10,.8,60)
  benches.append(Transform3D(Basis.IDENTITY.scaled(Vector3(4,.25,1.2)),p))
  benches.append(Transform3D(Basis.IDENTITY.scaled(Vector3(4,1.0,.2)),p+Vector3(0,.5,.6)))
 boxes(wood,benches)
 add_shops()
func add_shops() -> void:
 var props := preload("res://scripts/regional_props_3d.gd").new()
 var placements: Array[Dictionary] = []
 var kinds := ["coffee_shop","souvenir_shop","street_shop","noodle_house"]
 for i in range(4):
  var point: Vector3 = to_global(Vector3(-114+i*76,.45,135))
  placements.append({"kind":kinds[i],"position":point,"yaw":rotation.y+PI,"scale":1.0})
 var road: Node3D = scenery.track
 for i in range(10):
  var d := 380.0+i*135
  var lane: float = (1 if i%2 else -1)*(road.half_width(d)+road.rail_setback(d,1 if i%2 else -1)+23)
  var point: Vector3 = road.roadside_point(d,lane)
  var nearest: float = road.curve.get_closest_offset(point)
  if point.distance_to(road.point(nearest)) < road.half_width(nearest)+18: continue
  placements.append({"kind":"billboard","position":point,"yaw":preload("res://scripts/billboard_facing.gd").yaw(road,d,lane),"scale":1.0})
 props.configure("amusement",placements)
 # 배치 좌표는 월드 기준이므로 공원의 회전·이동을 다시 적용하지 않는다.
 scenery.add_child(props)
 props.name="AmusementShopsAndAds"
func boxes(material: Material, poses: Array[Transform3D], parent: Node3D = self) -> void:
 var mesh := BoxMesh.new()
 mesh.size = Vector3.ONE
 var multi := MultiMesh.new()
 multi.transform_format = MultiMesh.TRANSFORM_3D
 multi.mesh = mesh
 multi.instance_count = poses.size()
 for i in range(poses.size()): multi.set_instance_transform(i,poses[i])
 var node := MultiMeshInstance3D.new()
 node.multimesh = multi
 node.material_override = material
 node.visibility_range_end = 850
 parent.add_child(node)
func _process(delta: float) -> void:
 if not is_visible_in_tree() or not scenery.is_processing(): return
 elapsed += delta
 if swing != null: swing.rotation.z = sin(elapsed*.72)*.85
 if carousel != null: carousel.rotation.y = elapsed*.18
