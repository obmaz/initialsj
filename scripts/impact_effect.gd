extends Node3D
var pool: Array[CPUParticles3D] = []
var cursor := 0
func _ready() -> void:
	for i in range(4):
		var particles := CPUParticles3D.new()
		particles.amount = 40
		particles.lifetime = 0.55
		particles.one_shot = true
		particles.explosiveness = 1
		particles.emitting = false
		particles.local_coords = false
		particles.initial_velocity_min = 5
		particles.initial_velocity_max = 15
		particles.spread = 45
		particles.gravity = Vector3(0,-19,0)
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 1.3
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.15,0.65)
		particles.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/impact_spark.gdshader")
		particles.material_override = material
		var fade := Gradient.new()
		fade.set_color(0,Color.WHITE)
		fade.set_color(1,Color(1,0.5,0.1,0))
		particles.color_ramp = fade
		add_child(particles)
		pool.append(particles)
func burst(position_world: Vector3, direction_world: Vector3, reduced: bool) -> void:
	var particles := pool[cursor]
	cursor = (cursor+1) % pool.size()
	particles.position = position_world
	particles.direction = (direction_world + Vector3.UP * 0.7).normalized()
	particles.amount = 12 if reduced else 40
	particles.restart()
	particles.emitting = true
