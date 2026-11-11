extends RefCounted
const Passport = preload("res://scripts/race/tour_passport.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func run(tree: SceneTree) -> int:
	var passport := Passport.new()
	check(passport.unlocked_paints() == [0] and passport.unlocked_plates() == [0], "도전 전에는 공장 도색·기본 번호판만 선택한다")
	passport.record_goal("LLLL", 1, false)
	check(passport.goals.size() == 1 and passport.unlocked_paints().has(1), "첫 목적지 완주로 도색을 해금한다")
	passport.record_goal("LLLL", 3, false)
	check(
		passport.goals.size() == 1 and passport.routes.size() == 1 and passport.goals.canyon == 3,
		"반복 완주는 목적지를 중복 집계하지 않고 메달만 높인다"
	)
	for index in range(16):
		var route := ""
		for bit in range(4):
			route += "R" if (index >> bit) & 1 else "L"
		passport.record_goal(route, 2, index == 15)
	check(passport.goals.size() == 5 and passport.routes.size() == 16, "모든 분기 순서가 다섯 도착지와16개 방문 기록을 채운다")
	check(
		passport.unlocked_paints().size() == 5 and passport.unlocked_plates().size() == 5, "전체 목적지·경로·무충돌 도전으로 장식을 해금한다"
	)
	passport.path = "user://test_passport_" + str(get_instance_id()) + ".cfg"
	passport.cycle(0, false)
	passport.cycle(0, true)
	passport.save_progress()
	var loaded := Passport.new()
	loaded.path = passport.path
	loaded.load_progress()
	check(
		loaded.goals == passport.goals and loaded.paint_index(0) == 1 and loaded.plate_index(0) == 1,
		"목적지와 차량별 장식 선택을 저장·복원한다"
	)
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.save_records = false
	race.set_physics_process(false)
	race.passport = loaded
	var spec := Catalog.spec(0).duplicate(true)
	race.apply_cosmetics()
	check(race.player.paint == Color("208eba") and race.vehicle == spec, "장식은 실제 플레이어 외형에만 적용하고 주행 성능은 바꾸지 않는다")
	race.player.set_protection(true)
	race.player.set_protection(false)
	check(race.player.paint == Color("208eba"), "리스폰 보호가 끝나도 선택한 도색을 유지한다")
	race.state = "menu"
	race.toggle_passport()
	check(race.passport_open and race.navigate_back() and not race.passport_open, "뒤로가기는 여권을 닫고 메인 화면을 유지한다")
	race.open_garage()
	var plate := false
	for node in race.player.body.get_children():
		if node is Label3D and node.text == "TOUR-01":
			plate = true
	check(plate, "해금한 번호판 문구를 차량의 기존 GLB 번호판 위치에 표시한다")
	DirAccess.remove_absolute(passport.path)
	race.free()
	await tree.process_frame
	print("투어5목적지·16경로 / 메달·장식 해금 / 저장·외형 적용·뒤로가기: ", "PASS" if failures == 0 else "FAIL")
	return failures
