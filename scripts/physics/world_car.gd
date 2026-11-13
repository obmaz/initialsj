extends CharacterBody3D
# 월드 좌표의 실제 차체·접지·접촉을 처리한다. 도로 진행도·순위는 경기 계측이 소유한다.
const CornerResistance = preload("res://scripts/physics/corner_resistance.gd")
const SUPPORT_HEIGHT := 0.65
const Crash = preload("res://scripts/physics/crash_state.gd")
const GROUND_LAYER := 1
const DEFAULT_COLLISION_MASK := 47
const PROTECTED_COLLISION_MASK := 35
const MAX_CONTACTS := 5
const MAX_STEP_HEIGHT := 0.22
# Grip-limited steering: ordinary steering cannot exceed this many times the
# tyre grip in lateral acceleration, so a fast tight corner needs braking or a
# drift. Drifting uses the (higher) drift grip with the same factor.
const Tuning = preload("res://scripts/physics/drive_tuning.gd")
const GRAVITY := Tuning.WORLD_GRAVITY
const LATERAL_GRIP_FACTOR := Tuning.LATERAL_GRIP_FACTOR
# Asking for more turn than the grip allows slides the front tyres: they scrub
# speed (understeer) instead of turning the car.
const UNDERSTEER_SCRUB := Tuning.UNDERSTEER_SCRUB
# 장벽 반동은 접근 속도에 비례한다. 비행은 Crash의 속도·진입각 조건을 모두 통과해야 한다.
const BARRIER_REBOUND := 0.46
const BARRIER_REBOUND_MAX := 30.0
const BARRIER_HOP_FROM := 14.0
const REALIGN_TIME := Tuning.REALIGN_TIME
const REALIGN_RATE := 7.0
const REALIGN_MAX_ERROR := 1.3
const GLIDE_REBOUND := Tuning.GLIDE_REBOUND
const GLIDE_REBOUND_MAX := Tuning.GLIDE_REBOUND_MAX
var rescue_floor: Dictionary = {}
var rescue_floor_used := false
var flight_time := 0.0
var specification: Dictionary = {}
var grounded := false
var surface_normal := Vector3.UP
var ground_height := 0.0
var slip_angle := 0.0
var steering := 0.0
var yaw_rate := 0.0
# Direction of the road under the car (set by the race) and how long after a rail hit the
# nose is eased back toward it.
var road_heading := Vector3.ZERO
var realign_time := 0.0
var rail_escape := Vector3.ZERO
var last_contacts: Array[Dictionary] = []
var corner_demand := 0.0
var corner_grip := 14.5
var last_corner_loss := 0.0
var contact_shape: CollisionShape3D
# CPU cars settle onto the floor every other tick: one sweep less per car per frame.
var cheap_adhesion := false
# 플레이어는 모든 코스에서 같은 미끄러짐 진입·복귀를 사용한다.
var coast_profile := false
var coast_slide := 0.0
var coast_angle := 0.0
var coast_direction := 0.0


func _init() -> void:
	collision_layer = 4
	collision_mask = DEFAULT_COLLISION_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	contact_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 1.3, 4.3)
	contact_shape.shape = box
	add_child(contact_shape)


static func steering_scale(speed: float) -> float:
	# Keep parking/reverse responsive while giving fast touch inputs more margin.
	return lerpf(1.0, 0.80, smoothstep(25.0, 85.0, absf(speed)))


func configure(spec: Dictionary) -> void:
	specification = spec
	corner_grip = float(specification.get("grip", 14.5))


func reset_pose(feet: Vector3, forward: Vector3, up: Vector3 = Vector3.UP) -> void:
	surface_normal = up.normalized()
	var tangent := forward.slide(surface_normal).normalized()
	if tangent.length_squared() < 0.5:
		tangent = Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(tangent, surface_normal), feet + surface_normal * SUPPORT_HEIGHT)
	velocity = Vector3.ZERO
	flight_time = 0
	steering = 0
	yaw_rate = 0
	# 충돌 보정의 방향·남은 시간이 재시작이나 복구 후 새 출발 방향을 꺾지 않게 한다.
	road_heading = Vector3.ZERO
	rail_escape = Vector3.ZERO
	realign_time = 0
	slip_angle = 0
	coast_slide = 0
	coast_angle = 0
	coast_direction = 0
	grounded = false
	ground_height = feet.y
	corner_demand = 0
	last_corner_loss = 0
	last_contacts.clear()
	reset_physics_interpolation()


