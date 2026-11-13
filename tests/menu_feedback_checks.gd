extends RefCounted
const Feedback = preload("res://scripts/ui/menu_feedback.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var feedback := Feedback.new()
	var bounds: Array[Rect2] = [Rect2(10, 20, 200, 80)]
	check(not feedback.press(Vector2.ZERO, bounds, "menu"), "원화의 빈 배경은 버튼 반응을 만들지 않는다")
	check(feedback.press(Vector2(40, 40), bounds, "menu"), "실제 입력 영역이 눌림 장식을 소유한다")
	feedback.advance(.11, "menu")
	check(is_equal_approx(feedback.amount(), .5), "짧은 눌림은 누적 이벤트 없이 시간으로 완화된다")
	check(feedback.offset_for(Rect2(24, 30, 100, 40), false).y > 0, "버튼 안의 실제 글자도 같은 눌림을 따른다")
	check(feedback.offset_for(Rect2(24, 30, 100, 40), true) == Vector2.ZERO, "동작 감소에서는 글자를 이동시키지 않는다")
	feedback.advance(.01, "courses")
	check(feedback.amount() == 0, "화면이 바뀌면 이전 버튼 반응이 새 화면으로 넘어가지 않는다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.state = "menu"
	race.hud.register_menu_press(race.hud.HOME_TRACK.get_center())
	check(race.hud.menu_feedback.rect == race.hud.HOME_TRACK, "모드 카드 반응은 입력과 같은 사각형을 사용한다")
	race.state = "ready"
	race.hud.menu_feedback.advance(.01, race.state)
	check(race.hud.menu_feedback.amount() == 0, "실제 메뉴 전환도 반응 상태를 초기화한다")
	race.free()
	await tree.process_frame
	print("원화 버튼 눌림 / 문자 이동 / 모션 감소 / 빈 영역·전환 초기화: ", "PASS" if failures == 0 else "FAIL")
	return failures
