extends RefCounted
const Challenge = preload("res://scripts/race/tour_challenge.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func run(tree: SceneTree) -> int:
	var keys := {}
	for path in range(16):
		var route: Array = []
		for bit in range(4):
			route.append((path >> bit) & 1)
		keys[Challenge.route_id(route)] = true
		check(Challenge.score_multiplier(route) >= 1 and Challenge.score_multiplier(route) <= 1.56, "모든 경로의 위험 배율 범위")
	check(keys.size() == 16, "최종 목적지가 같아도 분기 순서별 기록은 분리한다")
	check(Challenge.route_length([0, 0, 0, 0]) < Challenge.route_length([1, 1, 1, 1]), "메달 목표는 실제 경로 길이를 반영한다")
	check(Challenge.medal(150, [0, 0, 0, 0], 72) == 3 and Challenge.medal(500, [0, 0, 0, 0], 72) == 1, "차량·경로별 완주 메달")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.save_records = false
	race.set_physics_process(false)
	var choice: Dictionary = Challenge.choice(race, 1)
	check(
		choice.title == "SKYLINE DRIVE" and choice.hint.contains("D2") and choice.multiplier > 1,
		"분기에 실제 다음 지역·난이도·배율을 표시한다"
	)
	race.state = "racing"
	race.track.history.assign([0, 0, 1, 1])
	var first: String = race.record_key()
	race.record_store.set_value(race.RECORD_GROUP, first, 250.0)
	race.load_record()
	check(race.best_time == 250, "경기 중 기록 조회는 로딩 때 확보한 캐시를 사용한다")
	race.track.history.assign([0, 1, 0, 1])
	race.load_record()
	check(race.record_key() != first and race.best_time == 0, "같은 목적지의 다른 경로 기록을 섞지 않는다")
	race.free()
	await tree.process_frame
	print("투어16경로 기록 / 위험 배율·메달 / 분기 정보·캐시: ", "PASS" if failures == 0 else "FAIL")
	return failures
