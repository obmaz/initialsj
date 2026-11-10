extends Node3D

const PANORAMA = preload("res://assets/environment/fuji-lake-panorama.png")
const BACK_A = preload("res://assets/environment/fuji-lake-back-a.png")
const BACK_B = preload("res://assets/environment/fuji-lake-back-b.png")
const GRASS = preload("res://assets/environment/lakeside-grass.png")
const Natural = preload("res://scripts/quaternius_props.gd")
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
	mat.set_shader_parameter("back_a", BACK_A)
	mat.set_shader_parameter("back_b", BACK_B)
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
	terrain.set_shader_parameter("terrain_variants",preload("res://assets/environment/terrain-variants.png"))
	terrain_band(SHORE_LANE, -10, terrain)
	terrain_band(10, 110, terrain)
	make_water()
	make_trees()
	make_village()
	landmarks = preload("res://scripts/circuit_landmarks.gd").new()
	landmarks.scenery = self
	add_child(landmarks)
	make_underpass()
	make_bridge()

func terrain_band(inner: float, outer: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(450):
		var a: float = track.length * i / 450.0
		var b: float = track.length * (i + 1) / 450.0
		if track.on_bridge((a+b)*0.5): continue
		var points := [terrain_point(a, inner), terrain_point(a, outer), terrain_point(b, inner), terrain_point(b, outer)]
		for index in [0, 2, 1, 1, 2, 3]:
			st.add_vertex(points[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	node.set_meta("world_ground",true)
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
		if track.in_tunnel(d) or track.excavation_depth(d) > 0.2 or track.on_bridge(d): continue
		# Cherry and Japanese pines keep the regional character; the rest of the forest is
		# Quaternius's CC0 pines and oaks, and willows stand on the lake side.
		var kind: String = "sakura" if i%4 == 0 else ("japanese_pine" if i%3 == 0 else (Natural.OAKS[i%2] if i%5 == 1 else Natural.PINES[i%3]))
		var scale := rng.randf_range(0.75,1.3)
		var side := -1.0 if i%9 == 0 else 1.0
		if side < 0: kind = Natural.WILLOWS[(i/9)%3]
		var radius: float = Props.radius(kind)*scale
		var lane: float = side*(track.half_width(d)+track.rail_setback(d,side)+radius+3.0+rng.randf_range(0,18))
		# Willows lean over the water: their trunks stand on the shore strip, not beyond it.
		if side < 0: lane = -(track.half_width(d)+track.rail_setback(d,side)+radius*0.6+1.0+rng.randf_range(0,2))
		var p: Vector3 = track.roadside_point(d,lane)
		var closest: float = track.curve.get_closest_offset(p)
		var center: Vector3 = track.point(closest)
		var reach := radius*0.6 if side < 0 else radius
		if Vector2(p.x-center.x,p.z-center.z).length()-reach < track.half_width(closest)+track.rail_setback(closest,side)+1.5: continue
		placements.append({"position":p,"yaw":rng.randf_range(0,TAU),"scale":scale,"kind":kind})
		tree_positions.append(p)
	# Low bushes and mossy rocks along both verges give the road a sense of speed.
	for i in range(260):
		var d: float = i*track.length/260+rng.randf_range(-6,6)
		if track.in_tunnel(d) or track.excavation_depth(d) > 0.2 or track.on_bridge(d): continue
		var side := -1.0 if i%7 == 0 else 1.0
		var kind: String = Natural.BUSHES[i%2] if i%3 == 0 else Natural.ROCKS[i%4]
		var scale := rng.randf_range(0.8,1.4)
		var radius: float = Props.radius(kind)*scale
		var lane: float = side*(track.half_width(d)+track.rail_setback(d,side)+1.6+radius+rng.randf_range(0,9))
		if side < 0 and lane < -15.5: continue
		var p: Vector3 = track.roadside_point(d,lane)
		var closest: float = track.curve.get_closest_offset(p)
		var center: Vector3 = track.point(closest)
		if Vector2(p.x-center.x,p.z-center.z).length()-radius < track.half_width(closest)+track.rail_setback(closest,side)+1.0: continue
		placements.append({"position":p,"yaw":rng.randf_range(0,TAU),"scale":scale,"kind":kind})
	var forest := Props.new()
	forest.name = "FujiForest3D"
	forest.configure("fuji",placements)
	add_child(forest)
	tree_batches.assign(forest.batches)

# The deck sits at ground level; open retaining walls lead down to both portals.
var tunnel_light_rig: Node3D
# Lakeside villages: on a few straight, open stretches the shops stand shoulder to shoulder on the
# land side, with cafes, souvenir stands, noodle houses, an inn and rows of vending machines.
const VILLAGES := [[520.0,800.0],[1750.0,2060.0],[3300.0,3600.0],[4700.0,4980.0]]
func make_village() -> void:
	var Props = preload("res://scripts/regional_props_3d.gd")
	var kinds := ["coffee_shop","souvenir_shop","noodle_house","vending_row","coffee_shop","ryokan","souvenir_shop","noodle_house","vending_row","coffee_shop"]
	var placements: Array[Dictionary] = []
	var index := 0
	for village in VILLAGES:
		var d: float = village[0]
		while d < village[1]:
			var kind: String = kinds[index%kinds.size()]
			index += 1
			var scale: float = Props.placement_scale(kind,rng.randf_range(0.95,1.1))
			var radius: float = Props.radius(kind)*scale
			var step := radius*1.5+rng.randf_range(2,5)
			var ok: bool = not (track.in_tunnel(d) or track.excavation_depth(d) > 0.2 or track.on_bridge(d)) and absf(track.curvature(d)) < 0.006
			if ok:
				var lane: float = track.half_width(d)+track.rail_setback(d,1.0)+radius+3.5
				var p: Vector3 = track.roadside_point(d,lane)
				var closest: float = track.curve.get_closest_offset(p)
				var center: Vector3 = track.point(closest)
				if Vector2(p.x-center.x,p.z-center.z).length()-radius >= track.half_width(closest)+track.rail_setback(closest,1.0)+1.5:
					# The shop front (local +Z) looks at the road.
					var to_road := Vector2(center.x-p.x,center.z-p.z)
					placements.append({"position":p,"yaw":atan2(to_road.x,to_road.y),"scale":scale,"kind":kind})
			d += step
	if placements.is_empty(): return
	var props = Props.new()
	props.name = "LakesideVillages"
	props.configure("fuji",placements)
	add_child(props)

func make_underpass() -> void:
	var walls: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var seams: Array[Transform3D] = []
	var start: float = track.underpass_span().x
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
		node.set_meta("world_barrier",true)
		node.set_meta("collision_transforms",group[0])
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

# The viaduct remains open below; no terrain ribbon spans the lower road.
func bridge_batch(label: String, transforms: Array[Transform3D], tint: Color) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()): multi.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = track.material(tint)
	node.set_meta("world_barrier",true)
	node.set_meta("collision_transforms",transforms)
	add_child(node)
func make_bridge() -> void:
	var span: Vector2 = track.bridge_span
	if span.y <= span.x: return
	var decks: Array[Transform3D] = []
	var piers: Array[Transform3D] = []
	var edges: Array[Transform3D] = []
	var steps := int(ceil((span.y-span.x)/6))
	for i in range(steps):
		var d: float = lerpf(span.x,span.y,(i+0.5)/steps)
		var basis: Basis = preload("res://scripts/fuji_collision.gd").frame(track,d)
		var width: float = track.half_width(d)+1.5
		decks.append(Transform3D(basis.scaled_local(Vector3(width*2+0.7,1.4,(span.y-span.x)/steps+0.3)),track.point(d)-basis.y*0.92))
		for side in [-1.0,1.0]:
			edges.append(Transform3D(basis.scaled_local(Vector3(0.55,1.9,(span.y-span.x)/steps+0.3)),track.point(d,side*(width+0.6))-basis.y*1.1))
		if i%8 != 0: continue
		for side in [-1.0,1.0]:
			var p: Vector3 = track.point(d,side*(width-0.5))
			var clear := true
			# Actual other road footprints decide pier clearance, not just the
			# hand-authored crossing centre. This also protects nearby approaches.
			for sample in range(500):
				var at: float = track.length*sample/500
				if at > span.x-80 and at < span.y+80: continue
				var road: Vector3 = track.point(at)
				if Vector2(p.x-road.x,p.z-road.z).length() < track.half_width(at)+5:
					clear = false
					break
			if not clear: continue
			var height := maxf(1,p.y-1.6+2)
			piers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.2,height,2.6)),Vector3(p.x,-2+height*0.5,p.z)))
	bridge_batch("BridgeDeck",decks,Color("758087"))
	bridge_batch("BridgeEdgeBeams",edges,Color("596b78"))
	bridge_batch("BridgePiers",piers,Color("99a39b"))
