extends RefCounted
const Flow = preload("res://scripts/race/contact_flow.gd")
const Rewards = preload("res://scripts/race/driving_rewards.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var flow := Flow.new()
	flow.advance(.5, true)
	check(not flow.sustained(), "가까이 달리는 것만으로 벽 타기로 판정하지 않는다")
	flow.contact(true)
	flow.advance(.15, true)
	check(not flow.sustained() and flow.reward_hold > 0, "짧은 스침은 보상만 잠시 대기한다")
	flow.advance(.16, true)
	check(flow.sustained(), "실제 접촉 뒤 벽 밀어붙이기가 이어지면 지속 접촉으로 전환한다")
	flow.advance(.016, false)
	check(not flow.sustained(), "도로 쪽으로 벗어나면 벽 밀어붙이기를 해제한다")
	flow.contact(false)
	flow.advance(.4, true)
	check(not flow.sustained() and flow.reward_hold == 0, "교통 차량 접촉을 벽 타기로 누적하지 않는다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.restart()
	race.state = "racing"
	race.drifting = true
	race.drift_latched = true
	race.drift_charge = 1
	race.nitro_burst_left = 1
	race.nitro_active = true
	race.register_impact(.05, Vector2.RIGHT)
	check(race.drifting and race.drift_charge == 1 and race.nitro_burst_left == 1, "가벼운 스침은 드리프트·발사한 샷을 지우지 않는다")
	race.register_impact(.6, Vector2.RIGHT)
	check(not race.drifting and race.nitro_burst_left == 0, "가벼운 접촉 대기 중에도 강한 충돌은 즉시 끊는다")
	var remembered: Vector2 = race.impact_normal
	race.register_impact(.8, Vector2.LEFT)
	check(race.impact_normal == remembered, "강한 충돌의 같은 프레임 중복 연출은 억제한다")
	var reward := Rewards.new()
	for tick in range(60):
		reward.drift_step(1.0 / 60, true, .3, 40, 40.0 / 60, .008, true, "one")
	var seconds: float = reward.drift_seconds
	check(
		reward.drift_step(.1, true, .3, 40, 4, .008, true, "one", true) == 0 and reward.drift_seconds == seconds,
		"접촉 유예 중에는 드리프트 점수를 늘리지 않는다"
	)
	check(reward.drift_step(.05, false, .05, 40, 2, 0, true, "one", true) == 0, "벽에 닿은 순간 탈출 보상을 지급하지 않는다")
	check(reward.drift_step(.05, false, .05, 40, 2, 0, true, "one") > 0, "스침에서 벗어나 깨끗하게 복귀하면 짧은 유예 뒤 연결한다")
	race.choose_mode("track", 2)
	race.restart()
	race.state = "racing"
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	var d := 1480.0
	race.world_race.teleport(0, d, race.track.half_width(d) + race.track.active.rail_setback(d, 1) - 1.2)
	body.grounded = true
	body.surface_normal = Vector3.UP
	var road: Vector3 = (race.track.point(d + 2) - race.track.point(d - 2)).normalized()
	body.velocity = road * 40
	race.speed = 40
	race.nitro_burst_left = 1
	race.drifting = true
	session.contact_flow.contact(true)
	for tick in range(30):
		session.advance_contact(1.0 / 60)
	check(
		session.contact_flow.sustained() and race.speed < 38 and not race.drifting and race.nitro_burst_left == 0,
		"지속 접촉 신호가 실제 차체 감속·니트로 중단으로 연결된다"
	)
	race.throttling = true
	race.impact = 0
	race.braking = false
	preload("res://scripts/race/nitro_system.gd").update(race, .016, true, false)
	check(not race.nitro_active, "벽을 계속 밀며 누른 니트로가 매 틱 재발사되지 않는다")
	race.world_race.contact_flow.contact(true)
	race.world_race.teleport(0, 80)
	check(not race.world_race.contact_flow.wall_latched, "리스폰은 이전 벽 접촉을 다음 도로로 가져오지 않는다")
	race.free()
	await tree.process_frame
	print("약한 스침 유지 / 강한 충돌 중단 / 지속 벽 접촉 / 보상 대기·복구: ", "PASS" if failures == 0 else "FAIL")
	return failures
