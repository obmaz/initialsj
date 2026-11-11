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
var material_cache := {}
var headlight: SpotLight3D
var headlamp_lenses: Array[MeshInstance3D] = []
var traffic_wheels: MultiMeshInstance3D
var nitro_flames: Array[MeshInstance3D] = []
var wheels: Array[MeshInstance3D] = []
var nitro_glows: Array[MeshInstance3D] = []
var smoke: Array[CPUParticles3D] = []
var brake_lights: Array[StandardMaterial3D] = []
var body: Node3D


func mat(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color.to_html(), metal, glow]
	if material_cache.has(key):
		return material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.27
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	material_cache[key] = m
	return m


func block(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	return preload("res://models/shared/vehicle_geometry.gd").block(self, pos, size, material)


func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	model_definition = preload("res://models/vehicle_models.gd").definition(model)
	for field in ["wheel_radius", "wheel_half_track", "wheel_half_base", "wheel_thickness", "rim_scale", "ride_offset"]:
		set(field, model_definition.parameters[field])
	preload("res://models/vehicle_models.gd").build(self, model_definition)
	body.position.y = ride_offset
	make_drift_smoke()
	if wheels.is_empty():
		make_wheels()
	merge_static_body()


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


# 타이어와 림을 한 메시로 만들어 바퀴 하나를 한 번에 그린다. 좌우는 림이 붙는 면만 다르다.
func make_wheel_mesh(side: float) -> ArrayMesh:
	var tire := CylinderMesh.new()
	tire.top_radius = wheel_radius
	tire.bottom_radius = wheel_radius
	tire.height = wheel_thickness
	tire.radial_segments = 24
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_baked(surface, tire, Transform3D.IDENTITY, mat(Color("131b23")))
	var rim_pose := Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * rim_scale), Vector3(0, -side * (wheel_thickness * 0.5 + 0.015), 0)
	)
	if side > 0:
		rim_pose.basis = Basis(Vector3(0, 0, 1), PI) * rim_pose.basis
	append_baked(surface, make_rim_mesh(), rim_pose, mat(model_definition.parameters.rim_color, 0.85))
	surface.index()
	return surface.commit()


func make_wheels() -> void:
	var axle := wheel_half_track
	var wheelbase := wheel_half_base
	for x in [-axle, axle]:
		var mesh := make_wheel_mesh(signf(x))
		for z in [-wheelbase, wheelbase]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = mesh
			wheel.material_override = shared_body_material()
			body.add_child(wheel)
			wheel.position = Vector3(x, wheel_radius + 0.02, z)
			wheel.rotation.z = PI / 2
			wheels.append(wheel)


func animate(
	steer: float, drifting: bool, boosting: bool, delta: float, yaw: float = NAN, braking: bool = false, hit: float = 0
) -> void:
	body.rotation.z = lerp(body.rotation.z, -steer * 0.06, delta * 8)
	body.rotation.y = (
		lerp_angle(body.rotation.y, -steer * (0.40 if drifting else 0.07), delta * 6) if is_nan(yaw) else yaw
	)
	body.rotation.x = lerpf(body.rotation.x, 0.07 if braking else 0.0, 1 - exp(-delta * 8))
	body.position.y = ride_offset + sin(Time.get_ticks_msec() * 0.05) * hit * 0.08
	for lamp in brake_lights:
		lamp.emission_energy_multiplier = 4.5 if braking else 1.7
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP, -road_speed * delta / wheel_radius)
	for particles in smoke:
		particles.emitting = drifting
	for glow in nitro_glows:
		glow.visible = boosting
	for flame in nitro_flames:
		flame.visible = boosting
		flame.scale.y = randf_range(0.85, 1.35)


func wedge(pos: Vector3, lower: Vector2, upper: Vector2, height: float, offset: float, material: Material) -> void:
	preload("res://models/shared/vehicle_geometry.gd").wedge(self, pos, lower, upper, height, offset, material)


func make_body_shell(material: Material) -> void:
	preload("res://models/shared/vehicle_geometry.gd").make_body_shell(self, material)


