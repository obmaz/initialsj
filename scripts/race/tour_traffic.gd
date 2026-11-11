extends "res://scripts/physics/world_car.gd"
# 순위·랩과 분리된 일반 교통 차량. 보이면 출발하고 실제 차체로 계속 달린다.
const RaceState = preload("res://scripts/race/race_state.gd")
var feature_record: Dictionary
var road: Node3D
var distance := 0.0
var lane := 0.0
var activated := false
var cruise_speed := 18.0
var visual: Node3D
var clock: Node


func _ready() -> void:
	clock = road
	while clock != null and not clock.is_in_group("tour_traffic_clock"):
		clock = clock.get_parent()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(road) or not road.visible:
		return
	var camera := get_viewport().get_camera_3d()
	if not activated:
		if (
			camera == null
			or camera.global_position.distance_to(global_position) > 230
			or not camera.is_position_in_frustum(global_position)
		):
			return
		activated = true
	if is_instance_valid(clock) and clock.state != RaceState.RACING:
		return
	var closest: float = road.curve.get_closest_offset(feet_position())
	# 높이와 횡방향은 계측에만 사용한다. 차체를 곡선으로 순간 이동시키지 않는다.
	distance = closest
	if not feature_record.is_empty():
		feature_record.distance = distance
	if distance > road.length - 20:
		if not feature_record.is_empty():
			feature_record.distance = road.length + 1000
		visual.queue_free()
		queue_free()
		return
	var forward := forward_direction()
	var right := global_basis.x
	var look := 24.0
	var aim: Vector3 = road.point(distance + look, lane) - feet_position()
	var angle := atan2(aim.dot(right), aim.dot(forward))
	var wheel := (.46 + 7.0 * .007) / (1 + velocity.length() * .035) * steering_scale(velocity.length())
	var target := maxf(cruise_speed, velocity.dot(forward) - delta * 2)
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + forward * 18, 4, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		target = maxf(4, velocity.length() - delta * 12)
	advance(
		delta,
		clampf(atan(5.4 * sin(angle) / look) / wheel, -1, 1),
		move_toward(velocity.dot(forward), target, delta * 5),
		false
	)
	visual.global_transform = visual_frame(visual.ride_offset)
	visual.animate(steering, false, false, delta)
	visual.road_speed = velocity.length()
	visual.set_detail(camera.global_position.distance_to(global_position) if camera != null else 0)


func receive_traffic_push(impulse: Vector3) -> void:
	activated = true
	super.receive_traffic_push(impulse)
