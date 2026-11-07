extends RefCounted
const Car = preload("res://scripts/world_car.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const CornerResistance = preload("res://scripts/corner_resistance.gd")
const Report = preload("res://tests/report.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func box(parent: Node3D, size: Vector3, at: Vector3, layer: int, rotation: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 4
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	body.add_child(shape)
	parent.add_child(body)
	body.position = at
	body.rotation = rotation
	return body
func corner_trial(car: CharacterBody3D, spec: Dictionary, axis: float, drift: bool = false, gas: bool = true, frames: int = 720, initial_speed: float = -1.0) -> Dictionary:
	car.configure(spec)
	car.reset_pose(Vector3(400,0,400),Vector3.FORWARD)
	car.velocity = Vector3.FORWARD*(float(spec.max_speed) if initial_speed < 0 else initial_speed)
	var loss := 0.0
	for frame in range(frames):
		var speed: float = car.velocity.slide(car.surface_normal).length()
		var engine: float = CornerResistance.engine_factor(speed,float(spec.max_speed),car.corner_demand,car.corner_grip)
		var target: float = move_toward(speed,float(spec.max_speed),spec.accel*engine/60.0) if gas else maxf(0,speed-5.0/60)
		car.advance(1.0/60,axis,target,drift)
		loss = maxf(loss,car.last_corner_loss)
	return {"speed_mps":car.velocity.slide(car.surface_normal).length(),"peak_scrub_mps2":loss,"demand_mps2":car.corner_demand,"slip_radians":car.slip_angle}
func collision_trial(car: CharacterBody3D, feet: Vector3, forward: Vector3, speed: float) -> Dictionary:
	car.reset_pose(feet,forward)
	car.velocity = forward.normalized()*speed
	for frame in range(60):
		var contacts: Array = car.advance(1.0/60,0,speed,false)
		for hit in contacts:
			return {"layer":int(hit.collider.collision_layer),"barrier":hit.barrier,"severe":hit.severe,"severity":hit.severity,"closing_speed":hit.closing_speed,"incoming_speed":hit.incoming_speed,"rebound_mps":car.velocity.dot(hit.normal)}
	return {}
func steering_trial(car: CharacterBody3D, speed: float) -> Dictionary:
	car.reset_pose(Vector3(400,0,400),Vector3.FORWARD)
	car.velocity = Vector3.FORWARD*speed
	var first_input := 0.0
	for frame in range(24):
		car.advance(1.0/60,0.6,speed,false)
		if frame == 0: first_input = car.steering
	return {"yaw_rate":absf(car.yaw_rate),"heading_radians":absf(atan2(car.forward_direction().x,-car.forward_direction().z)),"first_input":first_input}
func run(tree: SceneTree) -> int:
	var scene := Node3D.new()
	tree.root.add_child(scene)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 4
	var mesh_shape := ConcavePolygonShape3D.new()
	mesh_shape.set_faces(PackedVector3Array([Vector3(-1500,0,-1500),Vector3(1500,0,-1500),Vector3(-1500,0,1500),Vector3(1500,0,-1500),Vector3(1500,0,1500),Vector3(-1500,0,1500)]))
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = mesh_shape
	ground.add_child(ground_shape)
	scene.add_child(ground)
	box(scene,Vector3(40,5,0.5),Vector3(0,2,-80),2)
	var slope := box(scene,Vector3(35,1,45),Vector3(70,6,75),1,Vector3(0,0,deg_to_rad(15)))
	box(scene,Vector3(20,0.12,20),Vector3(-140,0.06,-20),1)
	box(scene,Vector3(20,1.0,1),Vector3(-180,0.5,-20),1)
	box(scene,Vector3(20,0.12,20),Vector3(-110,0.06,-20),1)
	box(scene,Vector3(20,0.30,20),Vector3(-110,1.50,-20),2)
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	var ramp_shape := CollisionShape3D.new()
	var ramp_surface := ConcavePolygonShape3D.new()
	ramp_surface.set_faces(PackedVector3Array([Vector3(-68,0,20),Vector3(-68,0.75,4),Vector3(-52,0,20),Vector3(-52,0,20),Vector3(-68,0.75,4),Vector3(-52,0.75,4)]))
	ramp_shape.shape = ramp_surface
	ramp.add_child(ramp_shape)
	scene.add_child(ramp)
	var car := Car.new()
	car.configure(Catalog.spec(0))
	scene.add_child(car)
	await tree.physics_frame
	await tree.physics_frame
	car.reset_pose(Vector3.ZERO,Vector3.FORWARD)
	for frame in range(120): car.advance(1.0/60,0,30,false)
	check(car.feet_position().z < -58 and car.grounded,"A world car must travel over a real collider without any road/path object")
	check(absf(car.feet_position().y) < 0.12,"World car must rest on actual mesh height")
	car.reset_pose(Vector3(100,0,-30),Vector3.FORWARD)
	car.velocity = Vector3(0,0,-35)
	for frame in range(50): car.advance(1.0/60,0.35,35,false)
	var turned := car.forward_direction()
	check(turned.x > 0.4,"Positive steering must turn right in world space")
	for frame in range(60): car.advance(1.0/60,0,35,false)
	var released := car.forward_direction()
	for frame in range(40): car.advance(1.0/60,0,35,false)
	check(car.forward_direction().dot(released) > 0.999,"Releasing steering must retain the chosen heading instead of following a road centreline")
	car.reset_pose(Vector3(0,0,-55),Vector3.FORWARD)
	car.velocity = Vector3(0,0,-112)
	var contacts := 0
	for frame in range(20): contacts += car.advance(1.0/30,0,112,false).size()
	check(contacts > 0 and car.feet_position().z > -78,"High-speed physical sweeps must hit the actual wall without tunnelling")
	var head_on := collision_trial(car,Vector3(0,0,-65),Vector3.FORWARD,80)
	check(head_on.get("barrier",false) and head_on.get("severe",false) and head_on.get("closing_speed",0) > 70 and head_on.get("incoming_speed",0) > 70,"A severe real barrier impact must preserve its incoming/closing speed for the crash controller")
	check(head_on.get("rebound_mps",0) >= 10 and head_on.get("rebound_mps",100) <= 14.1,"A high-speed barrier collision must rebound visibly with bounded normal restitution")
	# Adjacent rail triangles can produce a second recovery contact after the
	# impact. An already-separating body must keep its outgoing normal impulse.
	car.reset_pose(Vector3(0,0,-77.63),Vector3.FORWARD)
	car.velocity = Vector3.BACK*10
	car.advance(1.0/60,0,-10,false)
	var recovery_rebound: float = car.velocity.z
	check(recovery_rebound > 9 and car.feet_position().z > -77.6,"A separating wall recovery contact must preserve the rebound instead of sliding its normal impulse away")
	car.reset_pose(Vector3(50,-0.02,0),Vector3.FORWARD)
	car.velocity = Vector3.UP*5
	car.advance(1.0/60,0,0,false)
	check(not car.grounded and car.velocity.y > 4 and car.feet_position().y > 0.05,"A separating floor recovery contact must preserve upward momentum and skip ground adhesion")
	var glance := collision_trial(car,Vector3(-10,0,-78.2),Vector3(80,0,-8).normalized(),80)
	check(glance.get("barrier",false) and not glance.get("severe",true) and glance.get("closing_speed",100) < 12,"A fast glancing guardrail scrape must not trigger a severe crash")
	var slow_wall := collision_trial(car,Vector3(0,0,-65),Vector3.FORWARD,35)
	check(slow_wall.get("barrier",false) and not slow_wall.get("severe",true),"A lower-speed head-on wall touch must rebound without launching the crash animation")
	var ground_edge := collision_trial(car,Vector3(-180,0,0),Vector3.FORWARD,80)
	check(ground_edge.get("layer",0) == 1 and not ground_edge.get("barrier",true) and not ground_edge.get("severe",true),"Even a fast ground-layer edge contact must never be classified as a guardrail crash")
	var opponent := Car.new()
	opponent.configure(Catalog.spec(0))
	scene.add_child(opponent)
	opponent.reset_pose(Vector3(250,0,-15),Vector3.FORWARD)
	await tree.physics_frame
	await tree.physics_frame
	var car_hit := collision_trial(car,Vector3(250,0,0),Vector3.FORWARD,80)
	check(car_hit.get("layer",0) == 4 and not car_hit.get("barrier",true) and not car_hit.get("severe",true) and car_hit.get("rebound_mps",0) > 10,"Actual car contacts must rebound while remaining distinct from severe barrier impacts")
	opponent.queue_free()
	await tree.process_frame
	var low_steering := steering_trial(car,20)
	var fast_steering := steering_trial(car,80)
	check(fast_steering.yaw_rate < low_steering.yaw_rate*0.88 and fast_steering.first_input < low_steering.first_input*0.88,"Fast touch steering must engage smoothly and turn less sharply than low-speed steering")
	check(low_steering.yaw_rate > 0.9 and fast_steering.yaw_rate > 0.65,"Steering must retain responsive low-speed control and enough high-speed corner authority")
	car.reset_pose(Vector3(100,12,100),Vector3.FORWARD)
	car.velocity = Vector3(10,3,0)
	for frame in range(30): car.advance(1.0/60,0,80,false)
	check(not car.grounded and car.feet_position().y > 8 and absf(car.velocity.x-10) < 0.01,"Air motion must retain world momentum and gravity instead of snapping to throttle or a lane")
	var air_x: float = car.feet_position().x
	for frame in range(120): car.advance(1.0/60,0,0,false)
	check(car.grounded and absf(car.feet_position().y) < 0.12,"Ballistic fall must land on the real floor")
	var top := slope.global_position+slope.global_basis.y*0.5
	car.reset_pose(top,Vector3.FORWARD,slope.global_basis.y)
	for frame in range(50): car.advance(1.0/60,0,0,false)
	var bank_alignment := car.surface_normal.dot(slope.global_basis.y)
	check(car.grounded and bank_alignment > 0.99,"Chassis roll must follow the actual banked collision surface")
	check(absf((car.feet_position()-top).dot(slope.global_basis.y)) < 0.12,"A banked car's tyres must stay at the real surface")
	car.reset_pose(Vector3(-100,0,80),Vector3.FORWARD)
	for frame in range(90): car.advance(1.0/60,0,-10,false)
	check(car.feet_position().z > 94,"Holding reverse must move a free world car backwards")
	car.reset_pose(Vector3(-100,0,80),Vector3.FORWARD)
	for frame in range(60): car.advance(1.0/60,0.4,-10,false)
	check(car.forward_direction().x < -0.15,"Reverse steering must change yaw in the opposite direction")
	car.reset_pose(Vector3(-140,0,0),Vector3.FORWARD)
	var curb_contacts := 0
	for frame in range(45): curb_contacts += car.advance(1.0/60,0,30,false).size()
	var curb_height: float = car.feet_position().y
	check(car.grounded and car.feet_position().z < -21 and curb_height > 0.1 and curb_contacts == 0,"A grounded tyre must climb a low physical ground edge without reporting a wall collision")
	car.reset_pose(Vector3(-180,0,0),Vector3.FORWARD)
	var ledge_contacts := 0
	for frame in range(60): ledge_contacts += car.advance(1.0/60,0,30,false).size()
	check(car.feet_position().z > -18 and ledge_contacts > 0,"Step handling must not climb a tall ledge even when the collider is on the ground layer")
	car.reset_pose(Vector3(-110,0,0),Vector3.FORWARD)
	var roof_contacts := 0
	for frame in range(60): roof_contacts += car.advance(1.0/60,0,30,false).size()
	check(car.feet_position().z > -9 and roof_contacts > 0,"A low edge must remain blocked if raising the chassis would collide with a real overhang")
	car.reset_pose(Vector3(-60,0,35),Vector3.FORWARD)
	var ramp_peak := 0.0
	var ramp_launch_speed := 0.0
	for frame in range(80):
		car.advance(1.0/60,0,65,false)
		ramp_peak = maxf(ramp_peak,car.feet_position().y)
		if not car.grounded and car.feet_position().z < 4:
			ramp_launch_speed = maxf(ramp_launch_speed,car.velocity.y)
	check(ramp_launch_speed > 1.5 and ramp_peak > 0.9,"A physical ramp must launch the car using slope momentum without an artificial jump impulse")
	check(car.grounded and absf(car.feet_position().y) < 0.12,"The ramp jump must land on the physical floor")
	var corners := []
	for choice in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		var spec := Catalog.spec(choice)
		var straight := corner_trial(car,spec,0)
		var mild := corner_trial(car,spec,0.065)
		var tight := corner_trial(car,spec,0.14)
		var drift := corner_trial(car,spec,0.14,true)
		check(absf(straight.speed_mps-float(spec.max_speed)) < 0.05 and straight.peak_scrub_mps2 == 0,"Straight driving must retain its configured top speed without tyre scrub")
		check(mild.speed_mps < straight.speed_mps-0.5 and mild.speed_mps > straight.speed_mps*0.88,"A sustained mild real turn must scrub speed while retaining at least 88% of cruise")
		check(tight.speed_mps < mild.speed_mps-3 and tight.speed_mps > straight.speed_mps*0.65,"A tight real turn must shed materially more speed without a hard corner speed clamp")
		check(drift.speed_mps > tight.speed_mps and drift.speed_mps < straight.speed_mps-0.2,"Drifting must preserve more momentum while retaining measurable corner scrub")
		corners.append({"vehicle":spec.id,"straight":straight,"mild":mild,"tight":tight,"drift":drift})
	var overspeed := corner_trial(car,Catalog.spec(0),0.065,false,true,60,87)
	check(overspeed.speed_mps < 72.5 and overspeed.speed_mps > 65,"An expired boost in a loaded corner must retain engine braking toward the normal cruise speed")
	car.configure(Catalog.spec(0))
	var bank_corner_grip := []
	for axis in [-0.3,0.3]:
		car.reset_pose(top,Vector3.FORWARD,slope.global_basis.y)
		car.velocity = Vector3.FORWARD*20
		for frame in range(20): car.advance(1.0/60,axis,20,false)
		bank_corner_grip.append(car.corner_grip)
	check(bank_corner_grip[0] > 15.5 and bank_corner_grip[1] < 13.5,"The real support bank must assist downhill turns and reduce grip for adverse uphill turns")
	car.configure(Catalog.spec(0))
	car.reset_pose(Vector3(400,0,400),Vector3.FORWARD)
	for frame in range(60): car.advance(1.0/60,1,0,false)
	check(car.last_corner_loss == 0 and car.velocity.slide(car.surface_normal).length() < 0.001,"Stationary steering must not invent cornering drag or motion")
	car.reset_pose(Vector3(400,20,400),Vector3.FORWARD)
	car.velocity = Vector3(30,0,-40)
	for frame in range(20): car.advance(1.0/60,0.8,80,true)
	check(not car.grounded and car.last_corner_loss == 0 and absf(Vector2(car.velocity.x,car.velocity.z).length()-50) < 0.001,"Airborne steering must preserve horizontal momentum and apply no tyre scrub")
	var throttle := corner_trial(car,Catalog.spec(0),0.14,false,true,180)
	var coast := corner_trial(car,Catalog.spec(0),0.14,false,false,180)
	check(throttle.speed_mps > coast.speed_mps+8,"Throttle must still counter corner drag compared with coasting through the same turn")
	var before_brake: float = car.velocity.length()
	for frame in range(30):
		var speed: float = car.velocity.slide(car.surface_normal).length()
		car.advance(1.0/60,0,maxf(0,speed-48.0/60),false)
	check(car.velocity.length() < before_brake-20,"Brake input must remain immediately effective after a loaded corner")
	# With lower launch force, allow three seconds to recover from heavy braking.
	for frame in range(180):
		var speed: float = car.velocity.slide(car.surface_normal).length()
		var engine: float = CornerResistance.engine_factor(speed,72,car.corner_demand,car.corner_grip)
		car.advance(1.0/60,0,minf(72,speed+float(Catalog.spec(0).accel)*engine/60),false)
	check(car.velocity.length() > 65,"Straightening the car and applying throttle must restore acceleration")
	check(CornerResistance.loss_rate(70,0,14.5,0.7,true) == 0,"Straight visual drift must not trigger corner resistance")
	# Other moving bodies are queried through the physics server. Let the real
	# physics tick flush their transforms between frames, as the game does.
	var pack: Array[CharacterBody3D] = []
	for index in range(8):
		var member := Car.new()
		member.configure(Catalog.spec(0))
		scene.add_child(member)
		member.reset_pose(Vector3(-182 if index%2 == 0 else -178,0,150-(index/2)*10),Vector3.FORWARD)
		pack.append(member)
	await tree.physics_frame
	await tree.physics_frame
	for frame in range(120):
		for member in pack: member.advance(1.0/60,0,50,false)
		await tree.physics_frame
	var pack_error := 0.0
	for index in range(pack.size()):
		var expected := 50.0-(index/2)*10
		pack_error = maxf(pack_error,absf(pack[index].feet_position().z-expected))
		check(pack[index].velocity.length() > 49 and pack[index].last_contacts.is_empty(),"An eight-car formation must keep moving without stale spawn-position collisions")
	check(pack_error < 0.05,"All eight cars must travel their world distance after physics-frame synchronization")
	FileAccess.open(Report.path("world-car-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"wall_contacts":contacts,"air_momentum_x_at_half_second":air_x,"bank_normal_alignment":bank_alignment,"eight_car_max_position_error":pack_error,"ramp_peak_height":ramp_peak,"ramp_launch_speed":ramp_launch_speed,"low_step_height":curb_height,"tall_ledge_contacts":ledge_contacts,"low_roof_contacts":roof_contacts,"corner_trials":corners,"corner_throttle_mps":throttle.speed_mps,"corner_coast_mps":coast.speed_mps,"overspeed_recovery_mps":overspeed.speed_mps,"bank_corner_grip":bank_corner_grip,"contact_trials":{"head_on":head_on,"recovery_rebound_mps":recovery_rebound,"glancing":glance,"slow_wall":slow_wall,"ground_edge":ground_edge,"car":car_hit},"steering_trials":{"low":low_steering,"fast":fast_steering}},"\t")+"\n")
	scene.queue_free()
	await tree.process_frame
	print("World car / physical sweep / free heading / airborne momentum / banking / reverse / ramp / low steps / corner scrub / rebound / mobile steering / eight-car formation: ","PASS" if failures == 0 else "FAIL")
	return failures
