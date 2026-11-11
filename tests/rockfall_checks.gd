extends RefCounted
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 4)
	var hazard: Node3D = race.track.active.rockfall
	var section: Node3D = race.track.active
	var sites := {}
	for seed_value in range(30):
		hazard.reset_effect(seed_value)
		hazard.plan_lap(1)
		hazard.plan_lap(2)
		check(hazard.scenic_plans.size() == 30, "도로 밖 낙하는 매 주회 열 차례씩 계획해야 한다")
		check(hazard.plans.size() == 3, "모든 주회에 다른 낙석 지점이 있어야 한다")
		for i in range(hazard.plans.size()):
			var d: float = hazard.plans[i].distance
			sites[int(d)] = true
			check(d >= 1100 and d <= section.length - 280, "낙석은 다리와 결승선 밖 협곡 구간에 놓아야 한다")
			for j in range(i):
				check(absf(d - float(hazard.plans[j].distance)) >= 400, "이전 낙석과400m 이상 떨어져야 한다")
			for feature in section.features:
				check(absf(d - float(feature.distance)) >= float(feature.length) * .5 + 90, "점프·부스터 구간을 낙석으로 막으면 안 된다")
	check(sites.size() > 35, "재시작마다 넓은 후보 영역에서 낙석 위치가 달라져야 한다")
	hazard.reset_effect(71)
	var first: float = hazard.plans[0].distance
	hazard.advance(1.0, first - 200, 0)
	check(hazard.plans[0].bodies.size() == 9 and not hazard.plans[0].landed, "떨어지기 전 경고와 실제 공중 바위가 있어야 한다")
	for body in hazard.plans[0].bodies:
		check(body.collision_layer == 0, "공중 경고 단계에서 보이지 않는 벽을 만들면 안 된다")
	for i in range(hazard.plans[0].bodies.size()):
		var body: StaticBody3D = hazard.plans[0].bodies[i]
		check(
			body.get_child_count() == 1 and body.get_child(0).shape == hazard.rock_shape,
			"도로 낙석은 충돌 모양을 공유하고 개별 렌더 노드를 중복 생성하면 안 된다"
		)
		# Headless의 더미 렌더러는 MultiMesh 변환을 읽어도 항등행렬을 돌려준다.
		# 여기서는 제출한 포즈와 충돌체를 비교하고 실제 GPU 변환은 웹 출력에서 확인한다.
		check(body.transform.is_equal_approx(hazard.plans[0].poses[i]), "낙하 중 렌더 제출 포즈와 충돌체의 변환이 일치해야 한다")
	hazard.advance(3.0, first - 180, 0)
	await tree.physics_frame
	await tree.physics_frame
	check(hazard.plans[0].landed, "낙석은 실제 도로에 착지해야 한다")
	check(
		(
			hazard.plans[0].targets.size() == 24
			and hazard.plans[0].batch.multimesh.visible_instance_count == 9
			and hazard.plans[0].bodies.size() == 9
		),
		"도로 안24개 낙하 중9개만 남고 추가 낙석은 사라져 통로를 유지한다"
	)
	var hit_at: Vector3 = hazard.plans[0].bodies[1].position
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 1.3, 4.3)
	query.shape = box
	query.collision_mask = 2
	query.transform = Transform3D(Basis(Vector3.UP, section.heading(first)), hit_at)
	check(
		not section.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
		"착지한 바위는 실제 자동차를 막는 충돌체가 있어야 한다"
	)
	query.transform.origin = section.point(first - 15) + Vector3.UP * .7
	query.motion = section.point(first + 15) - section.point(first - 15)
	var clearance: PackedFloat32Array = section.get_world_3d().direct_space_state.cast_motion(query)
	check(clearance[0] == 1.0, "중앙에는 실제 차체가 지나갈 안전 통로가 남아야 한다")
	hazard.advance(.1, section.length + 80, 1)
	check(hazard.plans[0].landed and hazard.plans[0].bodies[0].collision_layer == 2, "이전 주회 낙석이 다음 주회에도 남아야 한다")
	var scenic: Dictionary = hazard.scenic_plans[0]
	hazard.advance(1.0, scenic.distance - 200, 0)
	check(scenic.poses.size() == 24 and scenic.bodies.is_empty(), "도로 밖에는 한 번에24개의 바위가 떨어져야 한다")
	check(
		scenic.node.get_child_count() == 1 and scenic.batch.multimesh.instance_count == 24,
		"도로 밖 낙석은 물리 노드 없이 공간별 MultiMesh 하나로 그려야 한다"
	)
	hazard.advance(4.0, scenic.distance - 180, 0)
	check(scenic.landed, "도로 밖 낙석도 착지해 남아야 한다")
	var settled_pose: Transform3D = scenic.poses[0]
	hazard.advance(60, scenic.distance, 0)
	check(scenic.poses[0].is_equal_approx(settled_pose), "착지한 잔해는 매 프레임 변환을 갱신하지 않고 같은 위치에 남아야 한다")
	for pose in scenic.poses:
		var nearest: float = section.curve.get_closest_offset(pose.origin)
		var center: Vector3 = section.point(nearest)
		check(
			(
				Vector2(pose.origin.x - center.x, pose.origin.z - center.z).length() - 2.8
				> section.half_width(nearest) + section.rail_setback(nearest, scenic.side)
			),
			"도로 밖 낙석의 전체 크기가 가드레일 밖에 남아야 한다"
		)
	race.restart()
	check(hazard.plans.size() == 1 and hazard.planned_lap == 0, "재시작 때 낙석과 주회 계획을 초기화해야 한다")
	race.queue_free()
	await tree.process_frame
	print("주회별 무작위 낙석 / 이격 / 실제 장애물 / 차체 통과로 / 초기화: ", "PASS" if failures == 0 else "FAIL")
	return failures
