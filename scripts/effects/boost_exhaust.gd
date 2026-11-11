extends Node3D
# 차량 한 대가 소유하는 고정 수의 배기 효과. 부스트 중에도 노드·메시를 새로 만들지 않는다.
const HEAT_SECONDS := 3.2
var held := 0.0
var heat := 0.0
var envelope := 0.0
var clock := 0.0
var tint := Color.WHITE
var emitters: Array[CPUParticles3D] = []
var flames: Array[MeshInstance3D] = []
var glows: Array[MeshInstance3D] = []
var rests: Array[Transform3D] = []
var accent := Color("56dfff")


func configure(car: Node3D) -> void:
	accent = car.nitro_tint
	flames.assign(car.nitro_flames)
	glows.assign(car.nitro_glows)
	for i in range(flames.size()):
		var flame := flames[i]
		rests.append(flame.transform)
		var particles := CPUParticles3D.new()
		particles.name = "BoostEmbers%d" % i
		particles.amount = 24
		particles.lifetime = .28
		particles.emitting = false
		particles.local_coords = false
		particles.direction = Vector3.BACK
		particles.spread = 12
		particles.initial_velocity_min = 3
		particles.initial_velocity_max = 9
		particles.gravity = Vector3(0, .4, 0)
		particles.scale_amount_min = .4
		particles.scale_amount_max = 1.1
		particles.mesh = preload("res://scripts/rendering/render_resources.gd").quad(Vector2(.12, .3))
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/boost_ember.gdshader")
		particles.material_override = material
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0, .25, 1])
		ramp.colors = PackedColorArray([Color(1, 1, 1, .85), Color(1, 1, 1, .65), Color(1, 1, 1, 0)])
		particles.color_ramp = ramp
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particles)
		particles.position = rests[i].origin - rests[i].basis.y * .56
		emitters.append(particles)
	reset()


func reset() -> void:
	held = 0
	heat = 0
	envelope = 0
	clock = 0
	for i in range(flames.size()):
		flames[i].transform = rests[i]
		flames[i].visible = false
	for glow in glows:
		glow.visible = false
	for particles in emitters:
		particles.visible = false
		particles.restart()
		particles.emitting = false


func advance(active: bool, delta: float, reduced: bool, quality: int) -> void:
	for particles in emitters:
		particles.speed_scale = 0 if delta <= 0 else 1
	if delta <= 0:
		return
	clock += delta
	held = minf(HEAT_SECONDS, held + delta) if active else 0.0
	var target := held / HEAT_SECONDS
	heat = lerpf(heat, target, 1 - exp(-delta * (5 if active else 9)))
	envelope = move_toward(envelope, 1.0 if active else 0.0, delta * (10 if active else 7))
	var cold := accent.lerp(Color("67eaff"), .65)
	tint = cold.lerp(Color("aa6bff"), smoothstep(.1, .6, heat))
	tint = tint.lerp(Color("ffd38a"), smoothstep(.6, 1, heat))
	var pulse := 1.0 if reduced else 1.0 + sin(clock * 39) * .055
	var length_scale := (1.0 + heat * 1.25) * pulse
	for i in range(flames.size()):
		var flame := flames[i]
		flame.visible = envelope > .01
		flame.scale = Vector3(1 + heat * .5, length_scale * maxf(.01, envelope), 1 + heat * .5)
		# 원뿔의 배기구 쪽을 고정해 차체 안쪽으로 불꽃이 자라지 않게 한다.
		flame.position = rests[i].origin + rests[i].basis.y * (.6 * (flame.scale.y - 1))
		flame.material_override.set_shader_parameter("tint", tint)
		flame.material_override.set_shader_parameter("strength", envelope)
		flame.material_override.set_shader_parameter("calm", reduced)
	for glow in glows:
		glow.visible = envelope > .01
		glow.scale = Vector3.ONE * (1 + heat * .65) * maxf(.01, envelope)
		glow.material_override.set_shader_parameter("tint", tint)
		glow.material_override.set_shader_parameter("strength", envelope)
	for particles in emitters:
		particles.visible = not reduced
		particles.emitting = active and not reduced
		var amount := 12 if quality >= 2 else (18 if quality == 1 else 24)
		if particles.amount != amount:
			particles.amount = amount
		particles.material_override.set_shader_parameter("tint", tint)
		particles.scale_amount_min = .4 + heat * .3
		particles.scale_amount_max = 1.1 + heat * 1.3
