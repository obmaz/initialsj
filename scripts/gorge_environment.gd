extends Node3D
var track: Node3D
var theme := "gorge"
var tree_positions: Array[Vector3] = []
var landmarks: Node3D

func make_sky() -> Sky:
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/riviera_sky.gdshader")
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky

func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d,lane)
	var road_y: float = track.point(d,clampf(lane,-17,17)).y-0.3
	var bay := smoothstep(150,230,d)*(1-smoothstep(1040,1150,d))
	p.y = lerpf(road_y,1.0,bay)
	return p

func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(720):
		var a: float = track.length*i/720
		var b: float = track.length*(i+1)/720
		for side in [-1.0,1.0]:
			for band in range(6):
				var inner: float = side*(9+band*23)
				var outer: float = side*(9+(band+1)*23)
				var points := [terrain_point(a,inner),terrain_point(a,outer),terrain_point(b,inner),terrain_point(b,outer)]
				for index in ([0,2,1,1,2,3] if side > 0 else [0,1,2,1,3,2]): st.add_vertex(points[index])
	st.generate_normals()
	var ground := MeshInstance3D.new()
	ground.name = "GorgeGround"
	ground.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sandstone.gdshader")
	mat.set_shader_parameter("rock_detail",preload("res://assets/environment/generated-rock-variants.png"))
	ground.material_override = mat
	ground.set_meta("world_ground",true)
	add_child(ground)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3500,1500)
	water.mesh = plane
	water.position = Vector3(0,2,-550)
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://shaders/coastal_water.gdshader")
	sea.set_shader_parameter("deep_color",Color("143d55"))
	sea.set_shader_parameter("shallow_color",Color("2b8190"))
	water.material_override = sea
	add_child(water)
	landmarks = preload("res://scripts/scenic_landmarks.gd").new()
	landmarks.track = track
	landmarks.bridge_span = track.bridge_span
	landmarks.canyon_spans.assign([Vector2(1800,track.length-360)])
	add_child(landmarks)
