extends Node3D
var petals := CPUParticles3D.new()
func _ready() -> void:
	petals.amount = 36
	petals.lifetime = 1.1
	petals.emitting = false
	petals.local_coords = false
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(10, 3, 18)
	petals.direction = Vector3(0, -0.2, 1)
	petals.spread = 25
	petals.initial_velocity_min = 1
	petals.initial_velocity_max = 4
	petals.gravity = Vector3(-0.4, -0.4, 0.5)
	petals.scale_amount_min = 0.6
	petals.scale_amount_max = 1.8
	petals.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.18, 0.18)
	petals.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sakura_petal.gdshader")
	petals.material_override = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.9))
	fade.add_point(0.7, Color(1, 1, 1, 0.9))
	petals.color_ramp = fade
	add_child(petals)
func update(race: Node3D) -> void:
	petals.emitting = race.state == "racing" and not race.motion_reduced
	petals.visible = not race.motion_reduced
	petals.position = race.track.point(race.distance + 18) + Vector3.UP * 3
	petals.rotation.y = race.player.rotation.y