func make_rim_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a := TAU * i / 32.0
		var b := TAU * (i + 1) / 32.0
		var u := Vector3(cos(a), 0, sin(a))
		var v := Vector3(cos(b), 0, sin(b))
		var points := [u * 0.235, u * 0.285, v * 0.235, v * 0.285]
		for index in [0, 1, 2, 1, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(points[index])
	var spoke_count := int(model_definition.parameters.spoke_count)
	for i in range(spoke_count):
		var angle := TAU * i / spoke_count
		var direction := Vector3(cos(angle), 0, sin(angle))
		var width := Vector3(-direction.z, 0, direction.x) * 0.028
		var root_point := direction * 0.055
		var tip := direction * 0.25 + width * 0.5
		var points := [root_point - width, tip - width, root_point + width, tip + width]
		for index in [0, 1, 2, 1, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(points[index])
	for i in range(12):
		for p in [
			Vector3.ZERO,
			Vector3(cos(TAU * i / 12), 0, sin(TAU * i / 12)) * 0.075,
			Vector3(cos(TAU * (i + 1) / 12), 0, sin(TAU * (i + 1) / 12)) * 0.075
		]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()


# 재질이 다른 차체 조각도 한 메시로 합쳐 한 번에 그린다. 조각별 색·금속성·거칠기·클리어코트·발광은
# 정점 자료로 옮긴다(shaders/vehicle_body.gdshader). 밝기가 바뀌는 브레이크등만 재질별로 따로 둔다.
static func shared_body_material() -> ShaderMaterial:
	return preload("res://scripts/rendering/render_resources.gd").vehicle_body_material()


# 정점 자료로 옮겨도 모양이 같은 재질인지: 불투명·기본 음영·뒷면 제거·무텍스처.
static func bakeable(material: Material) -> bool:
	if not material is BaseMaterial3D:
		return false
	if material.vertex_color_use_as_albedo or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or material.cull_mode != BaseMaterial3D.CULL_BACK:
		return false
	for slot in range(BaseMaterial3D.TEXTURE_MAX):
		if material.get_texture(slot) != null:
			return false
	return true


static func append_baked(surface: SurfaceTool, mesh: Mesh, pose: Transform3D, material: BaseMaterial3D) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var surface_data := Vector2(material.metallic, material.roughness)
	var coat := Vector2(
		material.clearcoat if material.clearcoat_enabled else 0.0,
		material.emission_energy_multiplier if material.emission_enabled else 0.0
	)
	# 발광 재질은 발광색과 표면색이 같은 색으로 만들어진다(mat()).
	surface.set_color(material.albedo_color)
	surface.set_uv(surface_data)
	surface.set_uv2(coat)
	for index in indices:
		surface.set_normal((pose.basis * normals[index]).normalized())
		surface.add_vertex(pose * vertices[index])


func merge_static_body() -> void:
	var baked := SurfaceTool.new()
	baked.begin(Mesh.PRIMITIVE_TRIANGLES)
	var baked_count := 0
	var groups := {}
	for child in body.get_children():
		if (
			not child is MeshInstance3D
			or child in wheels
			or child in nitro_flames
			or child in nitro_glows
			or child in headlamp_lenses
		):
			continue
		var material: Material = child.material_override
		# 외부 모델의 텍스처·UV·셰이더·다중 표면을 보존한다.
		if child.mesh.get_surface_count() != 1 or not bakeable(material):
			continue
		if material in brake_lights:
			if not groups.has(material):
				groups[material] = []
			groups[material].append(child)
			continue
		append_baked(baked, child.mesh, child.transform, material)
		baked_count += 1
		body.remove_child(child)
		child.queue_free()
	if baked_count > 0:
		baked.index()
		var shell := MeshInstance3D.new()
		shell.name = "BodyShell"
		shell.mesh = baked.commit()
		shell.material_override = shared_body_material()
		body.add_child(shell)
	for material in groups:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child in groups[material]:
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = (
				arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			)
			if indices.is_empty():
				indices = PackedInt32Array(range(vertices.size()))
			for index in indices:
				surface.set_normal((child.transform.basis * normals[index]).normalized())
				surface.add_vertex(child.transform * vertices[index])
			body.remove_child(child)
			child.queue_free()
		surface.index()
		var merged := MeshInstance3D.new()
		merged.name = "BrakeLights"
		merged.mesh = surface.commit()
		merged.material_override = material
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(merged)
	if traffic:
		for wheel in wheels:
			wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var tire := BoxMesh.new()
		tire.size = Vector3(0.3, 0.76, 0.8)
		multi.mesh = tire
		multi.instance_count = 4
		for i in range(4):
			multi.set_instance_transform(
				i, Transform3D(Basis.IDENTITY, Vector3(-1.02 if i < 2 else 1.02, 0.45, -1.35 if i % 2 == 0 else 1.35))
			)
		traffic_wheels = MultiMeshInstance3D.new()
		traffic_wheels.multimesh = multi
		traffic_wheels.material_override = mat(Color("131b23"))
		traffic_wheels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(traffic_wheels)


func set_detail(distance_to_player: float) -> void:
	for wheel in wheels:
		wheel.visible = distance_to_player < 110
	if traffic_wheels != null:
		traffic_wheels.visible = distance_to_player >= 110


func add_boost_jet(pos: Vector3, radius: float) -> void:
	var flame := MeshInstance3D.new()
	var plume := CylinderMesh.new()
	plume.top_radius = 0.015
	plume.bottom_radius = radius
	plume.height = 1.2
	plume.radial_segments = 12
	plume.cap_top = false
	plume.cap_bottom = false
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
	headlight.spot_range = 95
	headlight.spot_angle = 38
	headlight.rotation.x = -deg_to_rad(7)
	headlight.light_color = Color("eaf3ff")
	headlight.light_energy = 3.8
	headlight.spot_angle_attenuation = 1.6
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
