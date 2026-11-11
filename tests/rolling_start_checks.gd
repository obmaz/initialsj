extends RefCounted
const Report = preload("res://tests/report.gd")
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
	race.choose_mode("track", 1)
	race.restart()
	check(race.competitor_count() == 16 and race.world_race.bodies.size() == 16, "트랙2는15대의 상대와 실제16대 차체를 생성해야 한다")
	var low: float = race.distance
	var high: float = race.distance
	var ranks := {race.race_position(): true}
	for rival in race.rivals:
		if rival.active:
			high = maxf(high, rival.distance)
			ranks[race.competitor_position(rival.id)] = true
	check(high - low >= 340 and ranks.size() == 16, "16대의 출발 순위가 중복되지 않고340m 이상 분산되어야 한다")
	check(is_equal_approx(race.countdown, 6.0), "트랙2는6초 동안 두 배 길이로 롤링해야 한다")
	var initial: Vector3 = race.world_race.player_body.position
	for frame in range(90):
		await tree.physics_frame
		race._physics_process(1.0 / 60)
	check(
		(
			race.elapsed == 0
			and race.laps_completed == 0
			and race.world_race.player_body.position.distance_to(initial) > 40
		),
		"카운트다운에도 실제로 굴러가되 경기 시간·주회를 미리 가산하면 안 된다"
	)
	race.pause_tour()
	var frozen: Vector3 = race.world_race.player_body.position
	var before: float = race.countdown
	race._physics_process(.2)
	check(race.world_race.player_body.position == frozen and race.countdown == before, "일시정지는 롤링 대열과 출발 시간을 함께 멈춰야 한다")
	race.state = "countdown"
	for frame in range(275):
		await tree.physics_frame
		race._physics_process(1.0 / 60)
		if race.state == "racing":
			break
	check(
		race.state == "racing" and race.elapsed < .05 and race.speed > 32 and absf(race.distance - 80) < 6,
		"GO 때 출발선 부근에서 속도를 유지한 채 실제 경기 계측을 시작해야 한다"
	)
	check(race.wall_hits == 0, "16대의 자동 롤링 출발은 장벽에 부딪히면 안 된다")
	var levels := {0: 0, 1: 0, 2: 0}
	for body in race.world_race.bodies.slice(1):
		levels[race.world_race.rival_stride(body)] += 1
	check(levels[0] > 0 and levels[2] > 0 and levels[1] < 8, "분산 출발은 먼 차량과 중거리 차량을 실제 물리 LOD로 나눠야 한다")
	var board: Node3D = race.track.active.speedway_board
	check(
		board.labels.size() == 5 and board.position.distance_to(race.track.point(80)) < .1,
		"출발·결승선에 상위3기록과 베스트를 표시하는 전광판이 있어야 한다"
	)
	board.records.clear()
	for time in [143.2, 131.5, 140.1, 155.0]:
		board.add_result(time, "TEST CAR", false)
	check(
		board.records.size() == 3 and board.records[0].time == 131.5 and board.records[2].time == 143.2,
		"전광판의1·2·3위는 실제 완주 시간 오름차순이어야 한다"
	)
	race.best_time = 131.5
	board.refresh()
	check(board.labels[4].text.contains("02:11.500"), "개인 베스트도 실제 기록을 표시해야 한다")
	var timings := {}
	for count in [8, 16]:
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = rival.id < count - 1
		var samples: Array[float] = []
		for frame in range(120):
			await tree.physics_frame
			var begin := Time.get_ticks_usec()
			race.step(1.0 / 60, 0, false, true, false)
			samples.append((Time.get_ticks_usec() - begin) / 1000.0)
		samples.sort()
		var total := 0.0
		for sample in samples:
			total += sample
		timings[str(count)] = {"mean_ms": total / samples.size(), "p95_ms": samples[int(samples.size() * .95)]}
	FileAccess.open(Report.path("rolling-start-metrics.json"), FileAccess.WRITE).store_string(
		(
			JSON.stringify(
				{
					"headless_cpu_only": true,
					"physics_lod_at_start": levels,
					"active_competitors": timings,
					"failures": failures
				},
				"\t"
			)
			+ "\n"
		)
	)
	race.choose_mode("track", 2)
	check(race.competitor_count() == 8 and race.world_race.bodies.size() == 8, "다른 트랙은8대 구성을 유지해야 한다")
	for i in range(4):
		var skin: ShaderMaterial = race.track.scenery.get_node("Containers" + str(i)).material_override
		check(skin.get_shader_parameter("skins") != null, "항만 컨테이너 네 종류에 생성형 외장을 연결해야 한다")
	var signs := 0
	for child in race.track.scenery.get_children():
		if child is Label3D and child.text.contains("DRIFT") and child.text.contains("CURVE"):
			signs += 1
	check(signs >= 2, "기존 네온 바는 방향과 드리프트 의미를 글자로 안내해야 한다")
	race.choose_mode("track", 4)
	race.state = "racing"
	var energy: float = race.atmosphere.ambient_light_energy
	race.update_atmosphere(5)
	check(
		(
			race.atmosphere.sky.sky_material.get_shader_parameter("panorama") != null
			and absf(race.sun_light.rotation_degrees.x + 5) < .1
		),
		"트랙5의 노을 파노라마와 낮은 태양을 연결해야 한다"
	)
	check(
		(
			is_equal_approx(energy, race.atmosphere.ambient_light_energy)
			and race.sun_light.light_color.r > race.sun_light.light_color.b
		),
		"노을의 따뜻한 주광과 주변광은 매 프레임 낮 조명으로 덮이면 안 된다"
	)
	race.queue_free()
	await tree.process_frame
	print("16대 분산 롤링 / 실제 GO 계측 / 기록 전광판 / 항만 외장 / 노을광: ", "PASS" if failures == 0 else "FAIL")
	return failures
