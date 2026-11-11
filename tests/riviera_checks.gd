extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run(tree: SceneTree) -> int:
	var chain := preload("res://scripts/race/coast_drift.gd").new()
	check(chain.step(1,60,0,false,true,true) == 0,"직선 주행에는 드리프트 보상을 주지 않습니다")
	check(chain.step(1,60,0.4,true,false,true) == 0,"공중에서는 하트가 쌓이지 않습니다")
	for i in range(180): chain.step(1.0/60,60,0.4,true,true,true)
	check(chain.hearts >= 2 and chain.multiplier >= 2,"접지된 실제 슬라이드로 하트와 배수가 증가해야 합니다")
	var points: float = chain.points
	chain.step(0.35,60,0,false,true,true)
	chain.step(0.2,60,-0.4,true,true,true)
	check(chain.points > points,"짧은 S자 전환은 이전 콤보를 이어야 합니다")
	chain.step(0.1,60,0.4,true,true,false)
	check(not chain.active and chain.hearts == 0 and chain.broken,"충돌·이탈 후에는 연속 하트가 끊어져야 합니다")
	chain.reset()
	check(chain.points == 0 and chain.visible_time == 0,"재시작 시 보상과 표시가 초기화돼야 합니다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",3)
	await tree.physics_frame
	var section: Node3D = race.track.active
	check(race.selected_course == 3 and race.COURSE_COUNT == 5,"TRACK04가 독립 코스로 선택돼야 합니다")
	check(section.scenery.theme == "riviera" and section.scenery.tree_positions.size() >= 300,"전용 해안 환경과 야자수 대로가 있어야 합니다")
	check(section.length > 3000 and section.length < 6000,"긴 드리프트를 잇는 완결된 해안 코스여야 합니다")
	var low := INF
	var high := -INF
	var bends := 0
	for i in range(400):
		var d: float = section.length*i/400
		low = minf(low,section.point(d).y)
		high = maxf(high,section.point(d).y)
		if absf(section.curvature(d)) > 0.004: bends += 1
		check(section.half_width(d) >= 9.8 and section.half_width(d) <= 13.8,"협곡에서는 완만하게 좁아지고 나머지는 넓은 드리프트 도로여야 합니다")
		for lane in [-11.0,0.0,11.0]:
			check(section.scenery.terrain_point(d,lane).y < section.point(d,lane).y-0.2,"뱅킹 안쪽 차선을 지형이 덮으면 안 됩니다")
	check(high-low >= 40 and bends > 20,"완만한 고저차와 긴 곡선이 실제 도로에 있어야 합니다")
	check(section.point(0).distance_to(section.point(section.length-0.05)) < 0.2,"출발선에서 도로가 끊기면 안 됩니다")
	check(race.world_race.player_body.coast_profile,"새 코스에는 지속 슬라이드 프로파일을 적용해야 합니다")
	var lanes: MeshInstance3D = section.get_node("CurvedLaneMarks")
	check(is_equal_approx(lanes.material_override.get_shader_parameter("dash_length"),6),"멀리서 읽히는 긴 차선 도색을 적용해야 합니다")
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	var body: CharacterBody3D = race.world_race.player_body
	var drift_frames := 0
	var earned_hearts := 0
	for frame in range(6500):
		var forward: Vector3 = body.velocity.normalized() if race.drifting and body.velocity.length() > 25 else body.forward_direction()
		var right := Vector3(-forward.z,0,forward.x).normalized()
		var look := clampf(race.speed*0.65,14,46)
		var to: Vector3 = race.track.point(race.distance+look,-2.5)-body.feet_position()
		var angle := atan2(to.dot(right),to.dot(forward))
		var wheel: float = (0.46+race.vehicle.handling*0.007)/(1+race.speed*0.035)*race.world_race.WorldCar.steering_scale(race.speed)
		var axis := clampf(atan(5.4*sin(angle)/look)/wheel,-1,1)
		var safe: float = race.vehicle.max_speed
		for ahead in [0.0,25.0,55.0,95.0,145.0]:
			var cap: float = sqrt(race.vehicle.grip*0.72/maxf(absf(race.track.curvature(race.distance+ahead)),0.0001))
			safe = minf(safe,sqrt(cap*cap+2*25*ahead))
		var bend: float = absf(race.track.curvature(race.distance+25))
		var tap: bool = race.speed > 28 and not race.drifting and bend > 0.0015
		if race.drifting and bend < 0.0008: tap = true
		await tree.physics_frame
		race.step(1.0/60,axis,tap,true,race.speed > safe+0.5)
		if race.drifting and absf(race.slip_angle) > 0.12: drift_frames += 1
		earned_hearts = maxi(earned_hearts,race.coast_drift.hearts)
		if race.laps_completed >= 1: break
	check(race.laps_completed == 1 and race.wall_hits == 0,"실제 입력으로 드리프트하며 장벽 접촉 없이 한 바퀴를 완주해야 합니다")
	check(drift_frames > 90 and earned_hearts > 0 and race.score > 500,"실제 물리 주행에서 슬립과 하트·점수가 발생해야 합니다")
	race.open_courses()
	race.menu_focus = 3
	race.controls.pad_pressed(JOY_BUTTON_A)
	check(race.selected_course == 3,"패드로 네 번째 카드에 진입할 수 있어야 합니다")
	race.choose_mode("track",0)
	await tree.physics_frame
	check(not race.world_race.player_body.coast_profile,"기존 코스에는 새 슬라이드 설정을 적용하지 않습니다")
	race.queue_free()
	await tree.process_frame
	print("Riviera / rolling coast / lane paint / heart chains / course input: ","PASS" if failures == 0 else "FAIL")
	return failures
