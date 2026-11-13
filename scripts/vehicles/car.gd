extends Node3D

var model_definition: Resource
var paint := Color("b51223")
var model := "sport"
var wheel_half_track := 1.02
var wheel_half_base := 1.35
var wheel_thickness := 0.3
var rim_scale := 1.0
var ride_offset := 0.0
var nitro_tint := Color("56dfff")
var wheel_radius := 0.43
var road_speed := 0.0
var traffic := false
var headlight: SpotLight3D
var headlamp_lenses: Array[MeshInstance3D] = []
var traffic_wheels: MultiMeshInstance3D
var nitro_flames: Array[MeshInstance3D] = []
var wheels: Array[MeshInstance3D] = []
var nitro_glows: Array[MeshInstance3D] = []
var smoke: Array[CPUParticles3D] = []
var brake_lights: Array[StandardMaterial3D] = []
var equipped_effects: Array[String] = []
var presentation: Node3D
var body: Node3D
var boost_shot := false
var protection_active := false
var protection_parts: Array[MeshInstance3D] = []
var protection_originals: Array[Material] = []
var protection_materials: Dictionary = {}
var boost_fx: Node3D
var active_aero: MeshInstance3D
var aero_rest := Transform3D.IDENTITY
var aero_drop := 0.0
var aero_pitch := 0.0
var aero_blend := 0.0
var effects_quality := 0
var reduced_motion := false
var custom_plate := "STOCK"
var body_motion := preload("res://scripts/effects/body_motion.gd").new()
var shift_amount := 0.0
var wheel_centres: Array[Vector3] = []


func _ready() -> void:
	if preload("res://models/shared/scene_state.gd").bind(self):
		restore_paint()
		return
	model_definition = preload("res://models/vehicle_models.gd").definition(model)
	for field in ["wheel_radius", "wheel_half_track", "wheel_half_base", "wheel_thickness", "rim_scale", "ride_offset"]:
		set(field, model_definition.parameters[field])
	const RenderResources = preload("res://scripts/rendering/render_resources.gd")
	if traffic and RenderResources.traffic_models.has(model):
		body = RenderResources.traffic_models[model].instantiate()
		add_child(body)
		for child in body.get_children():
			if child is SpotLight3D:
				headlight = child
			if child.get_meta("traffic_brake", false):
				child.material_override = child.material_override.duplicate()
				brake_lights.append(child.material_override)
			var part: String = child.get_meta("traffic_part", "")
			if part == "traffic_wheels":
				traffic_wheels = child
			elif not part.is_empty():
				get(part).append(child)
		restore_paint()
		return
	body = Node3D.new()
	if not traffic:
		presentation = Node3D.new()
		presentation.name = "Presentation"
		add_child(presentation)
		presentation.add_child(body)
	else:
		add_child(body)
	preload("res://models/vehicle_models.gd").build(self, model_definition)
	body.position.y = ride_offset
	if not traffic:
		make_drift_smoke()
	assert(wheels.size() == 4, "차량 GLB에는 네 휠 피벗이 필요하다")
	if not traffic:
		boost_fx = preload("res://scripts/effects/boost_exhaust.gd").new()
		body.add_child(boost_fx)
		boost_fx.configure(self)
	if traffic:
		for part in ["wheels", "headlamp_lenses", "nitro_flames", "nitro_glows"]:
			for child in get(part):
				child.set_meta("traffic_part", part)
		traffic_wheels.set_meta("traffic_part", "traffic_wheels")
		for child in body.find_children("*", "", true, false):
			child.owner = body
			if (
				child is MeshInstance3D
				and child.material_override is StandardMaterial3D
				and child.material_override in brake_lights
			):
				child.set_meta("traffic_brake", true)
		var prototype := PackedScene.new()
		if prototype.pack(body) == OK:
			RenderResources.traffic_models[model] = prototype


func make_drift_smoke() -> void:
	for x in [-0.8, 0.8]:
		var particles := CPUParticles3D.new()
		particles.amount = 22
		particles.lifetime = 0.7
		particles.emitting = false
		particles.local_coords = false
		particles.direction = Vector3(0, 0.3, 1)
		particles.spread = 35
		particles.initial_velocity_min = 1
		particles.initial_velocity_max = 5
		particles.gravity = Vector3(0, 0.6, 0)
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 2.5
		var puff := preload("res://scripts/rendering/render_resources.gd").quad(Vector2(1.2, 1.2))
		particles.mesh = puff
		var smoke_mat := ShaderMaterial.new()
		smoke_mat.shader = preload("res://shaders/tire_smoke.gdshader")
		particles.material_override = smoke_mat
		var fade := Gradient.new()
		fade.set_color(0, Color(0.78, 0.83, 0.9, 0.4))
		fade.set_color(1, Color(0.78, 0.83, 0.9, 0))
		particles.color_ramp = fade
		body.add_child(particles)
		particles.position = Vector3(x, 0.25, wheel_half_base)
		smoke.append(particles)


