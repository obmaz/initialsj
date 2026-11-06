extends CharacterBody3D
# World-space arcade motor. Track progress is telemetry owned by the race;
# this controller knows only its chassis, input and real physics contacts.
const CornerResistance = preload("res://scripts/corner_resistance.gd")
const SUPPORT_HEIGHT := 0.65
const GRAVITY := 24.0
const GROUND_LAYER := 1
const MAX_CONTACTS := 5
const MAX_STEP_HEIGHT := 0.22
var specification: Dictionary = {}
var grounded := false
var surface_normal := Vector3.UP
var ground_height := 0.0
var slip_angle := 0.0
var steering := 0.0
var yaw_rate := 0.0
var last_contacts: Array[Dictionary] = []
var corner_demand := 0.0
var corner_grip := 14.5
var last_corner_loss := 0.0
var contact_shape: CollisionShape3D

func _init() -> void:
	collision_layer = 4
	collision_mask = 7
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	contact_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1,1.3,4.3)
	contact_shape.shape = box
	add_child(contact_shape)

func configure(spec: Dictionary) -> void:
	specification = spec
	corner_grip = float(specification.get("grip",14.5))

func reset_pose(feet: Vector3, forward: Vector3, up: Vector3 = Vector3.UP) -> void:
	surface_normal = up.normalized()
	var tangent := forward.slide(surface_normal).normalized()
	if tangent.length_squared() < 0.5: tangent = Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(tangent,surface_normal),feet+surface_normal*SUPPORT_HEIGHT)
	velocity = Vector3.ZERO
	steering = 0
	yaw_rate = 0
	slip_angle = 0
	grounded = false
	ground_height = feet.y
	corner_demand = 0
	last_corner_loss = 0
	last_contacts.clear()
	reset_physics_interpolation()

func feet_position() -> Vector3:
	return global_position-global_basis.y*SUPPORT_HEIGHT

func forward_direction() -> Vector3:
	return -global_basis.z.normalized()

func _support() -> Dictionary:
	if not is_inside_tree(): return {}
	var world := get_world_3d().direct_space_state
	var points: Array[Vector3] = []
	var normal := Vector3.ZERO
	# A centre probe plus axle probes prevent one tyre beside a curb from
	# changing the entire chassis plane. Rays never see cars or tunnel walls.
	for offset in [Vector3.ZERO,Vector3(0,0,-1.3),Vector3(0,0,1.3),Vector3(-0.65,0,0),Vector3(0.65,0,0)]:
		var origin: Vector3 = global_position+global_basis*offset+Vector3.UP*0.35
		var query := PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*1.9,GROUND_LAYER,[get_rid()])
		var hit := world.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.4: continue
		points.append(hit.position)
		normal += hit.normal
	if points.is_empty(): return {}
	var at := Vector3.ZERO
	for point in points: at += point
	at /= points.size()
	normal = normal.normalized()
	var separation := (global_position-at).dot(normal)
	if separation > SUPPORT_HEIGHT+0.22 or separation < -0.6: return {}
	return {"position":at,"normal":normal,"gap":separation-SUPPORT_HEIGHT}

func _step_over(motion: Vector3, collider: Object, normal: Vector3) -> bool:
	# A tyre-sized edge in the ground mesh must not behave like a guardrail.
	# All three sweeps use the real chassis; no course height is consulted.
	if not collider is CollisionObject3D or not collider.get_collision_layer_value(1) or absf(normal.y) > 0.35: return false
	var lift := Vector3.UP*MAX_STEP_HEIGHT
	if test_move(global_transform,lift,null,0.012,false): return false
	var raised := global_transform
	raised.origin += lift
	if test_move(raised,motion,null,0.012,true): return false
	var destination := raised
	destination.origin += motion
	var landing := KinematicCollision3D.new()
	var drop := Vector3.DOWN*(MAX_STEP_HEIGHT+0.12)
	if not test_move(destination,drop,landing,0.012,true): return false
	var floor_normal := landing.get_normal()
	var floor_body := landing.get_collider()
	if floor_normal.y < 0.4 or not floor_body is CollisionObject3D or not floor_body.get_collision_layer_value(1): return false
	var rise := (destination.origin+landing.get_travel()-global_position).y
	if rise < -0.08 or rise > MAX_STEP_HEIGHT+0.015: return false
	move_and_collide(lift,false,0.012,false)
	move_and_collide(motion,false,0.012,false)
	move_and_collide(drop,false,0.012,true)
	surface_normal = surface_normal.lerp(floor_normal,0.6).normalized()
	ground_height = landing.get_position().y
	grounded = true
	velocity = velocity.slide(floor_normal)
	return true

