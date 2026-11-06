extends Node3D

const PANORAMA = preload("res://assets/environment/fuji-lake-panorama.png")
const GRASS = preload("res://assets/environment/lakeside-grass.png")
const SKY_SHADER = preload("res://shaders/fuji_sky.gdshader")
const TERRAIN_SHADER = preload("res://shaders/lakeside_terrain.gdshader")
const WATER_SHADER = preload("res://shaders/lake_water.gdshader")
const WATER_HEIGHT := 0.0
const SHORE_LANE := -18.0
var theme := "fuji"
var track: Node3D
var landmarks: Node3D
var water: MeshInstance3D
var tree_positions: Array[Vector3] = []
var tree_batches: Array[MultiMeshInstance3D] = []
var rng := RandomNumberGenerator.new()

func make_sky() -> Sky:
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter("panorama", PANORAMA)
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky

func terrain_point(distance: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(distance, lane)
	var road_y: float = track.ground_height(distance)
	if lane < -10:
		p.y = lerpf(WATER_HEIGHT + 0.12, road_y - 0.25, clampf((lane - SHORE_LANE) / (-10.0 - SHORE_LANE), 0, 1))
	else:
		p.y = road_y - 0.25 + maxf(0, lane - 12) * 0.03
	return p

func _ready() -> void:
	rng.seed = 8417
	var terrain := ShaderMaterial.new()
	terrain.shader = TERRAIN_SHADER
	terrain.set_shader_parameter("ground_grain", GRASS)
	terrain_band(SHORE_LANE, -10, terrain)
	terrain_band(10, 110, terrain)
	make_water()
	make_trees()
	landmarks = preload("res://scripts/circuit_landmarks.gd").new()
	landmarks.scenery = self
	add_child(landmarks)
	make_underpass()

func terrain_band(inner: float, outer: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(450):
		var a: float = track.length * i / 450.0
		var b: float = track.length * (i + 1) / 450.0
		var points := [terrain_point(a, inner), terrain_point(a, outer), terrain_point(b, inner), terrain_point(b, outer)]
		for index in [0, 2, 1, 1, 2, 3]:
			st.add_vertex(points[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	add_child(node)

func make_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(450):
		var a: Vector3 = track.point(track.length * i / 450.0, SHORE_LANE)
		var b: Vector3 = track.point(track.length * (i + 1) / 450.0, SHORE_LANE)
		a.y = WATER_HEIGHT
		b.y = WATER_HEIGHT
		for point: Vector3 in [Vector3(0, WATER_HEIGHT, 0), b, a]:
			st.set_normal(Vector3.UP)
			st.add_vertex(point)
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("lake_image", PANORAMA)
	water = MeshInstance3D.new()
	water.name = "KawaguchiLake"
	water.mesh = st.commit()
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func make_trees() -> void:
	var Props = preload("res://scripts/regional_props_3d.gd")
	var placements: Array[Dictionary] = []
	for i in range(120):
		var d: float = i*track.length/120+rng.randf_range(-3,3)
		if track.in_tunnel(d) or track.excavation_depth(d) > 0.2: continue
		var kind := "sakura" if i%4 == 0 else ("japanese_pine" if i%3 == 0 else "pine")
		var scale := rng.randf_range(0.75,1.3)
		var radius: float = Props.radius(kind)*scale
		var side := -1.0 if i%9 == 0 else 1.0
		var lane: float = side*(track.half_width(d)+track.rail_setback(d,side)+radius+3.0+rng.randf_range(0,18))
		var p: Vector3 = track.roadside_point(d,lane)
		var closest: float = track.curve.get_closest_offset(p)
		var center: Vector3 = track.point(closest)
		if Vector2(p.x-center.x,p.z-center.z).length()-radius < track.half_width(closest)+track.rail_setback(closest,side)+1.5: continue
		placements.append({"position":p,"yaw":rng.randf_range(0,TAU),"scale":scale,"kind":kind})
		tree_positions.append(p)
	var forest := Props.new()
	forest.name = "FujiForest3D"
	forest.configure("fuji",placements)
	add_child(forest)
	tree_batches.assign(forest.batches)

# The deck sits at ground level; open retaining walls lead down to both portals.
var tunnel_light_rig: Node3D
func make_underpass() -> void:
	var walls: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var seams: Array[Transform3D] = []
	var start: float = track.length*0.56
	for i in range(int(ceil(620.0/6))):
		var d := start-190+i*6+3
		var depth: float = track.excavation_depth(d)
		if d >= start and d <= start+240: continue
		if depth < 0.15: continue
		for side in [-1.0,1.0]:
			walls.append(Transform3D(Basis(Vector3.UP,track.heading(d)).scaled_local(Vector3(0.9,depth+0.8,6.2)),track.point(d,side*(track.half_width(d)+1.7))+Vector3.UP*(depth*0.5+0.25)))
	for i in range(30):
		var d := start+i*8+4
		var f: Vector3 = (track.point(d+1)-track.point(d-1)).normalized()
		var right := Vector3(-f.z,0,f.x).normalized()
		var basis := Basis(Vector3.UP,track.heading(d)).rotated(right,asin(f.y))
		var width: float = track.half_width(d)
		for side in [-1.0,1.0]:
			walls.append(Transform3D(basis.scaled_local(Vector3(0.9,6.2,8.3)),track.point(d,side*(width+1.7))+Vector3.UP*3.1))
		roofs.append(Transform3D(basis.scaled_local(Vector3(width*2+4.2,0.7,8.3)),track.point(d)+Vector3.UP*6.25))
		if i%4 == 0:
			seams.append(Transform3D(basis.scaled_local(Vector3(width*2+1.8,0.22,0.35)),track.point(d)+Vector3.UP*5.80))
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("596574")
	wall_material.roughness = 0.9
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("303e50")
	roof_material.roughness = 0.9
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("a8b2b8")
	for group in [[walls,wall_material],[roofs,roof_material],[seams,trim]]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = group[0].size()
		for i in range(group[0].size()): multi.set_instance_transform(i,group[0][i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = group[1]
		add_child(node)
	tunnel_light_rig = preload("res://scripts/tunnel_lights.gd").new()
	tunnel_light_rig.track = track
	tunnel_light_rig.span = Vector2(start,start+240)
	tunnel_light_rig.ceiling = 5.55
	add_child(tunnel_light_rig)
	# A landscaped cap hides the roof shell in the surrounding original terrain.
	var caps: Array[Transform3D] = []
	for i in range(30):
		var d := start+i*8+4
		caps.append(Transform3D(Basis(Vector3.UP,track.heading(d)).scaled_local(Vector3(track.half_width(d)*2+9,0.65,8.3)),track.point(d)+Vector3.UP*6.85))
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("61775e")
	grass.roughness = 1
	track.box_batch(Vector3.ONE,grass,caps)

func set_shadow_quality(_enabled: bool) -> void:
	for node in tree_batches: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
