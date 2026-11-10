extends Node3D
# 투어와 서킷이 공유하는 원본 입체 구조물입니다. 도로 안에는 장식 충돌체를 놓지 않습니다.
const Ads = preload("res://scripts/advertisement_library.gd")
var track: Node3D
var bridge_span := Vector2.ZERO
var canyon_spans: Array[Vector2] = []
var batches: Array[MultiMeshInstance3D] = []
var billboard_manifest: Array[Dictionary] = []
var tower_distances: Array[float] = []
var bridge_clearance := 68.0
var ad_size := Vector2(20,8.75)
const AD_METRE_SCALE := 1.25
var texture_regions: Array[Vector3] = []
var advertisement_spans: Array[Vector2] = []
var ad_spacing := 135.0

func _ready() -> void:
	if bridge_span.y > bridge_span.x: make_bridge()
	for span in canyon_spans:
		make_canyon(span)
		if advertisement_spans.is_empty(): make_billboards(span)
	for span in advertisement_spans: make_billboards(span)

func advertisement_material(index: int) -> Material:
	return Ads.material(index)

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat

func boxes(label: String, poses: Array[Transform3D], color: Color, shadows: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat: Material = material(color)
	if "Concrete" in label or label == "BridgeStructuralDeck": mat = textured_surface(Vector2(1,0),Color.WHITE,.18,0.0,.9,true,true)
	elif label.begins_with("Bridge") and "Foundations" not in label: mat = steel(color)
	elif label.begins_with("Billboard") and "Lens" not in label: mat = textured_surface(Vector2(1,1),color.lightened(.55),.65,.35,.65,true,false)
	instances(label,mesh,poses,mat,shadows)

func instances(label: String, mesh: Mesh, poses: Array[Transform3D], mat: Material, shadows: bool = true) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()):
		multi.set_instance_transform(i,poses[i])
		var origin := poses[i].origin
		var variant := fposmod(floor(origin.x*.071)+floor(origin.z*.053),2.0)
		if label.begins_with("Billboard"):
			var nearest := INF
			for region in range(texture_regions.size()):
				var gap := origin.distance_squared_to(texture_regions[region])
				if gap < nearest:
					nearest = gap
					variant = float(region%2)
		multi.set_instance_custom_data(i,Color(.25+.5*variant,0,0,1))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = mat
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

# 원형 케이블과 지지대는 10면 단면을 공유하여 긴 구조물의 모서리를 줄입니다.
func tubes(label: String, poses: Array[Transform3D], color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 10
	mesh.rings = 1
	var turned: Array[Transform3D] = []
	for pose in poses: turned.append(pose*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO))
	instances(label,mesh,turned,textured_surface(Vector2(1,1),color.lightened(.4),1.0,.65,.53),false)