func feet_position() -> Vector3:
	return global_position - global_basis.y * SUPPORT_HEIGHT


func visual_frame(ride_offset: float) -> Transform3D:
	# 모델 원점은 물리 상자의 중심이 아니라 타이어 접지면을 기준으로 한다.
	return Transform3D(global_basis, feet_position() - surface_normal * ride_offset)


# After a rail hit the nose is eased toward the road direction, fading out with the timer.
# Only part of the angle is removed, so a hard hit still leaves the car visibly turned.
func realigned(forward: Vector3, delta: float) -> Vector3:
	var road := road_heading.slide(surface_normal).normalized()
	if rail_escape.length_squared() > .5:
		var blend := smoothstep(.45, .8, realign_time)
		road = road.lerp(rail_escape, blend).normalized()
	if road.length_squared() < 0.5 or (forward.dot(road) < 0 and rail_escape.length_squared() < .5):
		return forward
	var error := forward.signed_angle_to(road, surface_normal)
	if absf(error) > REALIGN_MAX_ERROR:
		error = signf(error) * REALIGN_MAX_ERROR
	var follow := (
		1 - exp(-delta * 12)
		if rail_escape.length_squared() > .5
		else clampf(delta * REALIGN_RATE * (realign_time / REALIGN_TIME + 0.3), 0, 0.6)
	)
	var step := clampf(error * follow, -delta * 2.8, delta * 2.8)
	return forward.rotated(surface_normal, step).normalized()


# Yaw the upright chassis toward a horizontal direction (used while a crash throws the car).
func turn_toward(direction: Vector3, rate: float, delta: float) -> void:
	var flat := Vector3(direction.x, 0, direction.z)
	if flat.length_squared() < 25:
		return
	var forward := forward_direction()
	forward.y = 0
	if forward.length_squared() < 0.01:
		return
	var error := forward.normalized().signed_angle_to(flat.normalized(), Vector3.UP)
	yaw_rate = 0
	global_basis = Basis(Vector3.UP, error * clampf(rate * delta, 0, 1)) * global_basis


func forward_direction() -> Vector3:
	return -global_basis.z.normalized()


func _support() -> Dictionary:
	if not is_inside_tree():
		return {}
	var world := get_world_3d().direct_space_state
	var points: Array[Vector3] = []
	var normal := Vector3.ZERO
	# A centre probe plus axle probes prevent one tyre beside a curb from
	# changing the entire chassis plane. Rays never see cars or tunnel walls.
	for offset in [Vector3.ZERO, Vector3(0, 0, -1.3), Vector3(0, 0, 1.3), Vector3(-0.65, 0, 0), Vector3(0.65, 0, 0)]:
		var origin: Vector3 = global_position + global_basis * offset + Vector3.UP * 0.35
		var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * 1.9, GROUND_LAYER, [get_rid()])
		var hit := world.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.4:
			continue
		points.append(hit.position)
		normal += hit.normal
	if points.is_empty():
		if not rescue_floor.is_empty():
			var plane: Vector3 = rescue_floor.position
			var up: Vector3 = rescue_floor.normal
			var gap := (global_position - plane).dot(up) - SUPPORT_HEIGHT
			if gap < .3 and gap > -2:
				rescue_floor_used = true
				return {"position": plane, "normal": up, "gap": gap, "rescue": true}
		return {}
	var at := Vector3.ZERO
	for point in points:
		at += point
	at /= points.size()
	normal = normal.normalized()
	var separation := (global_position - at).dot(normal)
	if separation > SUPPORT_HEIGHT + 0.22 or separation < -0.6:
		return {}
	return {"position": at, "normal": normal, "gap": separation - SUPPORT_HEIGHT}


func _step_over(motion: Vector3, collider: Object, normal: Vector3) -> bool:
	# A tyre-sized edge in the ground mesh must not behave like a guardrail.
	# All three sweeps use the real chassis; no course height is consulted.
	if not collider is CollisionObject3D or not collider.get_collision_layer_value(1) or absf(normal.y) > 0.35:
		return false
	var lift := Vector3.UP * MAX_STEP_HEIGHT
	if test_move(global_transform, lift, null, 0.012, false):
		return false
	var raised := global_transform
	raised.origin += lift
	if test_move(raised, motion, null, 0.012, true):
		return false
	var destination := raised
	destination.origin += motion
	var landing := KinematicCollision3D.new()
	var drop := Vector3.DOWN * (MAX_STEP_HEIGHT + 0.12)
	if not test_move(destination, drop, landing, 0.012, true):
		return false
	var floor_normal := landing.get_normal()
	var floor_body := landing.get_collider()
	if floor_normal.y < 0.4 or not floor_body is CollisionObject3D or not floor_body.get_collision_layer_value(1):
		return false
	var rise := (destination.origin + landing.get_travel() - global_position).y
	if rise < -0.08 or rise > MAX_STEP_HEIGHT + 0.015:
		return false
	move_and_collide(lift, false, 0.012, false)
	move_and_collide(motion, false, 0.012, false)
	move_and_collide(drop, false, 0.012, true)
	surface_normal = surface_normal.lerp(floor_normal, 0.6).normalized()
	ground_height = landing.get_position().y
	grounded = true
	velocity = velocity.slide(floor_normal)
	return true


