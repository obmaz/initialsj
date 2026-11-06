extends Node3D
# Untouched generated cutouts become distant world-space scenery, with real parallax.
const ATLAS = preload("res://assets/environment/horizon-ridges.png")
const URBAN_THEMES := {"city":0,"seoul":1,"ruins":2,"neon":3}
const REGIONS := [
	Vector4(0.02029312,0.20067644,0.46392334,0.17361894),
	Vector4(0.51578354,0.24351747,0.46843292,0.13190530),
	Vector4(0.01127396,0.71476888,0.47688839,0.13077790),
	Vector4(0.50901917,0.67756483,0.48196167,0.16572717)
]
const THEMES := {"hawaii":0,"jeju":1,"desert":2,"pyramid":2,"canyon":2,"snow":3}
var scenery: Node3D
var positions: Array[Vector3] = []
var widths: Array[float] = []
var sprite_batch: MultiMeshInstance3D
func _ready() -> void:
	if URBAN_THEMES.has(scenery.theme):
		make_urban_skyline()
		return
	if not THEMES.has(scenery.theme): return
	var road: Node3D = scenery.track
	var atlas: Texture2D = ATLAS
	var region: Vector4 = REGIONS[THEMES[scenery.theme]]
	var poses: Array[Transform3D] = []
	var regions: Array[Color] = []
	for i in range(4):
		var d: float = road.length*(0.12+i*0.25)
		var coastal: bool = scenery.theme in ["hawaii","jeju"]
		var side := -1.0 if i%2 else 1.0
		var width := (760.0 if scenery.theme == "snow" else 540.0)+(i%3)*70
		var lane := side*(950.0 if coastal and side < 0 else (950.0 if scenery.theme == "snow" else 680.0))
		var point: Vector3 = road.point(d,lane)
		var closest: float = road.curve.get_closest_offset(point)
		if point.distance_to(road.point(closest))-width*0.5 < 140: continue
		var height := width*region.w*atlas.get_height()/(region.z*atlas.get_width())
		point.y = (-3.0 if coastal and side < 0 else road.point(d).y-12)+height*0.5
		positions.append(point)
		widths.append(width)
		poses.append(Transform3D(Basis.IDENTITY.scaled_local(Vector3(width,height,1)),point))
		regions.append(Color(region.x+(region.z if i%2 else 0),region.y,-region.z if i%2 else region.z,region.w))
	if poses.is_empty(): return
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()):
		multi.set_instance_transform(i,poses[i])
		multi.set_instance_custom_data(i,regions[i])
	sprite_batch = MultiMeshInstance3D.new()
	sprite_batch.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/roadside_sprite.gdshader")
	material.set_shader_parameter("atlas",atlas)
	sprite_batch.material_override = material
	sprite_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite_batch)


func make_urban_skyline() -> void:
	var road: Node3D = scenery.track
	var random := RandomNumberGenerator.new()
	random.seed = 930+road.stage*7+road.route_node
	var groups := [[],[],[],[]]
	for cluster in range(4):
		var d: float = road.length*(0.14+cluster*0.23)
		var side := -1.0 if cluster%2 == 0 else 1.0
		for i in range(30):
			var at: float = d+(i-15)*19
			var lane: float = side*(530+random.randf_range(0,210))
			var p: Vector3 = road.point(at,lane)
			var radius := 24.0
			var closest: float = road.curve.get_closest_offset(p)
			var center: Vector3 = road.point(closest)
			if Vector2(p.x-center.x,p.z-center.z).length()-radius < road.half_width(closest)+90: continue
			var style := (i+cluster)%4
			var height := random.randf_range(32,110)
			if scenery.theme == "ruins": height *= 0.6
			var width := random.randf_range(16,31)
			var depth := random.randf_range(16,32)
			p.y = -5
			var tiers := 3 if style == 2 else 1
			var base := 0.0
			for tier in range(tiers):
				var h := height*(0.5 if tier == 0 else 0.25) if tiers > 1 else height
				var size := Vector3(width*(1-tier*0.22),h,depth*(1-tier*0.22))
				groups[style].append(Transform3D(Basis(Vector3.UP,road.heading(at)).scaled_local(size),p+Vector3.UP*(base+h*0.5)))
				base += h
			positions.append(p)
			widths.append(width)
	for style in range(4):
		var poses: Array[Transform3D] = []
		poses.assign(groups[style])
		var mesh: Mesh
		if style == 1:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1
			cylinder.radial_segments = 8
			mesh = cylinder
		else:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			mesh = cube
		var color := Color("69828e") if scenery.theme == "city" else (Color("8b9185") if scenery.theme == "seoul" else (Color("605b4b") if scenery.theme == "ruins" else Color("303d54")))
		var material := StandardMaterial3D.new()
		material.albedo_color = color.lightened(style*0.035)
		material.roughness = 1
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var node: MultiMeshInstance3D = scenery.batch(mesh,material,poses,false)
		node.reparent(self)
		node.name = "DistantBuildings3D_"+str(style)