func textured_surface(tile: Vector2, tint: Color, scale: float, metallic: float, roughness: float, varied: bool = false, concrete: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/painted_steel.gdshader")
	mat.set_shader_parameter("material_atlas",preload("res://assets/environment/generated-structure-variants.png") if varied else preload("res://assets/environment/generated-material-atlas.png"))
	mat.set_shader_parameter("instance_variation",varied)
	mat.set_shader_parameter("concrete_family",concrete)
	mat.set_shader_parameter("material_tile",tile)
	mat.set_shader_parameter("paint_color",tint)
	mat.set_shader_parameter("texture_scale",scale)
	mat.set_shader_parameter("metalness",metallic)
	mat.set_shader_parameter("surface_roughness",roughness)
	return mat

func steel(_color: Color) -> ShaderMaterial:
	return textured_surface(Vector2(0,1),Color("d5bfb2"),.65,.25,.66)

func make_bridge() -> void:
	var cables: Array[Transform3D] = []
	var hangers: Array[Transform3D] = []
	var ribs: Array[Transform3D] = []
	var bracing: Array[Transform3D] = []
	var fittings: Array[Transform3D] = []
	var foundations: Array[Transform3D] = []
	var deck_slabs: Array[Transform3D] = []
	var tower_mesh := SurfaceTool.new()
	tower_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for d in [bridge_span.x+95,bridge_span.y-95]:
		tower_distances.append(d)
		var w: float = track.half_width(d)+6.8
		var basis := Basis(Vector3.UP,track.heading(d))
		for side in [-1.0,1.0]:
			var foot: Vector3 = track.point(d,side*w)
			# 기초와 하부 기둥은 실제 수면까지 내려갑니다.
			var base_y := minf(foot.y-8,-5)
			foundations.append(Transform3D(basis.scaled_local(Vector3(10,14,12)),Vector3(foot.x,base_y+3,foot.z)))
			var levels := [base_y-foot.y+8,0.0,32.0,64.0,96.0]
			for level in range(4):
				var corners: Array[Vector3] = []
				for y in [levels[level],levels[level+1]]:
					var width := lerpf(5.4,3.0,clampf((y+15)/111,0,1))
					var depth := width*1.24
					for v in [Vector2(-.5,-.42),Vector2(-.42,-.5),Vector2(.42,-.5),Vector2(.5,-.42),Vector2(.5,.42),Vector2(.42,.5),Vector2(-.42,.5),Vector2(-.5,.42)]:
						corners.append(foot+basis*Vector3(v.x*width,y,v.y*depth))
				for face in range(8):
					for index in [face,(face+1)%8,face+8,(face+1)%8,(face+1)%8+8,face+8]: tower_mesh.add_vertex(corners[index])
			# 보강 리브와 접합판은 기둥 외면에 붙입니다.
			for h in range(8,94,8):
				var width := lerpf(5.4,3.0,clampf((h+15.0)/111,0,1))
				for front in [-1.0,1.0]:
					var center: Vector3 = foot+Vector3.UP*h+basis.z*front*(width*.62+.025)
					fittings.append(Transform3D(basis.scaled_local(Vector3(width*.95,.12,.13)),center))
					for x in [-.32,.32]:
						fittings.append(Transform3D(basis.scaled_local(Vector3(.12,.3,.14)),center+basis.x*width*x))
		for h in [bridge_clearance,90.0]:
			var start: Vector3 = track.point(d,-w)+Vector3.UP*h
			var end: Vector3 = track.point(d,w)+Vector3.UP*h
			ribs.append(beam(start,end,2.2))
			bracing.append(beam(start-Vector3.UP*7,end,0.48))
			bracing.append(beam(start,end-Vector3.UP*7,0.48))
	tower_mesh.generate_normals()
	var towers := MeshInstance3D.new()
	towers.name = "ScarletBridgeTowers"
	towers.mesh = tower_mesh.commit()
	towers.material_override = steel(Color("973c2e"))
	add_child(towers)
	var count := int(ceil((bridge_span.y-bridge_span.x)/4))
	for i in range(count):
		var a := lerpf(bridge_span.x,bridge_span.y,float(i)/count)
		var b := lerpf(bridge_span.x,bridge_span.y,float(i+1)/count)
		var midpoint := (a+b)*.5
		var forward: Vector3 = (track.point(b)-track.point(a)).normalized()
		var intervals: Array[Vector2] = [Vector2(-track.half_width(midpoint)-1.75,track.half_width(midpoint)+1.75)]
		if track.collapse != null and b > track.collapse.span.x and a < track.collapse.span.y:
			intervals = [Vector2(intervals[0].x,track.surface_lane(track.collapse.lanes.x,midpoint)),Vector2(track.surface_lane(track.collapse.lanes.y,midpoint),intervals[0].y)]
		for band in intervals:
			deck_slabs.append(Transform3D(Basis.looking_at(forward,Vector3.UP).scaled_local(Vector3(band.y-band.x,1.5,track.point(a).distance_to(track.point(b))+.05)),track.point(midpoint,(band.x+band.y)*0.5)-Vector3.UP*1.0))
		for side in [-1.0,1.0]:
			var lane: float = side*(track.half_width(a)+6.8)
			cables.append(beam(track.point(a,lane)+Vector3.UP*cable_height(a),track.point(b,side*(track.half_width(b)+6.8))+Vector3.UP*cable_height(b),0.48))
			var lower_a: Vector3 = track.point(a,side*(track.half_width(a)+1.4))-Vector3.UP*1.6
			var lower_b: Vector3 = track.point(b,side*(track.half_width(b)+1.4))-Vector3.UP*1.6
			ribs.append(beam(lower_a,lower_b,1.0))
			if i%3 == 0:
				hangers.append(beam(track.point(a,lane)-Vector3.UP*.7,track.point(a,lane)+Vector3.UP*cable_height(a),.18))
				fittings.append(Transform3D(Basis.IDENTITY.scaled_local(Vector3(.65,.3,.65)),track.point(a,lane)+Vector3.UP*cable_height(a)))
			if i%4 == 0:
				bracing.append(beam(lower_a-Vector3.UP*1.6,lower_b,.22))
		if i%4 == 0: ribs.append(beam(track.point(a,-track.half_width(a)-1.4)-Vector3.UP*1.6,track.point(a,track.half_width(a)+1.4)-Vector3.UP*1.6,.45))
	tubes("MainSuspensionCables",cables,Color("754a3c"))
	tubes("VerticalHangers",hangers,Color("7e7970"))
	boxes("BridgeDeckGirders",ribs,Color("853d30"))
	boxes("BridgeDiagonalBraces",bracing,Color("66342b"))
	boxes("BridgeJointPlates",fittings,Color("aa5b43"),false)
	boxes("BridgeConcreteFoundations",foundations,Color("9a9588"))
	boxes("BridgeStructuralDeck",deck_slabs,Color("747b77"))

func cliff_point(d: float, side: float, tier: float) -> Vector3:
	var riviera: bool = track.closed_loop and track.course_id == 3
	var seaside: bool = riviera and side < 0
	var offsets: Array = preload("res://scripts/riviera_profile.gd").SEA_CLIFF_OFFSETS if seaside else [32.0,40.0,56.0,68.0,102.0,180.0]
	var heights: Array = preload("res://scripts/riviera_profile.gd").SEA_CLIFF_HEIGHTS if seaside else [-2.0,36.0,44.0,78.0,96.0,110.0]
	var fade := 240.0 if riviera else 110.0
	var envelope := smoothstep(0,fade,d-current_span.x)*(1-smoothstep(current_span.y-fade,current_span.y,d))
	var ripple := sin(d*0.033+side*1.7)*3+sin(d*0.011)*5
	var k := mini(int(tier),offsets.size()-2)
	var blend := tier-k
	var offset: float = lerpf(offsets[k],offsets[k+1],blend)
	var elevation: float = lerpf(heights[k],heights[k+1],blend)
	var erosion := (sin(d*.19+tier*3.7)+sin(d*.071-tier*2.3)*1.8)*sin(PI*blend)*1.7
	var lane: float = side*(track.half_width(d)+offset+(0 if tier == 0 else ripple)+erosion)
	var bend: float = track.curvature(d)
	if side*bend < 0:
		lane = side*minf(absf(lane),maxf(track.half_width(d)+40,0.64/maxf(absf(bend),0.0001)))
	var p: Vector3 = track.point(d,lane)
	if riviera: p.y = track.scenery.terrain_point(d,lane).y-.4
	p.y += elevation*envelope+(0 if tier == 0 else ripple*envelope)
	return p

var current_span := Vector2.ZERO
func make_canyon(span: Vector2) -> void:
	var riviera: bool = track.closed_loop and track.course_id == 3
	if riviera: span += Vector2(-200,200)
	current_span = span
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(ceil((span.y-span.x)/7))
	for side in [-1.0,1.0]:
		for i in range(count):
			var a := lerpf(span.x,span.y,float(i)/count)
			var b := lerpf(span.x,span.y,float(i+1)/count)
			for row in range(28 if riviera and side < 0 else 20):
				var tier := row/4.0
				var points := [cliff_point(a,side,tier),cliff_point(a,side,tier+.25),cliff_point(b,side,tier),cliff_point(b,side,tier+.25)]
				for index in ([0,1,2,1,3,2] if side > 0 else [0,2,1,1,2,3]): st.add_vertex(points[index])
	st.index()
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "LayeredCanyonWalls"
	node.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sandstone.gdshader")
	mat.set_shader_parameter("rock_detail",preload("res://assets/environment/generated-rock-variants.png"))
	node.material_override = mat
	add_child(node)

func make_billboards(span: Vector2) -> void:
	var posts: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var backs: Array[Transform3D] = []
	var footings: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var lamps_metal: Array[Transform3D] = []
	for i in range(int((span.y-span.x-160)/ad_spacing)):
		var geometry: Array = [posts,frames,backs,footings,lamps,lamps_metal]
		var starts: Array[int] = []
		for poses in geometry: starts.append(poses.size())
		var d := span.x+100+i*ad_spacing
		var side := -1.0 if i%2 == 0 else 1.0
		var lane: float = side*(track.half_width(d)+18)
		var p: Vector3 = track.point(d,lane)
		texture_regions.append(p)
		var board := MeshInstance3D.new()
		board.name = "FictionalAdvertisement"
		var mesh := QuadMesh.new()
		mesh.size = ad_size
		board.mesh = mesh
		board.rotation.y = preload("res://scripts/billboard_facing.gd").yaw(track,d,lane)
		var basis := board.basis
		var center := p+Vector3.UP*10
		board.position = p+(center+basis.z*.25-p)*AD_METRE_SCALE
		var ad_index := Ads.choose()
		board.material_override = advertisement_material(ad_index)
		board.add_to_group("racing_advertisement")
		add_child(board)
		backs.append(Transform3D(basis.scaled_local(Vector3(16.4,7.4,.42)),center))
		for y in [-3.6,3.6]: frames.append(Transform3D(basis.scaled_local(Vector3(16.5,.18,.18)),center+Vector3.UP*y+basis.z*.26))
		for x in [-8.1,8.1]: frames.append(Transform3D(basis.scaled_local(Vector3(.18,7.4,.18)),center+basis.x*x+basis.z*.26))
		for x in [-5.5,0.0,5.5]:
			lamps_metal.append(Transform3D(basis.scaled_local(Vector3(.09,.09,1.25)),center+basis.x*x+Vector3.UP*3.85+basis.z*.65))
			lamps_metal.append(Transform3D(basis.scaled_local(Vector3(.65,.20,.48)),center+basis.x*x+Vector3.UP*3.75+basis.z*1.1))
			lamps.append(Transform3D(basis.scaled_local(Vector3(.49,.03,.32)),center+basis.x*x+Vector3.UP*3.64+basis.z*1.1))
		for offset in [-5.0,5.0]:
			var foot: Vector3 = p+basis.x*offset-basis.z*.65
			posts.append(beam(foot-Vector3.UP*1.5,foot+Vector3.UP*13.4,.38))
			footings.append(Transform3D(basis.scaled_local(Vector3(1.5,.7,1.5)),foot-Vector3.UP*.1))
		for h in [7.0,10.0,13.0]:
			frames.append(Transform3D(basis.scaled_local(Vector3(15.8,.16,.25)),p+Vector3.UP*h-basis.z*.55))
		for sign_x in [-1.0,1.0]:
			frames.append(beam(p+basis.x*sign_x*5+Vector3.UP*6.5-basis.z*.7,p+Vector3.UP*12.8-basis.z*.7,.13))
		# 하부 점검 발판은 광고 면을 가리지 않습니다.
		frames.append(Transform3D(basis.scaled_local(Vector3(16.6,.12,1.15)),p+Vector3.UP*6.15+basis.z*.65))
		# 패널·기초·지지대·조명을 같은 지면 피벗에서 확대해 접합부를 유지한다.
		for part in range(geometry.size()):
			for n in range(starts[part],geometry[part].size()):
				var pose: Transform3D = geometry[part][n]
				geometry[part][n] = Transform3D(pose.basis.scaled(Vector3.ONE*AD_METRE_SCALE),p+(pose.origin-p)*AD_METRE_SCALE)
		var record := {"distance":d,"lane":lane,"width":ad_size.x,"height":ad_size.y,"position":board.position,"basis":basis,"ad_index":ad_index}
		billboard_manifest.append(record)
		board.set_meta("ad_record",record)
	boxes("BillboardSteelSupports",posts,Color("555b5c"),false)
	boxes("BillboardRimAndTruss",frames,Color("42494a"),false)
	boxes("BillboardPanelBacks",backs,Color("747a76"))
	boxes("BillboardConcreteFeet",footings,Color("ada99b"))
	boxes("BillboardLampHousings",lamps_metal,Color("30393e"),false)
	boxes("BillboardLampLenses",lamps,Color("eee4bf"),false)
