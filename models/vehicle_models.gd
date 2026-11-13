extends RefCounted
const Catalog = preload("res://models/model_catalog.gd")
const SceneSource = preload("res://models/shared/scene_source.gd")


static func definition(id: String) -> Resource:
	var item: Resource = Catalog.find("vehicles", id)
	return item if item != null else Catalog.find("vehicles", "sport")


# 형상·휠 피벗·가동 부품은 GLB, 재질과 연결점은 모델 씬·정의가 소유한다.
static func build(car: Node3D, item: Resource) -> void:
	var model := SceneSource.instantiate_static(item.scene_path)
	var material: ShaderMaterial = car.paint_material()
	car.body.add_child(model)
	var meshes := SceneSource.collect_meshes(model)
	var split := meshes.any(func(node): return node.name == "PaintShell")
	var source_texture: Texture2D
	if item.parameters.get("imported_texture", false):
		var shell: MeshInstance3D = meshes.filter(func(node): return node.name == "PaintShell")[0]
		var source: StandardMaterial3D = shell.mesh.surface_get_material(0)
		source_texture = source.albedo_texture
		car.body.set_meta("source_texture", source_texture)
	for node in meshes:
		if str(node.name).begins_with("Open"):
			var variants: Dictionary = car.get_meta("open_top_variants", {})
			variants[str(node.name)] = {"mesh": node.mesh, "transform": node.transform}
			car.set_meta("open_top_variants", variants)
			continue
		# 직렬화된 투어 교통 차량은 기존 BodyShell 전체 메시를 계속 참조한다.
		if (
			split
			and (
				(not car.traffic and node.name == "BodyShell")
				or (car.traffic and node.name in ["TrimShell", "PaintShell"])
			)
		):
			continue
		node.reparent(car.body, true)
		if car.traffic and node.name == "BodyShell":
			node.visible = true
		if node.name == "PaintShell" or (source_texture != null and node.name == "TrimShell"):
			node.material_override = preload("res://scripts/vehicles/vehicle_customization.gd").paint_material(
				car.paint, source_texture
			)
		elif str(node.name).begins_with("wheel_"):
			if source_texture == null:
				node.material_override = car.shared_body_material()
		elif str(node.name).begins_with("BrakeLights"):
			var brake := node.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			node.material_override = brake
			car.brake_lights.append(brake)
		else:
			node.material_override = material
		if node.name == "ActiveRearAero":
			if car.traffic:
				continue
			car.active_aero = node
			car.aero_rest = node.transform
			car.aero_drop = item.parameters.aero_drop
			car.aero_pitch = item.parameters.aero_pitch
	for wheel_name in ["wheel_fl", "wheel_rl", "wheel_fr", "wheel_rr"]:
		var wheel := car.body.get_node(NodePath(wheel_name)) as MeshInstance3D
		assert(wheel != null, "GLB 휠 피벗 누락: " + wheel_name)
		car.wheels.append(wheel)
	model.free()
	if item.parameters.has("aero_mount"):
		car.aero_rest.origin = item.parameters.aero_mount
	for entry in item.parameters.get("labels", []):
		var label := Label3D.new()
		for key in entry:
			label.set(key, entry[key])
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.body.add_child(label)
	car.add_headlight(item.parameters.headlight_position)
	for jet in item.parameters.exhausts:
		car.add_boost_jet(jet.position, jet.radius)
	if car.traffic:
		var wheels := MultiMesh.new()
		wheels.transform_format = MultiMesh.TRANSFORM_3D
		wheels.mesh = car.wheels[0].mesh
		wheels.instance_count = 4
		for i in range(4):
			wheels.set_instance_transform(i, car.wheels[i].transform)
		car.traffic_wheels = MultiMeshInstance3D.new()
		car.traffic_wheels.multimesh = wheels
		car.traffic_wheels.material_override = car.shared_body_material()
		car.traffic_wheels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.body.add_child(car.traffic_wheels)
