extends RefCounted
const Rival = preload("res://scripts/race/rival_state.gd")
const Driving = preload("res://scripts/race/rival_driving.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func run(tree: SceneTree) -> int:
	var shot := Rival.new()
	shot.reset(1)
	check(Driving.nitro(shot, .1, 0, 60, true) and shot.boost_charges == 2, "직선형 상대는 자신의 니트로 샷을 소비한다")
	check(not Driving.nitro(shot, .1, 0, 60, false), "앞차에 막히면 부스트를 취소한다")
	var corner := Rival.new()
	corner.reset(2)
	check(not Driving.nitro(corner, .1, 0, 45, true), "코너형 상대는 직선 시작만으로 니트로를 쓰지 않는다")
	Driving.nitro(corner, .1, .005, 35, true)
	check(Driving.nitro(corner, .1, .001, 45, true), "코너를 빠져나오는 순간에 코너형 부스트를 쓴다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.save_records = false
	race.set_physics_process(false)
	race.choose_mode("track", 1)
	race.restart()
	var pace: float = race.rivals[1].pace
	var signature: Dictionary = race.rivals[1].specification.duplicate()
	race.open_garage()
	race.select_vehicle(3)
	race.restart()
	check(
		race.rivals[1].specification == signature and is_equal_approx(pace, race.rivals[1].pace),
		"플레이어 차 선택으로 상대 성능이 바뀌지 않는다"
	)
	check(race.world_race.bodies[2].specification == signature, "실제 상대 차체도 그 차종의 물리 성능을 쓴다")
	var models := {}
	var styles := {}
	for rival in race.rivals:
		models[rival.car.model] = true
		styles[rival.style.name] = true
	check(
		models.size() == mini(race.Catalog.SPECS.size(), race.rivals.size()) and styles.size() == 4,
		"등록된 차체와4가지 주행 성격을 섞는다"
	)
	race.free()
	await tree.process_frame
	print("상대별 차종·성격 / 독립 성능 / 직선·코너 탈출 니트로: ", "PASS" if failures == 0 else "FAIL")
	return failures
