extends RefCounted
const Catalog = preload("res://models/model_catalog.gd")
const SceneSource = preload("res://models/shared/scene_source.gd")


static func definition(id: String) -> Resource:
	var item: Resource = Catalog.find("vehicles", id)
	return item if item != null else Catalog.find("vehicles", "sport")


static func build(car: Node3D, item: Resource) -> void:
	if not item.builder_path.is_empty():
		load(item.builder_path).build(car)
		return
	var model: Node3D = SceneSource.instantiate_static(item.scene_path)
	car.body.add_child(model)
	# 휠이 없는 차체 전용 GLB에는 공통 휠을 사용한다. 명시한 팩만 자체 휠을 연결한다.
	if item.parameters.get("scene_wheels", false):
		for wheel_name in ["wheel_fl", "wheel_rl", "wheel_fr", "wheel_rr"]:
			var wheel := model.find_child(wheel_name, true, false) as MeshInstance3D
			assert(wheel != null, "차량 휠 연결점 누락: " + wheel_name)
			wheel.reparent(car.body, true)
			car.wheels.append(wheel)
	car.add_headlight(item.parameters.get("headlight_position", Vector3(0, .9, -2)))
	for position in item.parameters.get("exhaust_positions", []):
		car.add_boost_jet(position, .18)
