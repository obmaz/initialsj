extends RefCounted
const Car = preload("res://scripts/world_car.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
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
func run(tree: SceneTree) -> int:
	var scene := Node3D.new()
	tree.root.add_child(scene)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 4
	var mesh_shape := ConcavePolygonShape3D.new()
	mesh_shape.set_faces(PackedVector3Array([Vector3(-250,0,-250),Vector3(250,0,-250),Vector3(-250,0,250),Vector3(250,0,-250),Vector3(250,0,250),Vector3(-250,0,250)]))
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
	FileAccess.open(Report.path("world-car-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"wall_contacts":contacts,"air_momentum_x_at_half_second":air_x,"bank_normal_alignment":bank_alignment,"eight_car_max_position_error":pack_error,"ramp_peak_height":ramp_peak,"ramp_launch_speed":ramp_launch_speed,"low_step_height":curb_height,"tall_ledge_contacts":ledge_contacts,"low_roof_contacts":roof_contacts},"\t")+"\n")
	scene.queue_free()
	await tree.process_frame
	print("World car / physical sweep / free heading / airborne momentum / banking / reverse / ramp / low steps / eight-car formation: ","PASS" if failures == 0 else "FAIL")
	return failures
