extends RefCounted
const Challenges = preload("res://scripts/race/route_challenges.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func run(tree: SceneTree) -> int:
	var challenge := Challenges.new()
	check(not challenge.gate("arch", 100, 120, 220, 1, true), "안전 구간을 미리 통과하기 시작해야 한다")
	check(challenge.gate("arch", 225, 120, 220, 3, true), "무충돌 실제 통과를 보상한다")
	check(not challenge.gate("arch", 226, 120, 220, 4, true), "같은 구간을 반복해서 집계하지 않는다")
	challenge.gate("rock", 100, 120, 220, 5, true)
	challenge.invalidate()
	check(not challenge.gate("rock", 225, 120, 220, 7, true), "복구로 건너뛴 구간은 성공으로 인정하지 않는다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.save_records = false
	race.set_physics_process(false)
	race.choose_mode("track", 4)
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	race.world_race.teleport(0, 330, 6.0)
	var body: CharacterBody3D = race.world_race.player_body
	body.velocity = body.forward_direction() * 85
	race.speed = 85
	for frame in range(300):
		await tree.physics_frame
		var forward: Vector3 = body.forward_direction()
		var right := Vector3(-forward.z, 0, forward.x)
		var aim: Vector3 = race.track.point(race.distance + 28, 6.0) - body.feet_position()
		var angle := atan2(aim.dot(right), aim.dot(forward))
		var wheel: float = (
			(.46 + race.vehicle.handling * .007) / (1 + race.speed * .035) * body.steering_scale(race.speed)
		)
		race.step(1.0 / 60, clampf(atan(5.4 * sin(angle) / 28) / wheel, -1, 1), false, true, false)
		if race.route_challenges.skill_jumps > 0 or race.protection_left > 0:
			break
	check(
		race.route_challenges.skill_jumps == 1 and race.protection_left == 0, "실제 오른쪽 점프대를 타고 붕괴 구간 너머에 착지하면 한 번 보상한다"
	)
	check(race.rewards.exit_boost > 0 and race.rewards.boost_gain == 7, "위험 점프 성공은 실제 주행 가속 보상으로 연결한다")
	race.free()
	await tree.process_frame
	print("안전 우회·위험 점프 / 실제 붕괴 교량 비행·착지 / 중복·복구 방지: ", "PASS" if failures == 0 else "FAIL")
	return failures
