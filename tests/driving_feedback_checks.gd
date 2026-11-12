extends RefCounted
const Audio = preload("res://scripts/audio/vehicle_audio.gd")
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
	race.restart()
	race.state = "racing"
	var body: CharacterBody3D = race.world_race.player_body
	body.grounded = true
	race.speed = 50
	race.throttling = true
	race.haptics.busy_until = 0
	body.corner_demand = body.corner_grip * 1.05
	var pulses: int = race.haptics.pulses
	for frame in range(180):
		race.driving_feedback.advance(race, 1.0 / 60)
	check(race.haptics.pulses == pulses + 1, "접지 한계 경고는 지속 중 반복하지 않고 한 번만 진동한다")
	race.boosting = true
	for frame in range(30):
		race.driving_feedback.advance(race, 1.0 / 60)
	check(race.driving_feedback.boost_envelope > .9, "부스트의 시야각 신호는 부드럽게 커진다")
	race.boosting = false
	race.driving_feedback.advance(race, .05)
	check(race.driving_feedback.boost_envelope > .4 and Audio.mix(race).boost > 0, "부스트 종료 뒤 짧은 음향·시야각의 여운이 남는다")
	race.braking = true
	race.driving_feedback.advance(race, .016)
	check(race.driving_feedback.boost_envelope == 0 and Audio.mix(race).boost == 0, "제동할 때 부스트 여운을 끊는다")
	race.braking = false
	race.motion_reduced = true
	race.driving_feedback.reset()
	pulses = race.haptics.pulses
	for frame in range(60):
		race.driving_feedback.advance(race, 1.0 / 60)
	check(race.haptics.pulses == pulses, "동작 감소에서는 접지 한계 예고 진동을 내지 않는다")
	race.player.body_motion.reset()
	race.motion_reduced = false
	race.rewards.announce("CLEAN EXIT", 1, .32)
	race.sound_state.advance(race, .016)
	var impulse: float = race.player.body_motion.spring_velocity.x
	race.sound_state.advance(race, .016)
	check(impulse > 0 and race.player.body_motion.spring_velocity.x == impulse, "탈출 성공의 차체 반응은 사건당 한 번만 발생한다")
	race.world_race.teleport(0, 80)
	check(
		race.driving_feedback.boost_envelope == 0 and race.driving_feedback.grip_pressure == 0, "복귀 시 이전 접지 부하와 여운을 지운다"
	)
	race.free()
	await tree.process_frame
	print("주행 신호 완화 / 접지 경고 히스테리시스 / 보상 차체 반응 / 복구 초기화: ", "PASS" if failures == 0 else "FAIL")
	return failures
