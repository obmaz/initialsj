extends Node3D
# Real 3D trackside geometry, batched for the mobile/Web renderer.
var track: Node3D
var theme := "speedway"
var batches: Array[MultiMeshInstance3D] = []
var grandstand_anchors: Array[Transform3D] = []
const BASE_HEIGHT := 6.5
const OUTER_SLOPE_END := 240.0
const INNER_SLOPE_END := 180.0
func make_sky() -> Sky:
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("317dcc")
	material.sky_horizon_color = Color("c5e9f4")
	material.ground_horizon_color = Color("b5d2cb")
	material.ground_bottom_color = Color("50786b")
	material.sky_curve = 0.16
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky
func outer_ground_height(d: float, lane: float) -> float:
	var platform: float = maxf(7.4,track.point(d,track.half_width(d)+2).y)
	return lerpf(platform,BASE_HEIGHT,smoothstep(120,OUTER_SLOPE_END,lane))
func inner_ground_height(d: float, lane: float) -> float:
	var platform: float = maxf(BASE_HEIGHT,track.point(d,-track.half_width(d)-2).y-0.15)
	return lerpf(platform,BASE_HEIGHT,smoothstep(90,INNER_SLOPE_END,absf(lane)))
func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d,lane)
	p.y = inner_ground_height(d,lane) if lane < 0 else outer_ground_height(d,lane)
	return p
func distance_at_xz(p: Vector3) -> float:
	# Prop footprints project onto the road in plan view. A fixed low Y would
	# pull the closest point downhill after the circuit gains real elevation.
	var d: float = track.curve.get_closest_offset(p)
	for iteration in range(4):
		var q: Vector3 = track.point(d)
		var tangent: Vector3 = (track.point(d+1)-track.point(d-1))*0.5
		var derivative := Vector2(tangent.x,tangent.z)
		var offset := Vector2(p.x-q.x,p.z-q.z)
		d = fposmod(d+clampf(offset.dot(derivative)/maxf(0.01,derivative.length_squared()),-80,80),track.length)
	return d
