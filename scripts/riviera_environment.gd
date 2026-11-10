extends Node3D
# 바다·절벽·마을이 실제 도로 높이에 이어지는 해안 지형입니다.
# 먼 산은 낮은 다각형 수의 입체 섬이며 가로수·상점은 기존 원본 메시를 배치합니다.
const Profile = preload("res://scripts/riviera_profile.gd")
var track: Node3D
var theme := "riviera"
var tree_batches: Array[MultiMeshInstance3D] = []
var tree_positions: Array[Vector3] = []
var water: MeshInstance3D
var rock_arches: Node3D
var landmarks: Node3D

func make_sky() -> Sky:
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/riviera_sky.gdshader")
	mat.set_shader_parameter("panorama",load("res://assets/environment/riviera-sky-panorama.png"))
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky

func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d,lane)
	# 차선 안의 지형도 뱅킹을 따라 낮춰야 안쪽 차선을 흙과 충돌면이 덮지 않습니다.
	var road_y: float = track.point(d,clampf(lane,-17,17)).y
	if lane < 0:
		var reach := absf(lane)
		var coast := lerpf(road_y-0.28,-2.8,smoothstep(17,110,reach))
		coast = lerpf(coast,-5.0,smoothstep(170,230,reach))
		# 협곡으로 들어갈 때만 반도가 천천히 솟고, 먼 해안은 수면 아래로 돌아간다.
		var peninsula := lerpf(road_y-.28,-4.0,smoothstep(180,410,reach))
		p.y = lerpf(coast,peninsula,Profile.canyon_amount(d)*smoothstep(22,68,reach))
	else:
		p.y = road_y-0.28+26*smoothstep(20,115,lane)*(0.7+0.3*sin(d*0.004))
	return p

func band(inner: float, outer: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(720):
		var a: float = track.length*i/720
		var b: float = track.length*(i+1)/720
		var vertices := [terrain_point(a,inner),terrain_point(a,outer),terrain_point(b,inner),terrain_point(b,outer)]
		for index in [0,2,1,1,2,3]: st.add_vertex(vertices[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var terrain := ShaderMaterial.new()
	terrain.shader = preload("res://shaders/riviera_ground.gdshader")
	terrain.set_shader_parameter("ground_grain",load("res://assets/environment/lakeside-grass.png"))
	terrain.set_shader_parameter("terrain_variants",load("res://assets/environment/terrain-variants.png"))
	terrain.set_shader_parameter("base_color",color)
	terrain.set_shader_parameter("grassy",inner >= 18)
	node.material_override = terrain
	node.set_meta("world_ground",true)
	add_child(node)

func _ready() -> void:
	band(-420,-180,Color("d2c5a1"))
	band(-180,-75,Color("e5d5a7"))
	band(-75,-18,Color("bda47b"))
	band(-18,18,Color("d8c699"))
	band(18,65,Color("47784d"))
	band(65,240,Color("698358"))
	water = MeshInstance3D.new()
	water.name = "AzureSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(14000,14000)
	water.mesh = plane
	water.position.y = -3
	var sea: StandardMaterial3D = track.material(Color("087f9f"),0.12)
	sea.roughness = 0.27
	water.material_override = sea
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	make_islands()
	make_boulevard()
	landmarks = preload("res://scripts/scenic_landmarks.gd").new()
	landmarks.track = track
	landmarks.canyon_spans.assign(preload("res://scripts/settlement_layout.gd").canyon_spans(track))
	add_child(landmarks)
	rock_arches = preload("res://scripts/rock_arches.gd").new()
	rock_arches.track = track
	add_child(rock_arches)

func make_islands() -> void:
	for i in range(11):
		var island := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 12
		mesh.bottom_radius = 260+i%3*55
		mesh.height = 170+i%4*45
		mesh.radial_segments = 12
		island.mesh = mesh
		var angle := i*TAU/11
		island.position = Vector3(cos(angle)*2400,mesh.height*0.3-50,sin(angle)*2250)
		island.scale = Vector3(1.8,1,1)
		island.material_override = track.material(Color("4d6a86") if i%2 == 0 else Color("4d7b7b"))
		island.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(island)

func make_boulevard() -> void:
	var Props = preload("res://scripts/regional_props_3d.gd")
	var placements: Array[Dictionary] = []
	for i in range(180):
		var d: float = track.length*i/180
		for side in [-1.0,1.0]:
			var scale: float = Props.placement_scale("palm",1.1+(i%4)*.13)
			var radius: float = Props.radius("palm")*scale
			var lane: float = side*(track.half_width(d)+track.rail_setback(d,side)+radius+2.5+(i%3)*2.4)
			var p := terrain_point(d,lane)
			var nearest: float = track.curve.get_closest_offset(p)
			if Vector2(p.x-track.point(nearest).x,p.z-track.point(nearest).z).length()-radius < track.half_width(nearest)+track.rail_setback(nearest,side)+1.5: continue
			placements.append({"kind":"palm","position":p,"yaw":i*1.7,"scale":scale})
			tree_positions.append(p)
	# 육지의 안전한 마을 구획에만 집을 모으고 협곡 접근부와 마을 사이는 비운다.
	for i in range(160):
		var d: float = 130+(track.length-260)*(i+.5)/160
		var kind: String = Props.RURAL_KINDS[i%10]
		if i%11 == 0: kind = ["coffee_shop","souvenir_shop","gas_station","street_shop"][(i/11)%4]
		var scale: float = .98+(i%4)*.02
		var radius: float = Props.radius(kind)*scale
		if not preload("res://scripts/settlement_layout.gd").allows(track,d,radius): continue
		var lane: float = track.half_width(d)+track.rail_setback(d,1.0)+radius+3.5+(i%3)*2
		var p := terrain_point(d,lane)
		var nearest: float = track.curve.get_closest_offset(p)
		if Vector2(p.x-track.point(nearest).x,p.z-track.point(nearest).z).length()-radius < track.half_width(nearest)+track.rail_setback(nearest,1.0)+1.5: continue
		placements.append({"kind":kind,"position":p,"yaw":track.heading(d)-PI*0.5,"scale":scale,"distance":d})
	var props := Props.new()
	props.name = "RivieraBoulevard"
	props.configure("hawaii",placements)
	add_child(props)
	tree_batches.assign(props.batches)
