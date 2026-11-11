extends Node3D
var pool: Array[CPUParticles3D] = []
var cursor := 0
func _ready() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0,Color.WHITE)
	gradient.set_color(1,Color(1,1,1,0))
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	var mesh := preload("res://scripts/rendering/render_resources.gd").quad(Vector2(.08,.18))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	var fade := Gradient.new()
	fade.set_color(0,Color(.76,.94,1,.8))
	fade.set_color(1,Color(.45,.75,.9,0))
	for i in range(6):
		var particles := CPUParticles3D.new()
		particles.amount = 18
		particles.lifetime = 0.48
		particles.one_shot = true
		particles.explosiveness = 1
		particles.emitting = false
		particles.local_coords = false
		particles.initial_velocity_min = 4
		particles.initial_velocity_max = 9
		particles.spread = 40
		particles.gravity = Vector3(0,-20,0)
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.4
		particles.mesh = mesh
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.material_override = material
		particles.color_ramp = fade
		add_child(particles)
		pool.append(particles)
func burst(position_world: Vector3, forward: Vector3, reduced: bool) -> void:
	var right := Vector3(-forward.z,0,forward.x).normalized()
	for side in [-1.0,1.0]:
		var particles := pool[cursor]
		cursor = (cursor+1)%pool.size()
		particles.position = position_world-forward*0.9+right*side*0.9+Vector3.UP*0.18
		particles.direction = (-forward+right*side*0.7+Vector3.UP*0.8).normalized()
		particles.amount = 7 if reduced else 18
		particles.restart()
		particles.emitting = true
