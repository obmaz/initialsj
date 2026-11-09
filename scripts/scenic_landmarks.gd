extends Node3D
# 투어와 서킷이 공유하는 원본 입체 구조물입니다. 도로 안에는 장식 충돌체를 놓지 않습니다.
const AD_TEXTURES := [preload("res://assets/environment/ad-aerova.svg"),preload("res://assets/environment/ad-shift.svg"),preload("res://assets/environment/ad-fizz.svg"),preload("res://assets/environment/ad-apex.svg")]
var track: Node3D
var bridge_span := Vector2.ZERO
var canyon_spans: Array[Vector2] = []
var batches: Array[MultiMeshInstance3D] = []
var billboard_manifest: Array[Dictionary] = []
var tower_distances: Array[float] = []
var bridge_clearance := 68.0

func _ready() -> void:
	if bridge_span.y > bridge_span.x: make_bridge()
	for span in canyon_spans:
		make_canyon(span)
		make_billboards(span)

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat

func boxes(label: String, poses: Array[Transform3D], color: Color, shadows: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()): multi.set_instance_transform(i,poses[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material(color)
	if not shadows: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batches.append(node)

func beam(a: Vector3, b: Vector3, width: float) -> Transform3D:
	var direction := (b-a).normalized()
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	return Transform3D(Basis.looking_at(direction,up).scaled_local(Vector3(width,width,a.distance_to(b))),(a+b)*0.5)

func cable_height(d: float) -> float:
	var a := bridge_span.x+95
	var b := bridge_span.y-95
	if d < a: return lerpf(4,90,(d-bridge_span.x)/(a-bridge_span.x))
	if d > b: return lerpf(90,4,(d-b)/(bridge_span.y-b))
	return 22+68*pow((d-(a+b)*0.5)/((b-a)*0.5),2)

func make_bridge() -> void:
	var towers: Array[Transform3D] = []
	var cables: Array[Transform3D] = []
	var hangers: Array[Transform3D] = []
	var ribs: Array[Transform3D] = []
	for d in [bridge_span.x+95,bridge_span.y-95]:
		tower_distances.append(d)
		var w: float = track.half_width(d)+6
		for side in [-1.0,1.0]:
			var foot: Vector3 = track.point(d,side*w)
			towers.append(beam(foot-Vector3.UP*50,foot+Vector3.UP*96,4.2))
		for h in [bridge_clearance,90.0]: towers.append(beam(track.point(d,-w)+Vector3.UP*h,track.point(d,w)+Vector3.UP*h,3.6))
	var count := int(ceil((bridge_span.y-bridge_span.x)/8))
	for i in range(count):
		var a := lerpf(bridge_span.x,bridge_span.y,float(i)/count)
		var b := lerpf(bridge_span.x,bridge_span.y,float(i+1)/count)
		for side in [-1.0,1.0]:
			var lane: float = side*(track.half_width(a)+5)
			cables.append(beam(track.point(a,lane)+Vector3.UP*cable_height(a),track.point(b,side*(track.half_width(b)+5))+Vector3.UP*cable_height(b),0.62))
			ribs.append(beam(track.point(a,side*(track.half_width(a)+1.5))-Vector3.UP*2.2,track.point(b,side*(track.half_width(b)+1.5))-Vector3.UP*2.2,1.5))
			if i%3 == 0: hangers.append(beam(track.point(a,lane)+Vector3.UP*0.6,track.point(a,lane)+Vector3.UP*cable_height(a),0.20))
		if i%4 == 0: ribs.append(beam(track.point(a,-track.half_width(a)-1.5)-Vector3.UP*2.2,track.point(a,track.half_width(a)+1.5)-Vector3.UP*2.2,0.9))
	boxes("ScarletBridgeTowers",towers,Color("ad3e30"))
	boxes("MainSuspensionCables",cables,Color("bd5841"),false)
	boxes("VerticalHangers",hangers,Color("d98a63"),false)
	boxes("BridgeDeckGirders",ribs,Color("6c5146"))

func cliff_point(d: float, side: float, tier: int) -> Vector3:
	var offsets := [32.0,40.0,56.0,68.0,102.0,180.0]
	var heights := [-2.0,36.0,44.0,78.0,96.0,110.0]
	var envelope := smoothstep(0,110,d-current_span.x)*(1-smoothstep(current_span.y-110,current_span.y,d))
	var ripple := sin(d*0.033+side*1.7)*3+sin(d*0.011)*5
	var lane: float = side*(track.half_width(d)+offsets[tier]+(0 if tier == 0 else ripple))
	var bend: float = track.curvature(d)
	if side*bend < 0:
		lane = side*minf(absf(lane),maxf(track.half_width(d)+40,0.64/maxf(absf(bend),0.0001)))
	var p: Vector3 = track.point(d,lane)
	p.y += heights[tier]*envelope+(0 if tier == 0 else ripple*envelope)
	return p

var current_span := Vector2.ZERO
func make_canyon(span: Vector2) -> void:
	current_span = span
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(ceil((span.y-span.x)/14))
	for side in [-1.0,1.0]:
		for i in range(count):
			var a := lerpf(span.x,span.y,float(i)/count)
			var b := lerpf(span.x,span.y,float(i+1)/count)
			for tier in range(5):
				var points := [cliff_point(a,side,tier),cliff_point(a,side,tier+1),cliff_point(b,side,tier),cliff_point(b,side,tier+1)]
				for index in ([0,1,2,1,3,2] if side > 0 else [0,2,1,1,2,3]): st.add_vertex(points[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "LayeredCanyonWalls"
	node.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sandstone.gdshader")
	node.material_override = mat
	add_child(node)

func make_billboards(span: Vector2) -> void:
	var posts: Array[Transform3D] = []
	for i in range(int((span.y-span.x-160)/135)):
		var d := span.x+100+i*135
		var side := -1.0 if i%2 == 0 else 1.0
		var lane: float = side*(track.half_width(d)+18)
		var p: Vector3 = track.point(d,lane)
		var board := MeshInstance3D.new()
		board.name = "FictionalAdvertisement"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(23,10)
		board.mesh = mesh
		board.position = p+Vector3.UP*12
		board.rotation.y = track.heading(d)+side*0.22
		var mat := material(Color.WHITE)
		mat.albedo_texture = AD_TEXTURES[i%4]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		board.material_override = mat
		board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(board)
		for offset in [-7.0,7.0]:
			var foot: Vector3 = p+board.basis.x*offset
			posts.append(beam(foot-Vector3.UP*2,foot+Vector3.UP*6.9,0.65))
		billboard_manifest.append({"distance":d,"lane":lane,"width":23.0,"height":10.0,"position":board.position,"basis":board.basis})
	boxes("BillboardSteelSupports",posts,Color("49423b"),false)
