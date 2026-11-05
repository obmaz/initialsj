extends Node3D
var petals := CPUParticles3D.new()
var material := ShaderMaterial.new()
var last_theme := ""
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
	material.shader = preload("res://shaders/sakura_petal.gdshader")
	petals.material_override = material
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.9))
	fade.add_point(0.7, Color(1, 1, 1, 0.9))
	petals.color_ramp = fade
	add_child(petals)
func update(race: Node3D) -> void:
	var theme: String = race.track.active.scenery.theme
	if theme != last_theme:
		last_theme = theme
		var start := Color("ffe9c8") if theme in ["desert","pyramid","ruins"] else Color("f4f4ff")
		var end := Color("c7a77e") if theme in ["desert","pyramid","ruins"] else Color("d4ebed")
		if theme == "jeju": end = Color("ffb5ce")
		material.set_shader_parameter("petal_start",start)
		material.set_shader_parameter("petal_end",end)
		material.set_shader_parameter("confetti",1.0 if theme == "amusement" else 0.0)
		petals.amount = 20 if theme in ["city","seoul"] else 36
	petals.emitting = race.state == "racing" and not race.motion_reduced
	petals.visible = not race.motion_reduced
	petals.position = race.track.point(race.distance + 18) + Vector3.UP * 3
	petals.rotation.y = race.player.rotation.y
