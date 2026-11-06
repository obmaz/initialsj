extends Node3D
# Three real fixture families with a shared nearest-light budget for WebGL.
var track: Node3D
var span := Vector2.ZERO
var ceiling := 7.0
var lights: Array[Light3D] = []
var families: Array[int] = []
var fixtures := {"rim":[],"warm":[],"cool":[],"amber":[]}
func _ready() -> void:
	var count := int(ceil((span.y-span.x)/32))
	for i in range(count):
		var d: float = minf(span.y-6,span.x+12+i*32)
		var family := i%3
		var heading: float = track.heading(d)
		var basis := Basis(Vector3.UP,heading)
		var width: float = track.half_width(d)
		for side in [-1.0,1.0]:
			var light: Light3D
			var p: Vector3
			if family == 0:
				p = track.point(d,side*width*0.45)+Vector3.UP*ceiling
				fixtures.rim.append(Transform3D(basis.scaled_local(Vector3(1.5,0.18,0.9)),p+Vector3.UP*0.13))
				fixtures.warm.append(Transform3D(basis.scaled_local(Vector3(1.15,0.14,0.65)),p))
				light = point_light(p,Color("ffcf8a"),2.0,25)
			elif family == 1:
				p = track.point(d,side*width*0.70)+Vector3.UP*(ceiling-0.7)
				fixtures.rim.append(Transform3D(basis.scaled_local(Vector3(0.42,0.18,10.5)),p+Vector3.UP*0.1))
				fixtures.cool.append(Transform3D(basis.scaled_local(Vector3(0.20,0.10,10)),p))
				light = point_light(p,Color("b6e4ff"),1.7,26)
			else:
				p = track.point(d,side*(width-0.4))+Vector3.UP*4.8
				var target: Vector3 = track.point(d+8)+Vector3.UP*0.2
				var spot := SpotLight3D.new()
				spot.position = p
				spot.light_color = Color("ffd48d")
				spot.light_energy = 3.2
				spot.spot_range = 29
				spot.spot_angle = 53
				spot.spot_attenuation = 0.7
				spot.shadow_enabled = false
				add_child(spot)
				spot.look_at(target)
				light = spot
				fixtures.rim.append(Transform3D(spot.basis.scaled_local(Vector3(0.8,0.65,0.7)),p))
				fixtures.amber.append(Transform3D(spot.basis.scaled_local(Vector3(0.57,0.44,0.08)),p-spot.basis.z*0.38))
			lights.append(light)
			families.append(family)
	for key in fixtures:
		var transforms: Array[Transform3D] = []
		for t in fixtures[key]: transforms.append(t)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = {"rim":Color("24313b"),"warm":Color("ffda9a"),"cool":Color("c4ebff"),"amber":Color("ffbd63")}[key]
		if key != "rim":
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 1.4
		track.box_batch(Vector3.ONE,mat,transforms)
	update_lights(track.point(span.x))
func point_light(p: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = p
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.25
	light.shadow_enabled = false
	add_child(light)
	return light
func update_lights(at: Vector3) -> void:
	var nearest: Array[int] = []
	for i in range(lights.size()):
		lights[i].visible = false
		if lights[i].position.distance_to(at) < 39: nearest.append(i)
	nearest.sort_custom(func(a,b): return lights[a].position.distance_squared_to(at) < lights[b].position.distance_squared_to(at))
	for i in range(mini(6,nearest.size())): lights[nearest[i]].visible = true
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null: update_lights(camera.global_position)