func advance(delta: float, axis: float, target_speed: float, drifting: bool, grip_factor: float = 1.0) -> Array[Dictionary]:
	last_contacts.clear()
	corner_demand = 0
	last_corner_loss = 0
	if delta <= 0 or not is_inside_tree(): return last_contacts
	target_speed = clampf(target_speed,-12,maxf(float(specification.get("overdrive_speed",112))+10,float(specification.get("max_speed",80))+24))
	var support := _support()
	grounded = not support.is_empty() and velocity.dot(support.normal) <= 2.0
	if grounded:
		surface_normal = surface_normal.lerp(support.normal,1-exp(-delta*18)).normalized()
		ground_height = support.position.y
	var speed := velocity.slide(surface_normal).length()
	var input_rate: float = float(specification.get("steer_rate",7.0))
	steering = move_toward(steering,clampf(axis,-1,1),delta*input_rate)
	var handling: float = float(specification.get("handling",7.0))
	var wheel_angle := steering*(0.46+handling*0.007)/(1+speed*0.035)
	var signed_speed := velocity.dot(forward_direction())
	var desired_rate := -signed_speed*tan(wheel_angle)/2.7
	var max_rate := (1.20 if drifting else 0.88)*lerpf(0.82,1.12,handling/10.0)
	desired_rate = clampf(desired_rate,-max_rate,max_rate)
	if not grounded: desired_rate *= 0.22
	yaw_rate = move_toward(yaw_rate,desired_rate,delta*(5.5 if grounded else 1.2))
	var forward := forward_direction().rotated(surface_normal,yaw_rate*delta).slide(surface_normal).normalized()
	if forward.length_squared() < 0.5: forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward,surface_normal)
	var right := global_basis.x.normalized()
	if grounded:
		var lateral := velocity.dot(right)
		var grip: float = float(specification.get("drift_grip" if drifting else "grip",20.0))*clampf(grip_factor,0.12,1.5)
		lateral = move_toward(lateral,0,grip*delta)
		var planar: Vector3 = forward*target_speed+right*lateral
		# Steering must not create kinetic energy from the retained lateral speed.
		if planar.length() > absf(target_speed): planar = planar.limit_length(absf(target_speed))
		corner_demand = speed*absf(yaw_rate)
		var bank_assist := (Vector3.DOWN*9.81).dot(right)*-signf(yaw_rate)
		corner_grip = maxf(3.0,grip+bank_assist)
		var actual_slip := atan2(absf(planar.dot(right)),maxf(absf(planar.dot(forward)),0.01))
		last_corner_loss = CornerResistance.loss_rate(speed,corner_demand,corner_grip,actual_slip,drifting)
		planar = planar.move_toward(Vector3.ZERO,last_corner_loss*delta)
		velocity = planar-surface_normal*2.0
	else:
		# No road heading, throttle snap or lateral reset during a jump.
		velocity.y -= GRAVITY*delta
	var remaining := velocity*delta
	var can_step := grounded
	for pass_index in range(MAX_CONTACTS):
		if remaining.length_squared() < 0.0000001: break
		var before := velocity
		var collision := move_and_collide(remaining,false,0.012,true)
		if collision == null: break
		var normal := collision.get_normal()
		var collider := collision.get_collider()
		var is_floor: bool = normal.y > 0.4 and collider is CollisionObject3D and collider.get_collision_layer_value(1)
		if not is_floor and can_step and _step_over(collision.get_remainder(),collider,normal):
			remaining = Vector3.ZERO
			break
		if is_floor:
			grounded = true
			surface_normal = surface_normal.lerp(normal,0.6).normalized()
			ground_height = collision.get_position().y
			velocity = velocity.slide(normal)
		else:
			var closing := maxf(0,-before.dot(normal))
			if closing > 0.2:
				last_contacts.append({"normal":normal,"point":collision.get_position(),"collider":collider,"speed":closing})
				var tangent := velocity.slide(normal)
				velocity = tangent*0.86+normal*minf(closing*0.10,3.5)
			else: velocity = velocity.slide(normal)
		remaining = collision.get_remainder().slide(normal)
		if not is_floor: remaining *= 0.86
	if grounded:
		# Physical floor adhesion is short and uses the collider, never a spline.
		var probe := move_and_collide(-surface_normal*0.12,true,0.01)
		if probe != null and probe.get_normal().y > 0.4:
			move_and_collide(-surface_normal*0.12,false,0.01)
	var planar_velocity := velocity.slide(surface_normal)
	if planar_velocity.length() > 1:
		slip_angle = atan2(-planar_velocity.normalized().dot(right),absf(planar_velocity.normalized().dot(forward)))
	else: slip_angle = 0
	return last_contacts
