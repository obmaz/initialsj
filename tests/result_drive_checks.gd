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
	race.sound_enabled = false
	race.choose_mode("track", 0)
	race.restart()
	for rival in race.rivals:
		rival.active = false
	race.world_race.teleport(0, 600, 0, false)
	var body: CharacterBody3D = race.world_race.player_body
	body.velocity = body.forward_direction() * 40
	body.grounded = true
	race.speed = 40
	race.elapsed = 120
	race.score = 1234
	race.finish()
	var frozen := [race.distance, race.elapsed, race.score, race.laps_completed, race.race_position(), race.best_time]
	var start := body.global_position
	var last_speed := 40.0
	for i in range(480):
		await tree.physics_frame
		race.result_drive.advance(race, 1.0 / 60)
		race.place_cars()
		check(race.speed <= last_speed + .001, "결과 주행은 가속·부스트 없이 감속한다")
		last_speed = race.speed
	check(body.global_position.distance_to(start) > 30, "완주 후 안전한 도로를 실제 차체로 굴러간다")
	check(race.result_drive.stopped and race.speed == 0, "결과 주행은8초 이내 완전히 멈춘다")
	check(
		frozen == [race.distance, race.elapsed, race.score, race.laps_completed, race.race_position(), race.best_time],
		"결과 주행은 공식 거리·시간·점수·랩·순위·기록을 바꾸지 않는다"
	)
	race.update_camera(1)
	var rear: Vector3 = race.camera.global_position
	race.update_camera(4.5)
	check(race.camera.global_position.distance_to(rear) > 3, "중계 카메라는 시간에 따라 다른 구도로 전환한다")
	race.motion_reduced = true
	race.update_camera(1)
	var steady: Transform3D = race.camera.global_transform
	race.update_camera(5)
	check(race.camera.global_transform.is_equal_approx(steady), "동작 감소에서는 카메라 컷·회전을 멈춘다")
	check(race.hud.result_continue_rect().size.y >= 80, "결과 화면은 큰 전용 터치 버튼을 사용한다")
	race.choose_mode("track", 4)
	race.restart()
	for rival in race.rivals:
		rival.active = false
	var collapse: Node3D = race.track.active.collapse
	collapse.advance(4, 300)
	await tree.physics_frame
	var approach: float = collapse.span.x - 34
	var right_lane: float = race.track.active.surface_lane(5.5, approach)
	race.world_race.teleport(0, approach, right_lane, false)
	body = race.world_race.player_body
	body.grounded = true
	body.velocity = body.forward_direction() * 35
	race.state = "failed"
	for i in range(240):
		await tree.physics_frame
		race.result_drive.advance(race, 1.0 / 60)
	check(race.result_drive.stopped and race.result_drive.distance < collapse.span.x - 3, "붕괴 다리의 실제 빈 노면 앞에서 멈춘다")
	check(body.feet_position().y > race.track.point(approach, right_lane).y - 2, "종료 연출 중 새 낙하나 리스폰을 만들지 않는다")
	race.choose_mode("tour")
	race.restart()
	race.world_race.teleport(0, race.track.length - 22, 0, false)
	body = race.world_race.player_body
	body.grounded = true
	body.velocity = body.forward_direction() * 30
	race.state = "failed"
	var before := body.global_position
	for i in range(90):
		await tree.physics_frame
		race.result_drive.advance(race, 1.0 / 60)
	check(
		race.result_drive.stopped and body.global_position.distance_to(before) < 2,
		"투어 분기 끝에서는 결과 주행이 떨어지거나 다음 지역으로 넘어가지 않는다"
	)
	race.restart()
	check(not race.result_drive.initialized, "재시작은 종료 연출 상태를 초기화한다")
	race.world_race.player_body.grounded = true
	race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * 30
	race.finish()
	before = race.world_race.player_body.global_position
	for i in range(20):
		race.result_drive.advance(race, 1.0 / 60)
	check(race.world_race.player_body.global_position.is_equal_approx(before), "투어 최종 골은 도로 밖으로 자동 주행하지 않는다")
	race.free()
	await tree.process_frame
	print("종료 관성 주행 / 공식 결과 보존 / 안전한 정지 / 중계 구도 / 모바일 결과 버튼: ", "PASS" if failures == 0 else "FAIL")
	return failures
