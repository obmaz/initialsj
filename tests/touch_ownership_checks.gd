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
	race.state = "racing"
	race.auto_accelerate = false
	race.hud.configure_pedals()
	var hud: Control = race.hud
	for pair in [["left", "right"], ["gas", "brake"], ["drift", "nitro"]]:
		var a: Vector2 = hud.buttons[pair[0]].get_center()
		var b: Vector2 = hud.buttons[pair[1]].get_center()
		check(hud.button_at(a.lerp(b, .49)) == pair[0], "겹친 여유 영역의 가까운 첫 버튼을 선택한다")
		check(hud.button_at(a.lerp(b, .51)) == pair[1], "겹친 여유 영역의 가까운 둘째 버튼을 선택한다")
		hud.fingers = {1: a, 2: b}
		check(hud.held(pair[0]) and hud.held(pair[1]), "서로 다른 두 포인터의 동시 입력은 유지한다")
		hud.fingers = {1: a.lerp(b, .5)}
		check(not (hud.held(pair[0]) and hud.held(pair[1])), "한 포인터가 인접한 두 액션을 동시에 누르지 않는다")
	race.auto_accelerate = true
	check(hud.button_at(hud.buttons.gas.get_center()) == "brake", "자동 가속에서는 같은 자리의 브레이크만 활성화한다")
	check(hud.button_at(Vector2(640, 360)).is_empty(), "주행 시야의 빈 곳은 액션을 선택하지 않는다")
	check(not hud.hit_button("", Vector2(640, 360)), "빈 액션 이름은 빈 시야에서도 입력되지 않는다")
	check(not hud.hit_button("unknown", hud.buttons.gas.get_center()), "미등록 액션은 버튼 위에서도 입력되지 않는다")
	check(hud.hit_button("pause", hud.buttons.pause.get_center()), "일시정지의 사각 터치 영역을 유지한다")
	race.free()
	await tree.process_frame
	print("겹친 모바일 여유 영역 / 단일 포인터 배타성 / 멀티터치 / 자동 가속 페달: ", "PASS" if failures == 0 else "FAIL")
	return failures