func advance(
	delta: float, axis: float, target_speed: float, drifting: bool, grip_factor: float = 1.0
) -> Array[Dictionary]:
	last_contacts.clear()
	corner_demand = 0
	last_corner_loss = 0
	if delta <= 0 or not is_inside_tree():
		return last_contacts
	target_speed = clampf(
		target_speed,
		-12,
		maxf(float(specification.get("overdrive_speed", 112)) + 10, float(specification.get("max_speed", 80)) + 24)
	)
	rescue_floor_used = false
	var support := _support()
	grounded = not support.is_empty() and velocity.dot(support.normal) <= 2.0
	if not grounded:
		flight_time += delta
		turn_toward(velocity, 8.0, delta)
	else:
		if flight_time > .1:
			turn_toward(velocity, 1.0 / delta, delta)
		flight_time = 0
	if grounded:
		surface_normal = surface_normal.lerp(support.normal, 1 - exp(-delta * 18)).normalized()
		ground_height = support.position.y
		if support.get("rescue", false):
			global_position += (
				support.normal * (SUPPORT_HEIGHT - (global_position - support.position).dot(support.normal))
			)
	var speed := velocity.slide(surface_normal).length()
	var high_speed_scale := steering_scale(speed)
	var input_rate: float = float(specification.get("steer_rate", 7.0)) * high_speed_scale
	steering = move_toward(steering, clampf(axis, -1, 1), delta * input_rate)
	var handling: float = float(specification.get("handling", 7.0))
	var wheel_angle := steering * (0.46 + handling * 0.007) / (1 + speed * 0.035) * high_speed_scale
	var signed_speed := velocity.dot(forward_direction())
	if coast_profile and drifting and coast_slide < 0.01:
		coast_direction = signf(steering)
	coast_slide = move_toward(coast_slide, 1.0 if drifting and coast_profile else 0.0, delta * 2.2)
	var desired_rate := -signed_speed * tan(wheel_angle) / 2.7
	if coast_profile:
		desired_rate -= steering * coast_slide * 0.16
	var max_rate := (1.20 if drifting else 0.88) * lerpf(0.82, 1.12, handling / 10.0) * high_speed_scale
	var tyre_grip: float = float(specification.get("drift_grip" if drifting else "grip", 14.5))
	max_rate = minf(max_rate, LATERAL_GRIP_FACTOR * tyre_grip / maxf(absf(signed_speed), 1.0))
	var understeer := 0.0
	if not drifting and absf(desired_rate) > max_rate:
		understeer = clampf((absf(desired_rate) - max_rate) / maxf(max_rate, 0.05), 0, 1)
	desired_rate = clampf(desired_rate, -max_rate, max_rate)
	if not grounded:
		desired_rate *= 0.22
	yaw_rate = move_toward(yaw_rate, desired_rate, delta * (5.5 * high_speed_scale if grounded else 1.2))
	var forward := forward_direction().rotated(surface_normal, yaw_rate * delta).slide(surface_normal).normalized()
	var coast_motion := Vector3.ZERO
	if coast_profile and speed > 20 and coast_slide > 0:
		# 입력은 진행 방향을 돌리고 차체는 그 방향과 일정한 슬립각을 유지합니다.
		# 노면 중심선에 붙이지 않으므로 조향·카운터와 실제 장벽 접촉은 계속 필요합니다.
		if absf(steering) > 0.04 and (coast_direction == 0 or absf(steering) > 0.35):
			coast_direction = signf(steering)
		coast_angle = move_toward(
			coast_angle, -coast_direction * (0.28 + 0.2 * absf(steering)) * coast_slide, delta * 0.9
		)
		coast_motion = velocity.slide(surface_normal).normalized().rotated(surface_normal, yaw_rate * delta)
		forward = coast_motion.rotated(surface_normal, coast_angle).normalized()
	if realign_time > 0:
		realign_time = maxf(0, realign_time - delta)
		if grounded and road_heading.length_squared() > 0.5:
			forward = realigned(forward, delta)
	if realign_time <= 0:
		rail_escape = Vector3.ZERO
	if forward.length_squared() < 0.5:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward, surface_normal)
	var right := global_basis.x.normalized()
	if grounded:
		var lateral := velocity.dot(right)
		var grip: float = (
			float(specification.get("drift_grip" if drifting else "grip", 20.0)) * clampf(grip_factor, 0.12, 1.5)
		)
		grip *= lerpf(1.0, 0.40, coast_slide)
		lateral = move_toward(lateral, 0, grip * delta)
		var planar: Vector3 = forward * target_speed + right * lateral
		if coast_motion.length_squared() > 0.5:
			planar = coast_motion * target_speed
		# Steering must not create kinetic energy from the retained lateral speed.
		if planar.length() > absf(target_speed):
			planar = planar.limit_length(absf(target_speed))
		corner_demand = speed * absf(yaw_rate)
		var bank_assist := (Vector3.DOWN * 9.81).dot(right) * -signf(yaw_rate)
		corner_grip = maxf(3.0, grip + bank_assist)
		var actual_slip := atan2(absf(planar.dot(right)), maxf(absf(planar.dot(forward)), 0.01))
		last_corner_loss = (
			CornerResistance.loss_rate(speed, corner_demand, corner_grip, actual_slip, drifting)
			+ understeer * tyre_grip * UNDERSTEER_SCRUB
		)
		last_corner_loss *= lerpf(1.0, 0.48, coast_slide)
		planar = planar.move_toward(Vector3.ZERO, last_corner_loss * delta)
		velocity = planar - surface_normal * (0.0 if rescue_floor_used else 2.0)
	else:
		# No road heading, throttle snap or lateral reset during a jump.
		velocity.y -= GRAVITY * delta
	var remaining := velocity * delta
	var can_step := grounded
	var vehicles_hit := {}
	for pass_index in range(MAX_CONTACTS):
		if remaining.length_squared() < 0.0000001:
			break
		var before := velocity
		var collision := move_and_collide(remaining, false, 0.012, true)
		if collision == null:
			break
		var normal := collision.get_normal()
		var collider := collision.get_collider()
		var is_floor: bool = normal.y > 0.4 and collider is CollisionObject3D and collider.get_collision_layer_value(1)
		if not is_floor and can_step and _step_over(collision.get_remainder(), collider, normal):
			remaining = Vector3.ZERO
			break
		if is_floor:
			grounded = velocity.dot(normal) <= 2.0
			surface_normal = surface_normal.lerp(normal, 0.6).normalized()
			ground_height = collision.get_position().y
			if velocity.dot(normal) < 0:
				velocity = velocity.slide(normal)
		else:
			if collider.has_method("receive_traffic_push"):
				if vehicles_hit.has(collider.get_instance_id()):
					break
				vehicles_hit[collider.get_instance_id()] = true
			var closing := maxf(0, -before.dot(normal))
			if collider.has_method("receive_traffic_push"):
				closing = maxf(0, -(before - collider.velocity).dot(normal))
			if closing > 0.2:
				var incoming_speed := before.slide(surface_normal).length()
				var barrier: bool = (
					collider is CollisionObject3D
					and collider.get_collision_layer_value(2)
					and not collider.get_collision_layer_value(1)
				)
				var rail_wall := barrier
				var road_lip: bool = (
					can_step
					and collider is CollisionObject3D
					and collider.get_collision_layer_value(1)
					and absf(normal.y) < .35
					and road_heading.length_squared() > .5
				)
				barrier = barrier or road_lip
				var severe: bool = (
					rail_wall
					and collision_layer != 16
					and closing >= 1.2
					and Crash.launches(incoming_speed, closing)
					and absf(normal.y) < 0.65
				)
				last_contacts.append(
					{
						"normal": normal,
						"point": collision.get_position(),
						"collider": collider,
						"speed": closing,
						"closing_speed": closing,
						"incoming_speed": incoming_speed,
						"barrier": barrier,
						"severe": severe,
						"severity": clampf(closing / 65.0, 0, 1)
					}
				)
				var tangent := velocity.slide(normal)
				if barrier:
					var hardness := clampf(closing / 45.0, 0, 1)
					if severe:
						rail_escape = Vector3.ZERO
						# 속도와 진입각이 모두 임계값을 넘는 충돌만 비행으로 넘긴다.
						velocity = (
							tangent * lerpf(0.80, 0.50, hardness)
							+ normal * clampf(closing * BARRIER_REBOUND, 2.0, BARRIER_REBOUND_MAX)
						)
						if closing > BARRIER_HOP_FROM:
							velocity.y += clampf((closing - BARRIER_HOP_FROM) * 0.09, 0, 3.0)
					else:
						# 비행하지 않는 접촉도 노면 방향으로 짧게 튕긴다. 수직 충격은 추가하지 않는다.
						var away := normal.slide(surface_normal).normalized()
						velocity = (
							tangent * Tuning.glide_keep(hardness)
							+ away * clampf(closing * GLIDE_REBOUND, 0.85, GLIDE_REBOUND_MAX)
						)
						var road := road_heading.slide(surface_normal).normalized()
						if road.length_squared() > .5:
							# 지주 앞면의 법선은 뒤쪽을 향할 수 있다. 접점의 도로 좌우 위치로 안쪽을 구한다.
							var road_right := road.cross(surface_normal).normalized()
							var side := (collision.get_position() - global_position).dot(road_right)
							var inward := -signf(side) * road_right if absf(side) > .2 else away
							var low_speed := smoothstep(18, 3, incoming_speed)
							var escape_slope := minf(lerpf(.08, .28, low_speed), 1.8 / maxf(incoming_speed, 1))
							rail_escape = (road + inward * escape_slope).normalized()
							move_and_collide(inward * lerpf(.12, .24, low_speed), false, .012)
							var pace := maxf(before.dot(road), incoming_speed * .65) * Tuning.glide_keep(hardness)
							velocity = rail_escape * pace + inward * clampf(closing * .12, .5, 1.8)
							yaw_rate = 0
							steering = 0
						realign_time = REALIGN_TIME
				elif collider.has_method("receive_debris_hit"):
					collider.receive_debris_hit()
					velocity = before * .88
					remaining = collision.get_remainder()
					continue
				elif collider.has_method("receive_traffic_push"):
					rail_escape = Vector3.ZERO
					var incoming := before.slide(surface_normal)
					var side := global_basis.x.slide(surface_normal).normalized()
					var side_sign := signf(normal.dot(side))
					if absf(side_sign) < .1:
						side_sign = -1.0 if get_instance_id() % 2 else 1.0
					var strength := clampf(closing / maxf(incoming.length(), 1), 0, 1)
					velocity = incoming * lerpf(.92, .58, strength) + side * side_sign * clampf(closing * .13, .5, 8)
					var push := (
						incoming.normalized() * minf(closing * .65, 28) - side * side_sign * clampf(closing * .16, 2, 7)
					)
					collider.receive_traffic_push(push)
					# 실제 스윕으로 상대에게 옆 공간을 만들고, 플레이어도 전진하며 비켜간다.
					collider.move_and_collide(push.normalized() * minf(.65, closing * delta), false, .012)
					realign_time = REALIGN_TIME
				else:
					velocity = tangent * 0.90 + normal * clampf(closing * 0.16, 0.8, 5.0)
				if can_step and not severe:
					velocity = velocity.slide(surface_normal)
			# Recovery contacts can repeat on adjacent rail triangles after the
			# impact. Preserve the normal impulse when already separating.
			elif velocity.dot(normal) < 0 and not collider.has_method("receive_traffic_push"):
				velocity = velocity.slide(normal)
		remaining = collision.get_remainder().slide(normal)
		if not is_floor:
			remaining *= 0.86
	if grounded and (not cheap_adhesion or (Engine.get_physics_frames() + get_instance_id()) % 2 == 0):
		# Physical floor adhesion is short and uses the collider, never a spline.
		var probe := move_and_collide(-surface_normal * 0.12, true, 0.01)
		if probe != null and probe.get_normal().y > 0.4:
			move_and_collide(-surface_normal * 0.12, false, 0.01)
	var planar_velocity := velocity.slide(surface_normal)
	if planar_velocity.length() > 1:
		slip_angle = atan2(-planar_velocity.normalized().dot(right), absf(planar_velocity.normalized().dot(forward)))
	else:
		slip_angle = 0
	return last_contacts


# 교통 차량과 CPU 차량 모두 실제 속도로 충격을 전달받는다.
func receive_traffic_push(impulse: Vector3) -> void:
	velocity += impulse.slide(surface_normal)
