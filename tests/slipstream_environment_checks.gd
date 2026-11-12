extends RefCounted
const Sound = preload("res://scripts/audio/racing_audio.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func move_other(other: CharacterBody3D, player: CharacterBody3D, ahead: float, side: float, speed: float = 35) -> void:
	var forward: Vector3 = player.forward_direction()
	other.reset_pose(
		player.feet_position() + forward * ahead + player.global_basis.x * side, forward, player.surface_normal
	)
	other.grounded = true
	other.velocity = forward * speed


func charge(race: Node3D) -> void:
	for frame in range(75):
		race.slipstream.prepare(race, 1.0 / 60)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 1)
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	race.world_race.teleport(0, 300, 0)
	var player: CharacterBody3D = race.world_race.player_body
	player.grounded = true
	player.velocity = player.forward_direction() * 35
	race.speed = 35
	race.throttling = true
	race.impact_age = 10
	var other: CharacterBody3D = race.world_race.bodies[1]
	race.rivals[0].active = true
	move_other(other, player, 20, 0)
	charge(race)
	check(
		race.slipstream.ready and race.slipstream.target_id == other.get_instance_id(), "같은 실제 앞차의 후류를 유지하면 준비 상태가 된다"
	)
	var score: float = race.score
	var nitro: float = race.nitro
	player.velocity = player.forward_direction() * 50
	race.speed = 50
	move_other(other, player, 1.2, 3, 25)
	race.slipstream.prepare(race, .05)
	move_other(other, player, -.3, 3, 25)
	race.slipstream.finish(race, .05)
	check(race.slipstream.passes == 1 and race.rewards.message == "SLIPSTREAM PASS", "충전한 같은 차 옆으로 빠져나와 통과하면 성공한다")
	check(race.score == score and race.nitro == nitro, "기존 추월 점수·니트로를 성공 연출에서 중복 지급하지 않는다")
	move_other(other, player, 20, 0)
	charge(race)
	check(not race.slipstream.ready and race.slipstream.passes == 1, "같은 차를 오가며 같은 주회에서 성공을 반복하지 않는다")
	race.laps_completed += 1
	charge(race)
	check(race.slipstream.ready, "다음 주회에는 새 후류 추월에 도전할 수 있다")
	race.impact = .4
	race.slipstream.prepare(race, .016)
	check(not race.slipstream.ready and race.slipstream.charge == 0, "충돌하면 저장한 준비 상태를 취소한다")
	race.impact = 0
	charge(race)
	move_other(other, player, 6, 3)
	for frame in range(200):
		race.slipstream.prepare(race, .016)
	check(not race.slipstream.ready and race.slipstream.charge == 0, "후류에서 나온 뒤3초 동안 추월하지 못하면 준비가 끝난다")
	race.slipstream.reset()
	move_other(other, player, 20, 0)
	other.position += Vector3.UP * 12
	charge(race)
	check(race.slipstream.charge == 0, "위쪽 다른 도로의 차량으로 충전하지 않는다")
	move_other(other, player, 20, 0)
	charge(race)
	move_other(other, player, 1.2, 3)
	race.slipstream.prepare(race, .016)
	move_other(other, player, -20, 3)
	race.slipstream.finish(race, .016)
	check(race.slipstream.passes == 0, "상대가 순간이동한 경우에는 성공으로 집계하지 않는다")
	race.world_race.teleport(0, 350)
	check(race.slipstream.charge == 0 and not race.slipstream.ready, "복구는 후류 충전과 대상 관측을 초기화한다")
	race.choose_mode("tour")
	race.state = "racing"
	race.world_race.teleport(0, 200, 0)
	player = race.world_race.player_body
	player.grounded = true
	player.velocity = player.forward_direction() * 35
	race.speed = 35
	race.throttling = true
	race.impact_age = 10
	var found := false
	for traffic in tree.get_nodes_in_group("tour_road_traffic"):
		if traffic.clock != race or traffic.road != race.track.active:
			continue
		traffic.activated = true
		traffic.set_physics_process(false)
		move_other(traffic, player, 20, 0)
		found = race.slipstream.prepare(race, .016)
		charge(race)
		check(race.slipstream.ready, "투어의 움직이는 일반 차량 뒤에서도 충전한다")
		break
	check(found, "실제 활성 투어 차량을 공통 후류 대상으로 사용한다")
	race.choose_mode("track", 0)
	race.state = "racing"
	var span: Vector2 = race.track.active.underpass_span()
	race.world_race.teleport(0, (span.x + span.y) * .5, 0)
	race.acoustics.advance(race, .016)
	check(race.acoustics.wet > 0 and race.acoustics.wet < .03, "실제 터널에 들어갈 때 잔향이 갑자기 최대가 되지 않는다")
	for frame in range(90):
		race.acoustics.advance(race, .016)
	check(race.acoustics.wet > .21 and race.acoustics.enclosure > .95, "실제 터널 구간에서 닫힌 공간의 잔향으로 수렴한다")
	var tunnel: float = race.acoustics.wet
	race.state = "paused"
	race.acoustics.advance(race, 1)
	check(race.acoustics.wet == tunnel, "일시정지는 공간 상태도 보존한다")
	race.state = "racing"
	race.distance = 80
	player = race.world_race.player_body
	player.reset_pose(race.track.point(80), race.track.point(82) - race.track.point(78))
	race.acoustics.advance(race, .016)
	check(race.acoustics.wet < tunnel and race.acoustics.wet > .15, "터널 밖에서는 급격히 끊지 않고 열린 공간으로 돌아온다")
	race.choose_mode("track", 2)
	race.state = "racing"
	race.world_race.teleport(0, 1480, 0)
	for frame in range(90):
		race.acoustics.advance(race, .016)
	check(
		race.acoustics.wet > .09 and race.acoustics.wet < tunnel and race.acoustics.enclosure < .3,
		"컨테이너 협로는 터널보다 짧고 가벼운 공간 반응을 사용한다"
	)
	var buses := AudioServer.bus_count
	var sound := Sound.new()
	sound.race = race
	race.add_child(sound)
	sound.set_process(false)
	race.sound_enabled = true
	sound._process(.016)
	var bus_name: StringName = sound.environment_audio.bus_name
	check(
		sound.bus == bus_name and sound.extra_loops.coast.bus == bus_name and sound.cue.bus == &"Master",
		"차량 루프만 공간 버스로 보내고 보상·안내음은 분리한다"
	)
	check(AudioServer.bus_count == buses + 3, "공간 잔향·좌우 패닝은 총 세 고정 버스만 사용한다")
	for frame in range(120):
		sound._process(.016)
	check(AudioServer.bus_count == buses + 3, "프레임이나 지역 진입 횟수만큼 버스를 생성하지 않는다")
	race.sound_enabled = false
	sound._process(.016)
	check(
		AudioServer.is_bus_mute(AudioServer.get_bus_index(bus_name)) and sound.environment_audio.reverb.wet == 0,
		"음소거는 남은 공간 잔향도 차단한다"
	)
	sound.free()
	check(AudioServer.bus_count == buses, "음향 종료는 공통 잔향·패닝 버스를 전부 해제한다")
	race.world_race.player_body.position += Vector3.UP * 12
	for frame in range(120):
		race.acoustics.advance(race, .016)
	check(race.acoustics.wet < .001, "협로 위쪽 공중에서는 지상 협로의 잔향을 적용하지 않는다")
	race.free()
	OS.delay_msec(500)
	await tree.process_frame
	print("후류 충전·탈출 추월 / 중복·충돌·고저차·복구 / 터널·항만 잔향 / 고정 DSP·음소거·해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
