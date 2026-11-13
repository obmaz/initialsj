extends RefCounted
const Motion = preload("res://scripts/ui/modal_motion.gd")
var failures := 0
var calls := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var motion := Motion.new()
	motion.advance("settings", 0, false)
	var point := Vector2(350, 576)
	check(
		(motion.transform().affine_inverse() * (motion.transform() * point)).is_equal_approx(point), "표시와 입력 역변환이 일치한다"
	)
	motion.advance("settings", .18, false)
	check(motion.transform().is_equal_approx(Transform2D.IDENTITY), "등장 후 원래 배치에 도착한다")
	motion.close("settings", func(): calls += 1)
	motion.close("settings", func(): calls += 10)
	motion.advance("settings", .12, false)
	motion.advance("settings", .12, false)
	check(calls == 1, "연속 닫기의 완료 동작은 한 번만 실행한다")
	motion.close("settings", func(): calls += 10)
	motion.advance("paused", .2, false)
	check(calls == 1 and not motion.closing, "화면 교체가 이전 완료 동작을 취소한다")
	motion.close("controls", func(): calls += 1)
	motion.advance("controls", .12, false)
	check(calls == 2, "하위 화면 첫 표시 전 닫기도 유실되지 않는다")
	motion.advance("finished", 0, true)
	check(motion.transform().is_equal_approx(Transform2D.IDENTITY), "모션 감소는 확대 없이 표시한다")
	motion.advance("", .1, false)
	check(motion.transform() == Transform2D.IDENTITY, "주행에는 변환을 남기지 않는다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.state = "paused"
	race.resume_state = "racing"
	race.shell.portrait = true
	race.finish_resume_tour()
	check(race.state == "paused", "닫힘 중 세로 회전되면 주행을 재개하지 않는다")
	race.free()
	print("모달 좌표·닫기 단일 실행·화면 전환 취소·모션 감소: ", "PASS" if failures == 0 else "FAIL")
	return failures
