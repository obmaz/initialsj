extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",4)
	var hazard: Node3D = race.track.active.rockfall
	var section: Node3D = race.track.active
	var sites := {}
	for seed_value in range(30):
		hazard.reset_effect(seed_value)
		hazard.plan_lap(1)
		hazard.plan_lap(2)
		check(hazard.plans.size() == 3,"모든 주회에 다른 낙석 지점이 있어야 한다")
		for i in range(hazard.plans.size()):
			var d: float = hazard.plans[i].distance
			sites[int(d)] = true
			check(d >= 1100 and d <= section.length-280,"낙석은 다리와 결승선 밖 협곡 구간에 놓아야 한다")
			for j in range(i): check(absf(d-float(hazard.plans[j].distance)) >= 400,"이전 낙석과400m 이상 떨어져야 한다")
			for feature in section.features: check(absf(d-float(feature.distance)) >= float(feature.length)*.5+90,"점프·부스터 구간을 낙석으로 막으면 안 된다")
	check(sites.size() > 35,"재시작마다 넓은 후보 영역에서 낙석 위치가 달라져야 한다")
	hazard.reset_effect(71)
	var first: float = hazard.plans[0].distance
	hazard.advance(1.0,first-200,0)
	check(hazard.plans[0].bodies.size() == 3 and not hazard.plans[0].landed,"떨어지기 전 경고와 실제 공중 바위가 있어야 한다")
	for body in hazard.plans[0].bodies: check(body.collision_layer == 0,"공중 경고 단계에서 보이지 않는 벽을 만들면 안 된다")
	hazard.advance(2.0,first-180,0)
	await tree.physics_frame
	await tree.physics_frame
	check(hazard.plans[0].landed,"낙석은 실제 도로에 착지해야 한다")
	var hit_at: Vector3 = hazard.plans[0].bodies[1].position
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1,1.3,4.3)
	query.shape = box
	query.collision_mask = 2
	query.transform = Transform3D(Basis(Vector3.UP,section.heading(first)),hit_at)
	check(not section.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"착지한 바위는 실제 자동차를 막는 충돌체가 있어야 한다")
	query.transform.origin = section.point(first-15)+Vector3.UP*.7
	query.motion = section.point(first+15)-section.point(first-15)
	var clearance: PackedFloat32Array = section.get_world_3d().direct_space_state.cast_motion(query)
	check(clearance[0] == 1.0,"중앙에는 실제 차체가 지나갈 안전 통로가 남아야 한다")
	hazard.advance(.1,section.length+80,1)
	check(hazard.plans[0].landed and hazard.plans[0].bodies[0].collision_layer == 2,"이전 주회 낙석이 다음 주회에도 남아야 한다")
	race.restart()
	check(hazard.plans.size() == 1 and hazard.planned_lap == 0,"재시작 때 낙석과 주회 계획을 초기화해야 한다")
	race.queue_free()
	await tree.process_frame
	print("주회별 무작위 낙석 / 이격 / 실제 장애물 / 차체 통과로 / 초기화: ","PASS" if failures == 0 else "FAIL")
	return failures