func animate(
	steer: float, drifting: bool, boosting: bool, delta: float, yaw: float = NAN, braking: bool = false, hit: float = 0
) -> void:
	body_motion.advance(delta, model, reduced_motion, shift_amount)
	body.rotation.z = body_motion.pose.z
	body.rotation.y = (
		lerp_angle(body.rotation.y, -steer * (0.40 if drifting else 0.07), delta * 6) if is_nan(yaw) else yaw
	)
	body.rotation.x = body_motion.pose.x
	body.position.y = ride_offset + body_motion.pose.y + sin(Time.get_ticks_msec() * 0.05) * hit * 0.08
	for lamp in brake_lights:
		lamp.emission_energy_multiplier = 4.5 if braking else 1.7
	if wheel_centres.is_empty():
		for wheel in wheels:
			wheel_centres.append(wheel.position + Vector3.UP * ride_offset)
	var suspension_inverse := body.transform.affine_inverse()
	for i in range(wheels.size()):
		var wheel: MeshInstance3D = wheels[i]
		# 시각 차체가 기울어도 휠 중심은 원래 노면 높이에 둔다.
		wheel.position = suspension_inverse * wheel_centres[i]
		wheel.rotate_object_local(Vector3.UP, -road_speed * delta / wheel_radius)
	for particles in smoke:
		particles.emitting = drifting
	if boost_fx != null:
		boost_fx.advance(boosting, delta, reduced_motion, effects_quality, boost_shot)
		if active_aero != null:
			aero_blend = lerpf(aero_blend, smoothstep(.2, .85, boost_fx.heat), 1 - exp(-delta * 5))
			active_aero.transform = aero_rest
			active_aero.position.y -= aero_blend * aero_drop
			active_aero.rotate_object_local(Vector3.RIGHT, aero_blend * aero_pitch)
	else:
		for glow in nitro_glows:
			glow.visible = boosting
		for flame in nitro_flames:
			flame.visible = boosting


func reset_driving_effects() -> void:
	if presentation != null:
		set_presentation_rotation(Vector3.ZERO)
	body_motion.reset()
	shift_amount = 0
	if body != null:
		body.rotation = Vector3.ZERO
		body.position = Vector3(0, ride_offset, 0)
	for i in range(wheel_centres.size()):
		wheels[i].position = wheel_centres[i] - Vector3.UP * ride_offset
	if boost_fx != null:
		boost_fx.reset()
	aero_blend = 0
	if active_aero != null:
		active_aero.transform = aero_rest
	for particles in smoke:
		particles.restart()
		particles.emitting = false


static func shared_body_material() -> ShaderMaterial:
	return preload("res://scripts/rendering/render_resources.gd").vehicle_body_material()


func set_detail(distance_to_player: float) -> void:
	for wheel in wheels:
		wheel.visible = distance_to_player < 110
	if traffic_wheels != null:
		traffic_wheels.visible = distance_to_player >= 110


func add_boost_jet(pos: Vector3, radius: float) -> void:
	var flame := MeshInstance3D.new()
	var plume := preload("res://scripts/rendering/primitive_assets.gd").mesh("plume_%d" % roundi(radius * 100000))
	flame.mesh = plume
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/nitro_flame.gdshader")
	material.set_shader_parameter("tint", nitro_tint)
	flame.material_override = material
	body.add_child(flame)
	flame.position = pos + Vector3(0, 0, 0.48)
	flame.rotation.x = PI / 2
	flame.visible = false
	nitro_flames.append(flame)
	var glow := MeshInstance3D.new()
	var quad := preload("res://scripts/rendering/render_resources.gd").quad(Vector2.ONE * radius * 4)
	glow.mesh = quad
	var glow_material := ShaderMaterial.new()
	glow_material.shader = preload("res://shaders/nitro_glow.gdshader")
	glow_material.set_shader_parameter("tint", nitro_tint)
	glow.material_override = glow_material
	body.add_child(glow)
	glow.position = pos + Vector3(0, 0, 0.08)
	glow.visible = false
	nitro_glows.append(glow)


