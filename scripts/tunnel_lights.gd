extends Node3D
# Three real fixture families with a shared nearest-light budget for WebGL.
const MAX_NEARBY := 6
const UPDATE_PERIOD := 0.06
static var pipeline_warmed := false
var update_clock := 0.0
var selection_passes := 0
var visibility_changes := 0
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
	selection_passes += 1
	# Keep only the closest budget entries; never sort every lamp in a long tunnel.
	var nearest: Array[int] = []
	var distances: Array[float] = []
	for i in range(lights.size()):
		var distance := lights[i].position.distance_squared_to(at)
		if distance >= 39*39: continue
		var insertion := 0
		while insertion < distances.size() and distances[insertion] <= distance: insertion += 1
		if insertion >= MAX_NEARBY: continue
		distances.insert(insertion,distance)
		nearest.insert(insertion,i)
		if nearest.size() > MAX_NEARBY:
			nearest.pop_back()
			distances.pop_back()
	for i in range(lights.size()):
		var wanted := nearest.has(i)
		# Unchanged lamps must not be removed and re-added to the renderer every frame.
		if lights[i].visible != wanted:
			lights[i].visible = wanted
			visibility_changes += 1

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	update_clock -= delta
	if update_clock > 0: return
	update_clock = UPDATE_PERIOD
	var camera := get_viewport().get_camera_3d()
	if camera != null: update_lights(camera.global_position)

static func collect_rigs(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	if node.get_script() == load("res://scripts/tunnel_lights.gd"): out.append(node)
	for child in node.get_children(): out.append_array(collect_rigs(child))
	return out

static func prewarm_scene(race: Node3D) -> void:
	if pipeline_warmed or DisplayServer.get_name() == "headless": return
	var rigs := collect_rigs(race.track)
	if rigs.is_empty(): return
	# Run only behind the opaque screen-transition cover. The normal first world
	# frame does not see a tunnel, so it cannot prepare local-light shader variants.
	var rig: Node3D = rigs[0]
	var camera: Camera3D = race.camera
	var saved_transform := camera.global_transform
	var saved_processing: bool = race.is_physics_processing()
	var was_visible: bool = race.track.visible
	race.set_physics_process(false)
	race.track.visible = true
	for offset in [0.0,28.0,44.0,60.0,76.0]:
		var d: float = minf(rig.span.y-10,rig.span.x+offset)
		camera.position = rig.track.point(d)+Vector3.UP*2.3
		camera.look_at(rig.track.point(d+24)+Vector3.UP*2.0)
		camera.reset_physics_interpolation()
		rig.update_lights(camera.global_position)
		await race.get_tree().process_frame
		await RenderingServer.frame_post_draw
	camera.global_transform = saved_transform
	camera.reset_physics_interpolation()
	for other in rigs: other.update_lights(camera.global_position)
	race.track.visible = was_visible
	race.set_physics_process(saved_processing)
	pipeline_warmed = true
