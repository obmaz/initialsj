extends Node3D
# Untouched generated cutouts become distant world-space scenery, with real parallax.
const ATLAS = preload("res://assets/environment/horizon-ridges.png")
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
	if not THEMES.has(scenery.theme): return
	var road: Node3D = scenery.track
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
		var height := width*region.w/region.z
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
	material.set_shader_parameter("atlas",ATLAS)
	sprite_batch.material_override = material
	sprite_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite_batch)
