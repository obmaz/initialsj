extends Node3D
# 기존 GLB 차체만 재사용한다. 물리 차체·광원·오디오·입자는 만들지 않는다.
var car: Node3D
var vehicle_index := -1


func prepare(race: Node3D) -> void:
	visible = false
	if not race.show_ghost or race.personal_run.reference.is_empty():
		return
	if vehicle_index == race.selected_vehicle and is_instance_valid(car):
		return
	if is_instance_valid(car):
		car.free()
	vehicle_index = race.selected_vehicle
	car = preload("res://scripts/vehicles/vehicle_factory.gd").create(vehicle_index)
	car.traffic = true
	add_child(car)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(.1, .85, 1, .25)
	for node in car.find_children("*", "", true, false):
		if node is GeometryInstance3D:
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif node is Light3D:
			node.visible = false


func update(race: Node3D) -> void:
	visible = false
	if not race.show_ghost or race.state != race.RaceState.RACING or not is_instance_valid(car):
		return
	if race.mode == "tour" and not race.personal_run.matches(race.track.history):
		return
	var pose: Variant = race.personal_run.reference_pose(race.elapsed)
	if pose == null:
		return
	var distance: float = pose.origin.distance_to(race.player.global_position)
	if distance < 4 or distance > 150:
		return
	car.global_transform = pose
	visible = true