func batch(label: String, size: Vector3, color: Color, poses: Array[Transform3D]) -> void:
	if poses.is_empty(): return
	var mesh := BoxMesh.new()
	mesh.size = size
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = poses.size()
	for i in range(poses.size()): instances.set_instance_transform(i,poses[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = track.material(color)
	add_child(node)
	batches.append(node)
func pose(d: float, lane: float, height: float, scale: Vector3 = Vector3.ONE) -> Transform3D:
	var p: Vector3 = track.point(d,lane)
	p.y = (outer_ground_height(d,lane) if lane > 0 else inner_ground_height(d,lane))+height
	return Transform3D(Basis(Vector3.UP,track.heading(d)).scaled_local(scale),p)
func _ready() -> void:
	make_infield()
	make_walls_and_fences()
	make_stands()
	make_pits()
	make_lights()
	make_palms()
func make_infield() -> void:
	var grass: StandardMaterial3D = track.material(Color("548e5d"))
	grass.roughness = 1
	grass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(2800,2100)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "SpeedwayInfield"
	floor_node.mesh = floor_mesh
	floor_node.material_override = grass
	floor_node.position.y = 6.5
	add_child(floor_node)
	make_outer_ground(grass)
	make_inner_ground(grass)
	var lake := MeshInstance3D.new()
	lake.name = "InfieldLake"
	var disk := CylinderMesh.new()
	disk.top_radius = 1
	disk.bottom_radius = 1
	disk.height = 0.1
	disk.radial_segments = 48
	lake.mesh = disk
	lake.material_override = track.material(Color("328dad"),0.25)
	lake.position = Vector3(140,6.65,-60)
	lake.scale = Vector3(250,1,130)
	add_child(lake)
# The outer safety wall, grandstands and light masts share a raised foundation.
# One continuous mesh closes the bank underside and descends to the base plane.
func make_outer_ground(grass: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := int(ceil(track.length/8))
	var lanes: Array[float] = [16.0,16.5,120.0]
	for lane in range(125,int(OUTER_SLOPE_END)+1,5): lanes.append(float(lane))
	for i in range(steps):
		var a: float = track.length*i/steps
		var b: float = track.length*(i+1)/steps
		for band in range(lanes.size()-1):
			var points := [track.point(a,lanes[band]),track.point(a,lanes[band+1]),track.point(b,lanes[band]),track.point(b,lanes[band+1])]
			for corner in range(4):
				var d: float = a if corner < 2 else b
				var lane: float = lanes[band+(corner%2)]
				points[corner].y = track.point(d,lane).y-0.16 if band == 0 and corner%2 == 0 else outer_ground_height(d,lane)
			for index in [0,2,1,1,2,3]: surface.add_vertex(points[index])
	surface.index()
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "SpeedwayOuterGround"
	terrain.mesh = surface.commit()
	terrain.material_override = grass
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
# An elevated inside shoulder needs a continuous bank down to the flat lake
# and lawn; props and the pit lane share the same authored ground profile.
func make_inner_ground(grass: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := int(ceil(track.length/8))
	var lanes: Array[float] = [-16.0,-16.5,-90.0]
	for lane in range(95,int(INNER_SLOPE_END)+1,5): lanes.append(-float(lane))
	for i in range(steps):
		var a: float = track.length*i/steps
		var b: float = track.length*(i+1)/steps
		for band in range(lanes.size()-1):
			var points := [terrain_point(a,lanes[band]),terrain_point(a,lanes[band+1]),terrain_point(b,lanes[band]),terrain_point(b,lanes[band+1])]
			for corner in [0,2]:
				if band == 0: points[corner].y = track.point(a if corner == 0 else b,lanes[band]).y-0.16
			for index in [0,1,2,1,3,2]: surface.add_vertex(points[index])
	surface.index()
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "SpeedwayInnerGround"
	terrain.mesh = surface.commit()
	terrain.material_override = grass
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
func make_walls_and_fences() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posts: Array[Transform3D] = []
	var fence := SurfaceTool.new()
	fence.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(ceil(track.length/5))
	for side in [-1.0,1.0]:
		for i in range(count):
			var a: float = track.length*i/count
			var b: float = track.length*(i+1)/count
			var lane: float = side*(track.half_width(a)+track.rail_setback(a,side)+0.25)
			var next_lane: float = side*(track.half_width(b)+track.rail_setback(b,side)+0.25)
			var p: Vector3 = track.point(a,lane)
			var q: Vector3 = track.point(b,next_lane)
			for v in [p,q,p+Vector3.UP*1.2,p+Vector3.UP*1.2,q,q+Vector3.UP*1.2]: st.add_vertex(v)
			if side < 0: continue
			for n in [0,1,2,2,1,3]:
				fence.set_uv(Vector2((a if n%2 == 0 else b)/2,0 if n < 2 else 1))
				fence.add_vertex((p if n%2 == 0 else q)+Vector3.UP*(1.2 if n < 2 else 5.2))
			if i%4 == 0: posts.append(pose(a,lane,3.0))
	st.generate_normals()
	var wall := MeshInstance3D.new()
	wall.name = "SpeedwaySafetyWalls"
	wall.mesh = st.commit()
	wall.material_override = track.material(Color("eff1e9"))
	add_child(wall)
	fence.generate_normals()
	var net := MeshInstance3D.new()
	net.name = "CatchFence"
	net.mesh = fence.commit()
	var wire := ShaderMaterial.new()
	wire.shader = preload("res://shaders/catch_fence.gdshader")
	net.material_override = wire
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)
	batch("FencePosts",Vector3(0.1,4.8,0.1),Color("536d7b"),posts)
func make_stands() -> void:
	var supports: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var foundations: Array[Transform3D] = []
	var canopy_supports: Array[Transform3D] = []
	var seats := [[],[],[]]
	for fraction in [0.015,0.055,0.095,0.135,0.45,0.49,0.53,0.57,0.71,0.75]:
		var d: float = track.length*fraction
		var frame := Transform3D(Basis(Vector3.UP,track.heading(d)),track.point(d))
		# A grandstand is one rigid building. Give every seat, tier and roof the
		# same foundation instead of following different road banks per block.
		var base := 7.4
		for x in [34.3,47.55,60.8,78.0]:
			for z in range(-64,65,8):
				var p := frame*Vector3(x,0,z)
				var at := distance_at_xz(p)
				base = maxf(base,outer_ground_height(at,x))
		frame.origin.y = base+0.08
		grandstand_anchors.append(frame)
		var foundation_height := frame.origin.y-6.5
		foundations.append(frame*Transform3D(Basis.IDENTITY.scaled(Vector3(26.5,foundation_height,116)),Vector3(47.55,-foundation_height*0.5,0)))
		for row in range(8):
			var lane := 36.0+row*3.3
			var height := 0.8+row*1.25
			for block in range(5):
				seats[(row+block)%3].append(frame*Transform3D(Basis.IDENTITY.scaled(Vector3(3.2,0.8,22)),Vector3(lane,height,(block-2)*23)))
			var tier_height := 0.5+row*1.25
			supports.append(frame*Transform3D(Basis.IDENTITY.scaled(Vector3(3.4,tier_height,116)),Vector3(lane,tier_height*0.5,0)))
		roofs.append(frame*Transform3D(Basis.IDENTITY.scaled(Vector3(32,0.5,122)),Vector3(62,14,0)))
		for x in [48.0,76.0]:
			for z in [-50.0,50.0]:
				var p := frame*Vector3(x,0,z)
				var at := distance_at_xz(p)
				var bottom := outer_ground_height(at,x)
				var column_height := frame.origin.y+14-bottom
				p.y = bottom+column_height*0.5
				canopy_supports.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.35,column_height,0.35)),p))
	for i in range(3):
		var typed: Array[Transform3D] = []
		typed.assign(seats[i])
		batch("GrandstandSeats"+str(i),Vector3.ONE,Color(["217991","e9ad51","b5c9d0"][i]),typed)
	batch("GrandstandFoundations",Vector3.ONE,Color("67797d"),foundations)
	batch("GrandstandTerraces",Vector3.ONE,Color("73818a"),supports)
	batch("GrandstandCanopies",Vector3.ONE,Color("dce2db"),roofs)
	batch("GrandstandCanopySupports",Vector3.ONE,Color("8e9a9a"),canopy_supports)
