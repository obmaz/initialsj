extends RefCounted


static func build(car: Node3D) -> void:
	var shell: StandardMaterial3D = car.mat(car.paint, 0.55)
	shell.clearcoat_enabled = true
	shell.roughness = 0.20
	shell.clearcoat = 0.35
	shell.clearcoat_roughness = 0.12
	var dark: StandardMaterial3D = car.mat(Color("10212d"), 0.5)
	var glass: StandardMaterial3D = car.mat(Color("253e50"), 0.75)
	car.make_body_shell(shell)
	car.block(Vector3(0, 0.86, -1.35), Vector3(1.75, 0.08, 1.35), shell)
	car.wedge(Vector3(0, 0.93, 0.1), Vector2(1.7, 2.2), Vector2(1.45, 1.25), 0.38, 0.16, glass)
	car.block(Vector3(0, 1.34, 0.15), Vector3(1.46, 0.09, 1.25), shell)
	car.wedge(Vector3(0, 0.24, 2.15), Vector2(1.5, 0.26), Vector2(1.9, 0.25), 0.30, 0, dark)
	car.block(Vector3(0, 0.42, -2.21), Vector3(2.12, 0.12, 0.25), dark)
	for x in [-0.50, 0.50]:
		var lamp: StandardMaterial3D = car.mat(Color("ff2620"), 0, true)
		car.brake_lights.append(lamp)
		car.block(Vector3(x, 0.87, 2.19), Vector3(0.66, 0.055, 0.05), lamp)
		car.block(Vector3(x, 0.81, -2.19), Vector3(0.65, 0.08, 0.05), car.mat(Color("c6f3ff"), 0, true))
		car.block(Vector3(x, 1.01, 1.76), Vector3(0.08, 0.32, 0.12), dark)
		var exhaust := MeshInstance3D.new()
		var pipe := TorusMesh.new()
		pipe.inner_radius = 0.08
		pipe.outer_radius = 0.13
		pipe.rings = 12
		pipe.ring_segments = 6
		exhaust.mesh = pipe
		exhaust.material_override = car.mat(Color("78818c"), 0.9)
		car.body.add_child(exhaust)
		exhaust.position = Vector3(x, 0.47, 2.30)
		exhaust.rotation.x = PI / 2
		var flame := MeshInstance3D.new()
		var plume := CylinderMesh.new()
		plume.top_radius = 0.015
		plume.bottom_radius = 0.18
		plume.height = 1.2
		plume.radial_segments = 12
		plume.cap_top = false
		plume.cap_bottom = false
		flame.mesh = plume
		var plume_material := ShaderMaterial.new()
		plume_material.shader = preload("res://shaders/nitro_flame.gdshader")
		flame.material_override = plume_material
		car.body.add_child(flame)
		flame.position = Vector3(x, 0.47, 2.78)
		flame.rotation.x = PI / 2
		car.nitro_flames.append(flame)
		flame.visible = false
		var glow := MeshInstance3D.new()
		var glow_mesh := preload("res://scripts/rendering/render_resources.gd").quad(Vector2(0.55, 0.55))
		glow.mesh = glow_mesh
		var glow_material := ShaderMaterial.new()
		glow_material.shader = preload("res://shaders/nitro_glow.gdshader")
		glow.material_override = glow_material
		car.body.add_child(glow)
		glow.position = Vector3(x, 0.47, 2.38)
		glow.visible = false
		car.nitro_glows.append(glow)
	car.block(Vector3(0, 0.895, 1.36), Vector3(1.6, 0.035, 1.25), dark)
	for i in range(6):
		car.block(Vector3(0, 0.925, 0.90 + i * 0.135), Vector3(1.48, 0.035, 0.065), dark)
	for side in [-1, 1]:
		car.block(Vector3(side * 1.1, 1.02, -0.45), Vector3(0.24, 0.12, 0.32), shell)
	car.block(Vector3(0, 1.17, 1.8), Vector3(2.2, 0.08, 0.36), dark)

	car.add_headlight(Vector3(0, 0.84, -2.02))
