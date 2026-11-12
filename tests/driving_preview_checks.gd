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
	race.choose_mode("track", 0)
	var section: Node3D = race.track.active
	var curve := Curve3D.new()
	curve.bake_interval = 1
	for d in range(701):
		var angle := clampf(d - 130, 0, 120) * .01
		var at := Vector3(0, 0, -d) if d < 130 else Vector3((1 - cos(angle)) / .01, 0, -130 - sin(angle) / .01)
		if d > 250:
			at += Vector3(sin(angle), 0, -cos(angle)) * (d - 250)
		curve.add_point(at)
	section.curve = curve
	section.length = curve.get_baked_length()
	section.closed_loop = false
	race.track.curvature_cache = preload("res://scripts/track/circuit_curvature.gd").new(curve, section.length)
	race.distance = 60
	race.speed = 100
	check(absf(race.track.curvature(race.distance + 35)) < .001, "기존35m 시점에는 아직 급커브가 보이지 않는 시험 노면이다")
	for frame in range(30):
		race.world_race.update_corner_warning(1.0 / 60)
	check(race.corner_warning > .15 and race.recommended_speed < 80, "먼 급커브를 제동 거리 기준으로 미리 경고한다")
	var saved: float = race.world_race.warning_speed_limit
	race.surface.wet_time = race.surface.WET_DURATION
	race.world_race.warning_clock = 0
	race.world_race.update_corner_warning(.016)
	check(race.world_race.warning_speed_limit <= saved, "젖은 노면에서 감속 예고가 늦어지지 않는다")
	race.distance = section.length - 4
	race.world_race.warning_clock = 0
	for frame in range(60):
		race.world_race.update_corner_warning(1.0 / 60)
	check(race.corner_warning < .01, "열린 투어형 도로 끝에서 미선택 다음 분기를 감속 근거로 사용하지 않는다")
	race.free()
	await tree.process_frame
	print("전방 제동 거리 예고 / 젖은 노면 / 열린 도로 경계: ", "PASS" if failures == 0 else "FAIL")
	return failures
