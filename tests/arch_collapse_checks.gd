extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",3)
	var arches: Node3D = race.track.scenery.rock_arches
	for fall in arches.falls:
		arches.advance(5,fall.distance-200,0)
		check(fall.elapsed < 0,"첫 바퀴에는 아치가 유지되어야 한다")
		arches.advance(.8,fall.distance-200,1)
		check(fall.pieces[0].position.y < fall.origins[0].y and not fall.landed,"다음 바퀴 접근 중에 실제 아치 조각이 낙하해야 한다")
		arches.advance(4,fall.distance-180,1)
		check(fall.landed,"무너진 아치가 중앙에 쌓여 남아야 한다")
		await tree.physics_frame
		await tree.physics_frame
		var query := PhysicsShapeQueryParameters3D.new()
		var car := BoxShape3D.new()
		car.size = Vector3(2.1,1.4,4.5)
		query.shape = car
		query.collision_mask = 2
		for lane in [-8.0,0.0,8.0]:
			query.transform = Transform3D(Basis(Vector3.UP,race.track.heading(fall.distance)),race.track.point(fall.distance,lane)+Vector3.UP*.9)
			var hits: Array = race.get_world_3d().direct_space_state.intersect_shape(query)
			check(hits.is_empty() if lane != 0 else not hits.is_empty(),"아치 잔해는 중앙을 막고 양쪽 실제 차량 통과 폭을 비워야 한다")
			if lane != 0:
				query.transform.origin = race.track.point(fall.distance-22,lane)+Vector3.UP*.9
				query.motion = race.track.point(fall.distance+22,lane)-race.track.point(fall.distance-22,lane)
				var clearance: PackedFloat32Array = race.get_world_3d().direct_space_state.cast_motion(query)
				check(clearance[0] == 1.0,"아치 양쪽 통과로 전체에 실제 차량 크기의 여유가 있어야 한다")
		check(absf(arches.safe_lane(fall.distance-100,0)) > 6,"상대 차량도 중앙 잔해를 피해 측면으로 합류해야 한다")
	race.restart()
	for fall in arches.falls: check(fall.elapsed < 0 and fall.pieces[0].collision_layer == 0,"재시작하면 아치와 장애물을 함께 복원해야 한다")
	race.choose_mode("track",4)
	race.hazard_text = "ROCKS ON ROAD / KEEP LEFT"
	race.choose_mode("track",0)
	check(race.hazard_text.is_empty() and race.track.active.rockfall == null,"트랙1로 바꿀 때 트랙5 낙석 경고를 남기면 안 된다")
	race.queue_free()
	await tree.process_frame
	print("아치 다음 주회 붕괴 / 중앙 장애물 / 양측 통과 / 경고 초기화: ","PASS" if failures == 0 else "FAIL")
	return failures
