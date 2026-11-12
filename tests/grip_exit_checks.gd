extends RefCounted
const Rewards = preload("res://scripts/race/driving_rewards.gd")
const Probe = preload("res://tests/corner_feel_checks.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func corner(reward: RefCounted, key: String, curve: float = .008, clean: bool = true, slip: float = .04) -> int:
	var earned := 0
	for frame in range(60):
		earned += reward.corner_step(1.0 / 60, false, slip, 40, 40.0 / 60, curve, clean, key, false, 1, .6)
	for frame in range(12):
		earned += reward.corner_step(1.0 / 60, false, .04, 40, 40.0 / 60, 0, clean, "exit", false, 1, 0)
	return earned


func run(tree: SceneTree) -> int:
	var reward := Rewards.new()
	check(
		corner(reward, "one") == 120 and reward.grip_exits == 1 and reward.exit_boost > 0,
		"실제 곡률·주행 거리·작은 슬립으로 코너를 탈출하면 작은 보상을 준다"
	)
	check(corner(reward, "two") == 0, "직선 여유 없는 한 코너에서 그립·드리프트 보상을 반복하지 않는다")
	for frame in range(60):
		reward.corner_step(1.0 / 60, false, 0, 40, 40.0 / 60, 0, true, "straight", false, 1, 0)
	check(corner(reward, "one") == 0, "직선을 달린 뒤에도 같은 코너 키를 다시 오가며 보상받지 않는다")
	check(corner(reward, "next") == 120, "충분한 직선 이후 새 코너의 정밀 주행은 다시 보상한다")
	for scenario in range(5):
		reward.reset()
		var result := corner(
			reward, "invalid", 0 if scenario == 0 else .008, scenario != 1, .3 if scenario == 2 else .04
		)
		if scenario in [3, 4]:
			reward.reset()
			for frame in range(60):
				result = reward.corner_step(
					.016, false, 0, 40, -1 if scenario == 3 else 20, .008, true, "invalid", false, 1, .6
				)
		check(result == 0 and reward.clean_exits == 0, "직선·충돌·큰 슬립·역주행·순간이동은 그립 보상 대상이 아니다")
	var helper := Probe.new()
	var race := helper.make_race(tree)
	var floor := helper.physical_floor(tree)
	race.choose_mode("track", 0)
	var section: Node3D = race.track.active
	var curve := Curve3D.new()
	curve.bake_interval = 1
	for d in range(501):
		var turn := minf(d, 140) * .0045
		var at := Vector3((1 - cos(turn)) / .0045, 0, -sin(turn) / .0045)
		if d > 140:
			at += Vector3(sin(turn), 0, -cos(turn)) * (d - 140)
		curve.add_point(Vector3(8000, 100, 8000) + at)
	section.curve = curve
	section.length = curve.get_baked_length()
	section.closed_loop = false
	section.features.clear()
	section.bank_samples = PackedFloat32Array([0, 0])
	race.track.curvature_cache = preload("res://scripts/track/circuit_curvature.gd").new(curve, section.length)
	for tracker in race.world_race.trackers:
		tracker.configure(section)
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	race.world_race.teleport(0, 65, 0)
	await tree.physics_frame
	await tree.physics_frame
	race.step(1.0 / 60, 0, false, false, false)
	var body: CharacterBody3D = race.world_race.player_body
	body.velocity = body.forward_direction() * 35
	race.speed = 35
	for frame in range(210):
		var forward: Vector3 = body.forward_direction()
		var right := Vector3(-forward.z, 0, forward.x)
		var to: Vector3 = race.track.point(race.distance + 14, 0) - body.feet_position()
		var angle := atan2(to.dot(right), to.dot(forward))
		var wheel: float = (
			(0.46 + race.vehicle.handling * .007) / (1 + race.speed * .035) * body.steering_scale(race.speed)
		)
		var axis := clampf(atan(5.4 * sin(angle) / 14) / wheel, -1, 1)
		await tree.physics_frame
		race.step(1.0 / 60, axis, false, true, false)
	print("실제 그립 탈출=", race.rewards.grip_exits, " 충돌=", race.wall_hits, " 거리=", race.distance)
	check(
		race.rewards.grip_exits == 1 and race.wall_hits == 0 and not race.drifting, "실제 차체의 정상 코너 주행으로 그립 보상을 얻을 수 있다"
	)
	race.rewards.corner_locked = false
	race.rewards.corner_step(.016, false, 0, 40, .64, .008, true, "pending", false, 1, .6)
	check(race.rewards.grip_seconds > 0, "순간이동 전 코너 후보가 실제로 존재한다")
	race.world_race.teleport(0, 200)
	check(
		race.rewards.grip_seconds == 0 and race.rewards.drift_seconds == 0 and race.rewards.exit_boost == 0,
		"순간이동이 이전 코너 후보·탈출 가속을 다음 도로로 가져오지 않는다"
	)
	race.free()
	floor.free()
	await tree.process_frame
	print("정밀 그립 탈출 / 실제 차체 / 중복·역주행·워프 보상 방지: ", "PASS" if failures == 0 else "FAIL")
	return failures
