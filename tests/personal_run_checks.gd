extends RefCounted
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Personal = preload("res://scripts/race/personal_run.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func poses() -> PackedFloat32Array:
	return PackedFloat32Array([0, 80, 0, 0, 0, 0, 0, 0, 1, .2, 100, 10, 0, 0, 0, 0, 0, 1])


func run(tree: SceneTree) -> int:
	var run := Personal.new()
	check(Personal.valid_samples(poses()), "시간 순서와 정규화된 회전의 주행 데이터")
	var invalid := poses()
	invalid[9] = -1
	check(not Personal.valid_samples(invalid), "역순 시간 데이터는 재생하지 않는다")
	run.reference = poses()
	var middle: Transform3D = run.reference_pose(.1)
	check(middle.origin.distance_to(Vector3(5, 0, 0)) < .01, "고스트는 두 실제 월드 자세 사이를 보간한다")
	run.reference[11] = 1000
	check(run.reference_pose(.1) == null, "복구로 멀리 이동한 자세 사이를 날아다니며 보간하지 않는다")
	run.reference_route = "LRLL"
	check(run.matches([0, 1]) and not run.matches([1]), "다른 투어 분기로 진입하면 기존 경로 고스트를 표시하지 않는다")
	run.samples.resize(Personal.MAX_SAMPLES * Personal.STRIDE)
	run.sample(null)
	check(run.capped and run.samples.size() == Personal.MAX_SAMPLES * Personal.STRIDE, "긴 주행의 기록 메모리는 고정 상한을 넘지 않는다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.save_records = false
	race.set_physics_process(false)
	race.choose_mode("track", 0)
	race.personal_run.directory = "user://test_personal_" + str(race.get_instance_id())
	race.personal_run.prepare(race)
	race.personal_run.samples = poses()
	race.elapsed = .2
	race.new_record = true
	race.save_records = true
	race.personal_run.finish(race, true)
	check(
		not FileAccess.file_exists(race.personal_run.directory.path_join("index.cfg.tmp")), "개인 기록은 임시 저장 완료 후 원본을 교체한다"
	)
	race.save_records = false
	race.personal_run.prepare(race)
	check(race.personal_run.reference.size() == 18, "개인 최고 기록의 자세는 압축 저장 후 다시 읽을 수 있다")
	race.show_ghost = true
	race.ghost.prepare(race)
	var physical := false
	for node in race.ghost.find_children("*", "", true, false):
		physical = physical or node is CollisionObject3D
		if node is Light3D:
			check(not node.visible, "고스트는 추가 광원을 켜지 않는다")
	check(not physical, "고스트는 순위·교통·충돌에 참여하는 물리 차체가 아니다")
	race.show_ghost = false
	race.ghost.prepare(race)
	check(not is_instance_valid(race.ghost.car), "고스트 표시를 끄면 이전 시각 객체와 전용 재질 참조를 놓는다")
	race.personal_run.prepare(race)
	race.distance = 80
	race.elapsed = 0
	race.speed = 60
	race.personal_run.observe(race, true, .1)
	for tick in range(360):
		race.distance += 6
		race.elapsed += .1
		race.personal_run.observe(race, true, .1)
	check(
		race.personal_run.best_sectors.has("track:0:launch") and race.personal_run.split_new,
		"실제 순방향 구간 통과의 시간과 개인 구간 베스트를 계산한다"
	)
	race.state = "racing"
	race.world_race.safe_distance = 500
	race.world_race.safe_lane = 0
	race.recovery.available = true
	race.route_challenges.gates["pending"] = race.elapsed
	race.recover_car()
	check(race.personal_run.recoveries == 1 and not race.personal_run.segment_valid, "수동 복구도 무복구 도전과 현재 구간 기록을 무효화한다")
	check(race.route_challenges.gates.is_empty() and race.protection_left == 3, "수동 복구는 위험 구간 보상을 끊고 기존3초 보호를 유지한다")
	race.return_to_road()
	check(race.personal_run.recoveries == 2, "자동·수동 복구는 성공 한 번당 정확히 한 번 집계한다")
	race.mode = "tour"
	race.personal_run.scope = "LLLL:0"
	race.personal_run.scope_stage = 0
	race.track.history.assign([1])
	race.distance = 100
	race.personal_run.observe(race, true, .1)
	check(not race.personal_run.segment_valid, "같은 지역의 분기를 뒤늦게 바꾸어 첫 구간 기록을 단축할 수 없다")
	var folder: String = race.personal_run.directory
	var path: String = race.personal_run.file_path(Catalog.record_key(0, "track", 0))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder.path_join("index.cfg"))
	DirAccess.remove_absolute(folder)
	race.free()
	await tree.process_frame
	print("개인 고스트 압축·보간 / 경로 일치 / 구간 기록 / 메모리·충돌 격리: ", "PASS" if failures == 0 else "FAIL")
	return failures
