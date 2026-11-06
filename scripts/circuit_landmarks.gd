extends Node3D
# Rare landmarks distinguish the one circuit's visual beats without narrowing the road.
const ATLAS = preload("res://assets/environment/fuji-landmarks.png")
const REGIONS := [
	Vector4(0.03889515,0.06426156,0.42671928,0.40248027),
	Vector4(0.56426156,0.05411499,0.39120631,0.41600902),
	Vector4(0.05862458,0.53889515,0.38387824,0.40698985),
	Vector4(0.52762120,0.57158963,0.43235626,0.36640361)
]
const PLACEMENTS := [
	[0.075,2,1.0,6.5],[0.205,0,-1.0,7.0],
	[0.32,1,1.0,14.0],[0.44,1,1.0,11.0],
	[0.66,3,1.0,10.0],[0.84,0,1.0,5.0]
]
var scenery: Node3D
var positions: Array[Vector3] = []
var widths: Array[float] = []
var landmark_distances: Array[float] = []
func _ready() -> void:
	var road: Node3D = scenery.track
	var poses: Array[Transform3D] = []
	var regions: Array[Color] = []
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("6b706b")
	stone.roughness = 0.95
	for spec in PLACEMENTS:
		var d: float = road.length*spec[0]
		var region: Vector4 = REGIONS[spec[1]]
		var side: float = spec[2]
		var height: float = spec[3]
		var width: float = height*region.z*ATLAS.get_width()/(region.w*ATLAS.get_height())
		var lane: float = side*(road.half_width(d)+5+width*0.5)
		var point: Vector3 = scenery.terrain_point(d,lane)
		var closest: float = road.curve.get_closest_offset(point)
		if point.distance_to(road.point(closest))-width*0.5 < road.half_width(closest)+3: continue
		if side < 0:
			point.y = road.point(d).y-height*0.23
			var foot_height := maxf(0.5,point.y-scenery.WATER_HEIGHT+0.12)
			var footing: MeshInstance3D = road.box(self,point-Vector3.UP*(foot_height*0.5),Vector3(width*0.7,foot_height,3.5),stone)
			footing.rotation.y = road.heading(d)
		point.y -= 0.12
		positions.append(point)
		widths.append(width)
		landmark_distances.append(d)
		poses.append(Transform3D(Basis.IDENTITY.scaled_local(Vector3(width,height,1)),point+Vector3.UP*height*0.5))
		regions.append(Color(region.x,region.y,region.z,region.w))
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
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/roadside_sprite.gdshader")
	material.set_shader_parameter("atlas",ATLAS)
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(batch)