func add_headlight(pos: Vector3) -> void:
	headlight = SpotLight3D.new()
	headlight.position = pos
	headlight.spot_range = 165
	headlight.spot_angle = 38
	headlight.rotation.x = -deg_to_rad(4)
	headlight.light_color = Color("eaf3ff")
	headlight.light_energy = 7.0
	headlight.spot_angle_attenuation = 1.2
	headlight.shadow_enabled = false
	headlight.visible = false
	body.add_child(headlight)
	for side in [-1.0, 1.0]:
		var lens := MeshInstance3D.new()
		lens.name = "NightHeadlamp"
		var mesh := preload("res://scripts/rendering/render_resources.gd").quad(Vector2(0.26, 0.13))
		lens.mesh = mesh
		lens.position = pos + Vector3(side * 0.65, 0, -0.26)
		var anchors: PackedVector3Array = model_definition.parameters.get("headlamp_positions", PackedVector3Array())
		if anchors.size() == 2:
			lens.position = anchors[0 if side < 0 else 1]
		lens.rotation.y = PI
		var luminous := StandardMaterial3D.new()
		luminous.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		luminous.albedo_color = Color("f3f9ff")
		luminous.emission_enabled = true
		luminous.emission = Color("d2eaff")
		luminous.emission_energy_multiplier = 3
		lens.material_override = luminous
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.visible = false
		body.add_child(lens)
		headlamp_lenses.append(lens)


func set_headlights(enabled: bool, illuminate_road: bool = true) -> void:
	if headlight != null:
		headlight.visible = enabled and illuminate_road
	for lens in headlamp_lenses:
		lens.visible = enabled


# vec4 유니폼에는 Vector4를 저장한다. Color를 저장하면 엔진의 재질 복제가 원본 캐시까지 비운다.
func paint_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shared_body_material().shader
	material.set_shader_parameter("repaint_traffic", true)
	material.set_shader_parameter("traffic_paint", Vector4(paint.r, paint.g, paint.b, paint.a))
	return material


func restore_paint() -> void:
	var material := paint_material()
	for node in body.get_children():
		if node is MeshInstance3D and node.name == "PaintShell":
			node.material_override = preload("res://scripts/vehicles/vehicle_customization.gd").paint_material(paint)
			continue
		if (
			node is MeshInstance3D
			and not node in wheels
			and node.material_override is ShaderMaterial
			and node.material_override.shader == material.shader
		):
			node.material_override = material


func apply_customization(color: Color, plate: String) -> void:
	if paint == color and custom_plate == plate:
		return
	set_protection(false)
	protection_parts.clear()
	protection_originals.clear()
	protection_materials.clear()
	paint = color
	custom_plate = plate
	restore_paint()
	for node in body.get_children():
		if node is Label3D and absf(node.position.x) < .05 and node.position.z > 1.5:
			if not node.has_meta("stock_plate"):
				node.set_meta("stock_plate", node.text)
			node.text = str(node.get_meta("stock_plate")) if plate == "STOCK" else plate


# 불투명한 청록 차체로 보호 상태를 표시한다. 공유 재질은 바꾸지 않는다.
func set_protection(active: bool) -> void:
	if active == protection_active:
		return
	protection_active = active
	if protection_parts.is_empty():
		for node in body.find_children("*", "MeshInstance3D", true, false):
			var material: Material = node.material_override
			if (
				material is ShaderMaterial
				and (
					material.shader
					in [
						shared_body_material().shader,
						preload("res://shaders/vehicle_livery.gdshader"),
						preload("res://shaders/tuning_wheel.gdshader")
					]
				)
			):
				protection_parts.append(node)
				protection_originals.append(material)
				if not protection_materials.has(material):
					var copy: ShaderMaterial = material.duplicate()
					copy.set_shader_parameter("protection", true)
					protection_materials[material] = copy
	for i in range(protection_parts.size()):
		var original: Material = protection_originals[i]
		protection_parts[i].material_override = protection_materials[original] if active else original


# 무적 마지막1.2초 동안 원래 재질로 돌아오며, 모션 감소 설정은 점멸 없이 감쇠한다.
func update_protection(seconds: float, reduce_motion: bool = false) -> void:
	set_protection(seconds > 0)
	if not protection_active:
		return
	var fade := clampf(seconds / 1.2, 0, 1)
	var pulse := 1.0 if reduce_motion or seconds >= 1.2 else .25 + .75 * (.5 + .5 * sin(seconds * TAU * 2.5))
	for material in protection_materials.values():
		material.set_shader_parameter("protection_amount", fade * pulse)


func set_presentation_rotation(value: Vector3) -> void:
	if presentation != null:
		presentation.basis = Basis.from_euler(value)
		var center := Vector3(0, .65, 0)
		presentation.position = center - presentation.basis * center