func make_pits() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(100):
		var a := 15.0+i*6
		var b := a+6
		var pts := [track.point(a,-18),track.point(a,-32),track.point(b,-18),track.point(b,-32)]
		for n in [0,2,1,1,2,3]:
			var p: Vector3 = pts[n]
			p.y = inner_ground_height(a if n < 2 else b,-18 if n%2 == 0 else -32)+0.03
			st.add_vertex(p)
	st.generate_normals()
	var apron := MeshInstance3D.new()
	apron.name = "PitLane"
	apron.mesh = st.commit()
	apron.material_override = track.material(Color("47555b"))
	add_child(apron)
	var garages: Array[Transform3D] = []
	var doors: Array[Transform3D] = []
	for i in range(20):
		var d := 30.0+i*28
		var p: Vector3 = track.point(d,-45)
		p.y = inner_ground_height(d,-45)+3.5
		garages.append(Transform3D(Basis(Vector3.UP,track.heading(d)),p))
		p = track.point(d,-34.7)
		p.y = inner_ground_height(d,-34.7)+2.4
		doors.append(Transform3D(Basis(Vector3.UP,track.heading(d)),p))
	batch("PitGarages",Vector3(20,7,26),Color("d4dbd8"),garages)
	batch("PitDoors",Vector3(0.2,4,20),Color("235565"),doors)
	var tower := Node3D.new()
	tower.name = "RaceControlTower"
	add_child(tower)
	tower.position = track.point(170,-70)
	tower.position.y = inner_ground_height(170,-70)+0.05
	tower.rotation.y = track.heading(170)
	track.box(tower,Vector3(0,10,0),Vector3(15,20,20),track.material(Color("cbd6d4")))
	track.box(tower,Vector3(0,21,0),Vector3(21,5,27),track.material(Color("28566c"),0.4))
	track.box(tower,Vector3(0,24,0),Vector3(24,1,30),track.material(Color("e4ad4b")))
	var label := Label3D.new()
	label.text = "SUNCOAST"
	label.font_size = 90
	label.pixel_size = 0.035
	label.position = Vector3(11,21,0)
	label.rotation.y = PI/2
	tower.add_child(label)
func make_lights() -> void:
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for i in range(48):
		var d: float = track.length*i/48
		poles.append(pose(d,84,12))
		heads.append(pose(d,82,24))
	batch("StadiumLightPoles",Vector3(0.32,24,0.32),Color("738594"),poles)
	batch("StadiumLightBanks",Vector3(3.5,1.6,6),Color("f5f0d5"),heads)
func make_palms() -> void:
	var placements: Array[Dictionary] = []
	for i in range(32):
		var d: float = track.length*(i+0.35)/32
		var lane := -95.0 if d < 650 else -48.0
		var p: Vector3 = track.point(d,lane)
		p.y = inner_ground_height(d,lane)+0.1
		placements.append({"position":p,"yaw":i*1.7,"scale":0.85+(i%4)*0.09,"variant":i})
	var palms := preload("res://scripts/regional_props_3d.gd").new()
	palms.name = "SpeedwayPalms"
	palms.configure("hawaii",placements)
	add_child(palms)
func set_shadow_quality(enabled: bool) -> void:
	for node in batches: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
