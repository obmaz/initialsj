extends RefCounted
const Motion = preload("res://scripts/effects/body_motion.gd")
const Audio = preload("res://scripts/audio/vehicle_audio.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var reactions: Array[float] = []
	for model in ["hatch", "wedge", "muscle", "gt"]:
		var motion := Motion.new()
		motion.sample(.016, Vector3(0, 0, -40), Basis.IDENTITY, true)
		check(motion.acceleration == Vector2.ZERO, "첫 샘플·리스폰 속도는 가속 충격으로 취급하지 않는다")
		for frame in range(60):
			motion.sample(1.0 / 60, Vector3(0, 0, -40 - frame * .25), Basis.IDENTITY, true)
			motion.advance(1.0 / 60, model, false)
		check(motion.pose.x > .015 and absf(motion.pose.z) < .001, "실제 전진 가속은 차체 앞을 들고 직선에서 롤하지 않는다")
		reactions.append(motion.pose.x)
		motion.reset()
		motion.land(.8)
		var lowest := 0.0
		var rebound := 0.0
		for frame in range(180):
			motion.advance(1.0 / 60, model, false)
			lowest = minf(lowest, motion.pose.y)
			rebound = maxf(rebound, motion.pose.y)
		check(lowest < -.015 and rebound > 0 and motion.pose.length() < .001, "착지 압축·작은 반동 뒤 안정 상태로 수렴한다")
		motion.acceleration = Vector2(1000, -1000)
		for frame in range(8):
			motion.advance(.5, model, false)
		check(
			motion.pose.is_finite() and absf(motion.pose.x) < .1 and absf(motion.pose.z) < .1,
			"프레임 지연·큰 충격에도 시각 스프링이 발산하지 않는다"
		)
		motion.reset()
		check(motion.pose == Vector3.ZERO and not motion.sampled, "차량 재시작은 차체 운동 이력을 해제한다")
	check(
		reactions[2] > reactions[0] and reactions[0] > reactions[3] and reactions[3] > reactions[1],
		"네 차종의 시각 서스펜션 성격을 구분한다"
	)
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 2)
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	race.world_race.teleport(0, 1480, 0)
	var body: CharacterBody3D = race.world_race.player_body
	body.velocity = body.forward_direction() * 30
	race.speed = 30
	for frame in range(45):
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, true, false)
		race.player.animate(0, false, false, 1.0 / 60, 0)
	check(race.player.body.rotation.x > 0 and race.sound_state.load_amount > .7, "실제 물리 가속을 시각 차체와 엔진 부하가 함께 읽는다")
	for i in range(4):
		check(
			(
				race.player.wheels[i].global_position.distance_to(race.player.to_global(race.player.wheel_centres[i]))
				< .001
			),
			"하중 연출 중에도 바퀴 중심을 접지 높이에 유지한다"
		)
	var loaded := Audio.mix(race)
	for frame in range(25):
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, false, true)
		race.player.animate(0, false, false, 1.0 / 60, 0, true)
	check(race.player.body.rotation.x < 0, "실제 제동은 차체 앞을 숙인다")
	var coast := Audio.mix(race)
	check(coast.coast > loaded.coast and coast.engine < loaded.engine, "가속과 타력·제동을 다른 음색으로 크로스페이드한다")
	check(coast.gravel > 0 and coast.wet == 0, "항만 작업 통로의 실제 프로필에서 자갈 접촉음을 낸다")
	race.air.active = true
	body.grounded = false
	var airborne := Audio.mix(race)
	check(airborne.gravel == 0 and airborne.drift == 0 and airborne.wet == 0, "공중에서는 타이어·노면 접촉음이 나지 않는다")
	race.air.active = false
	body.grounded = true
	race.slip_angle = 0
	body.corner_demand = body.corner_grip * .85
	check(Audio.mix(race).drift > 0, "드리프트 버튼 전에도 실제 접지 한계가 가까우면 타이어가 경고한다")
	body.corner_demand = 0
	race.speed = 0
	race.drifting = true
	race.slip_angle = .5
	check(Audio.mix(race).drift == 0, "정지 상태의 드리프트 입력만으로 타이어 소리를 내지 않는다")
	race.speed = 45
	race.drifting = false
	race.slip_angle = 0
	race.throttling = true
	race.braking = false
	race.rewards.announce("CLEAN EXIT", 1.4, .6)
	var pulses: int = race.haptics.pulses
	race.sound_state.advance(race, .016)
	race.sound_state.advance(race, .016)
	check(
		race.haptics.pulses == pulses + 1 and race.boost_kick > 0 and Audio.mix(race).boost > 0,
		"보상 하나가 부스트 소리·카메라 반응·진동을 한 번만 연결한다"
	)
	race.throttling = false
	check(Audio.mix(race).boost == 0, "탈출 보상도 가속을 놓으면 불꽃과 소리가 함께 멈춘다")
	race.world_race.teleport(0, 1490)
	check(race.sound_state.gear == 0 and race.player.body_motion.pose == Vector3.ZERO, "순간이동은 변속·차체 운동을 초기화한다")
	race.rewards.reset()
	race.sound_state.reset()
	race.speed = race.vehicle.max_speed / 5.8 - 2
	race.sound_state.advance(race, .016)
	for frame in range(30):
		race.speed = race.vehicle.max_speed / 5.8 + (.1 if frame % 2 == 0 else -.1)
		race.sound_state.advance(race, .016)
	check(race.sound_state.gear == 1 and race.sound_state.shift == 0, "경계 속도 진동으로 변속 효과가 반복되지 않는다")
	race.speed += 2
	for frame in range(8):
		race.sound_state.advance(race, .016)
	check(race.sound_state.gear == 2 and race.sound_state.shift > 0, "안정적인 상향 변속에서만 짧은 피치·차체 반응을 낸다")
	var audio = preload("res://scripts/audio/racing_audio.gd").new()
	audio.race = race
	race.add_child(audio)
	audio.set_process(false)
	race.sound_enabled = true
	check_reward_audio(race, audio)
	race.free()
	await tree.process_frame
	print("실제 차체 하중 / 착지 감쇠 / 엔진 부하·변속 / 접지·노면 / 통합 보상: ", "PASS" if failures == 0 else "FAIL")
	return failures


func check_reward_audio(race: Node3D, audio: AudioStreamPlayer) -> void:
	audio._process(.016)
	race.rewards.announce("CLOSE PASS x3", 1.4, 0, 4, 3)
	race.sound_state.advance(race, .016)
	race.checkpoint_flash += 2
	audio._process(.016)
	check(audio.cue.stream == audio.LAP_TONE and audio.reward_pending > 0, "체크포인트 안내를 우선하고 보상음 하나만 잠시 대기한다")
	audio._process(.016)
	check(audio.cue.stream == audio.LAP_TONE, "다음 프레임에 보상음이 중요한 안내음을 바로 잘라내지 않는다")
	for frame in range(10):
		audio._process(.016)
	check(
		audio.cue.stream == audio.REWARD_TONE and is_equal_approx(audio.cue.pitch_scale, 1.14),
		"연속 보상 피치가 재생 도중 기본값으로 되돌아가지 않는다"
	)
	race.rewards.announce("CLOSE PASS x4", 1.4, 0, 4, 4)
	race.checkpoint_flash += 2
	audio._process(.016)
	race.protection_left = 3
	audio._process(.016)
	check(audio.reward_pending == 0, "복구 보호가 시작되면 미처 재생하지 못한 과거 보상음을 버린다")
