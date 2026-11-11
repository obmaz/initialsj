extends Node3D
# Reuse four short one-shot emitters. Only a real contact can request a burst;
# strength controls the size and lifetime, and reduced motion omits metal chips.
const POOL_SIZE := 4
static var pipeline_warmed := false
var pool: Array[CPUParticles3D] = []
var chips: Array[CPUParticles3D] = []
var cursor := 0


func _ready() -> void:
	var spark_mesh := preload("res://scripts/rendering/render_resources.gd").quad(Vector2(0.11, 0.52))
	var spark_material := ShaderMaterial.new()
	spark_material.shader = preload("res://shaders/impact_spark.gdshader")
	var chip_mesh := preload("res://scripts/rendering/primitive_assets.gd").mesh("impact_chip")
	var chip_material := StandardMaterial3D.new()
	chip_material.albedo_color = Color("9daeb8")
	chip_material.metallic = 0.35
	chip_material.roughness = 0.55
	for i in range(POOL_SIZE):
		var particles := CPUParticles3D.new()
		particles.amount = 36
		particles.lifetime = 0.46
		particles.one_shot = true
		particles.explosiveness = 1
		particles.emitting = false
		particles.local_coords = false
		particles.spread = 38
		particles.gravity = Vector3(0, -19, 0)
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 1.2
		particles.mesh = spark_mesh
		particles.material_override = spark_material
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 0.5, 0.1, 0))
		particles.color_ramp = fade
		add_child(particles)
		pool.append(particles)
		var debris := CPUParticles3D.new()
		debris.amount = 8
		debris.lifetime = 0.38
		debris.one_shot = true
		debris.explosiveness = 1
		debris.emitting = false
		debris.local_coords = false
		debris.spread = 52
		debris.gravity = Vector3(0, -23, 0)
		debris.angular_velocity_min = -420
		debris.angular_velocity_max = 420
		debris.scale_amount_min = 0.6
		debris.scale_amount_max = 1.3
		debris.mesh = chip_mesh
		debris.material_override = chip_material
		debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(debris)
		chips.append(debris)
	reset()


func reset() -> void:
	cursor = 0
	for particles in pool + chips:
		particles.emitting = false
		particles.visible = false


func burst(position_world: Vector3, direction_world: Vector3, reduced: bool, strength: float = 1.0) -> void:
	strength = clampf(strength, 0, 1)
	if strength < 0.07:
		return
	var particles := pool[cursor]
	var debris := chips[cursor]
	cursor = (cursor + 1) % POOL_SIZE
	particles.position = position_world
	particles.direction = (direction_world + Vector3.UP * 0.55).normalized()
	particles.amount = roundi(lerpf(6, 12, strength)) if reduced else roundi(lerpf(10, 36, strength))
	particles.lifetime = lerpf(0.24, 0.46, strength)
	particles.initial_velocity_min = lerpf(2.5, 5.5, strength)
	particles.initial_velocity_max = lerpf(5, 14, strength)
	particles.visible = true
	particles.restart()
	particles.emitting = true
	debris.visible = not reduced and strength > 0.32
	debris.emitting = false
	if debris.visible:
		debris.position = position_world
		debris.direction = (direction_world + Vector3.UP * 0.4).normalized()
		debris.amount = roundi(lerpf(3, 8, strength))
		debris.initial_velocity_min = 2.0
		debris.initial_velocity_max = lerpf(4, 8, strength)
		debris.restart()
		debris.emitting = true


# Caller keeps the opaque scene-transition cover in place until this returns.
# This warms both particle materials without changing race/camera/physics state.
func prewarm(camera: Camera3D) -> void:
	if pipeline_warmed or DisplayServer.get_name() == "headless":
		return
	burst(camera.global_position - camera.global_basis.z * 4, Vector3.UP, false, 0.8)
	pool[0].lifetime = 1.0
	chips[0].lifetime = 1.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	reset()
	pool[0].lifetime = 0.46
	chips[0].lifetime = 0.38
	pipeline_warmed = true
