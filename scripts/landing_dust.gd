extends Node3D
# Short, bounded landing bursts; there is no continuous ambient particle emitter.
var particles: CPUParticles3D
func _ready() -> void:
	particles = CPUParticles3D.new()
	particles.amount = 22
	particles.lifetime = 0.48
	particles.one_shot = true
	particles.explosiveness = 1
	particles.emitting = false
	particles.local_coords = false
	particles.initial_velocity_min = 1.3
	particles.initial_velocity_max = 4
	particles.direction = Vector3.UP
	particles.spread = 82
	particles.gravity = Vector3(0,-5,0)
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.9
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75,0.75)
	particles.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/landing_dust.gdshader")
	particles.material_override = mat
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.48))
	gradient.set_color(1,Color(1,1,1,0))
	particles.color_ramp = gradient
	add_child(particles)
func burst(at: Vector3, reduced: bool) -> void:
	particles.position = at+Vector3.UP*0.15
	particles.amount = 6 if reduced else 22
	particles.restart()
	particles.emitting = true
