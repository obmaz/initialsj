extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var tour: Node3D = race.track.active
	check(tour.scenery.landmarks != null and tour.scenery.landmarks.tower_distances.size() == 2,"투어 해안에 두 주탑이 있는 실제 장대교가 있어야 합니다")
	var bridge_mid: float = (tour.bridge_span.x+tour.bridge_span.y)*0.5
	check(tour.scenery.terrain_point(bridge_mid,30).y < 0 and tour.point(bridge_mid).y > 20,"다리 아래가 흙으로 메워지지 않고 수면 위에 떠 있어야 합니다")
	check(tour.on_bridge(bridge_mid),"투어 다리 아래로 일반 흙 갓길 사면을 만들면 안 됩니다")
	check(tour.scenery.get_node_or_null("BridgeBayWater") != null,"투어 다리 양쪽 아래에 바다가 보여야 합니다")
	for i in range(750,1490):
		check(absf(tour.rail_setback(i+1,1)-tour.rail_setback(i,1)) < 0.15,"다리 진입부의 가드레일 폭은 연속적으로 좁아져야 합니다")
	for d in tour.scenery.landmarks.tower_distances:
		check(is_equal_approx(tour.rail_setback(d,1),1.5),"다리 주탑과 주행용 갓길이 겹치면 안 됩니다")
	race.track.reset(4,0)
	await tree.physics_frame
	var canyon: Node3D = race.track.active.scenery.landmarks
	check(canyon != null and canyon.billboard_manifest.size() >= 12,"투어 협곡 루트에 양쪽 절벽과 반복 광고판이 있어야 합니다")
	for ad in canyon.billboard_manifest:
		check(ad.distance < 1700 or ad.distance > 2390,"투어 광고판은 터널 안에 놓으면 안 됩니다")
	race.choose_mode("track",4)
	await tree.physics_frame
	await tree.physics_frame
	var section: Node3D = race.track.active
	var landmarks: Node3D = section.scenery.landmarks
	check(race.selected_course == 4 and race.COURSE_COUNT == 5,"다섯 번째 독립 코스가 있어야 합니다")
	check(section.length > 3000 and section.length < 3800,"다리 직선과 협곡 S자를 연결한 긴 코스여야 합니다")
	check(landmarks.tower_distances.size() == 2 and landmarks.billboard_manifest.size() >= 12,"트랙에도 주탑·케이블·협곡·광고판이 모두 있어야 합니다")
	check(landmarks.bridge_clearance > 60,"대형 주탑 가로보가 도로 위를 충분히 높게 통과해야 합니다")
	check(section.point(0).distance_to(section.point(section.length-0.05)) < 0.2,"코스 시작과 끝의 노면이 이어져야 합니다")
	check(section.on_bridge(430),"트랙 장대교에도 흙 사면 대신 교량 바닥을 사용해야 합니다")
	var outside: Vector3 = section.point(430,section.half_width(430)+10)
	var outside_hit: Dictionary = section.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(outside+Vector3.UP*4,outside-Vector3.UP*120,1))
	check(not outside_hit.is_empty() and outside_hit.position.y < outside.y-30,"장대교 밖을 흙 사면이 메우면 안 됩니다")
	check(section.bridge_span.y-section.bridge_span.x < 600,"긴 다리 구간을 600m 미만으로 줄여야 합니다")
	check(section.point(430).y-section.point(40).y > 20,"다리 정상으로 실제 20m 이상 올라가야 합니다")
	check(section.features.filter(func(f): return f.kind == "boost").size() >= 6,"교차 주행선을 선택하는 부스터 패드가 있어야 합니다")
	check(section.features.filter(func(f): return f.kind == "ramp").size() == 2,"착지 공간이 있는 점프 두 곳이 있어야 합니다")
	var rays := 0
	for i in range(120):
		var d: float = section.length*i/120
		for lane in [-8.0,0.0,8.0]:
			var p: Vector3 = section.point(d,lane)
			var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*4,p-Vector3.UP*6,1)
			var hit: Dictionary = section.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and absf(hit.position.y-p.y) < 0.15,"다리·협곡의 실제 노면이 보이는 도로와 같아야 합니다")
			rays += 1
	for ad in landmarks.billboard_manifest:
		var toward: Vector3 = section.point(ad.distance-65)-ad.position
		toward.y = 0
		check(ad.basis.z.dot(toward.normalized()) > .85,"광고 정면이 도로와 접근 차량 쪽을 향해야 한다")
		var projected: float = absf(ad.basis.x.dot((section.point(ad.distance,1)-section.point(ad.distance)).normalized()))*ad.width*0.5
		check(absf(ad.lane)-projected > section.half_width(ad.distance)+2,"광고판 전체가 가드레일 밖에 있어야 합니다")
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	var body: CharacterBody3D = race.world_race.player_body
	var peak_hearts := 0
	for frame in range(9500):
		var forward: Vector3 = body.velocity.normalized() if race.drifting and body.velocity.length() > 25 else body.forward_direction()
		var right := Vector3(-forward.z,0,forward.x).normalized()
		var look := clampf(race.speed*0.65,14,46)
		var to: Vector3 = race.track.point(race.distance+look,-2.5)-body.feet_position()
		var angle := atan2(to.dot(right),to.dot(forward))
		var wheel: float = (0.46+race.vehicle.handling*0.007)/(1+race.speed*0.035)*race.world_race.WorldCar.steering_scale(race.speed)
		var axis := clampf(atan(5.4*sin(angle)/look)/wheel,-1,1)
		var safe: float = race.vehicle.max_speed
		for ahead in [0.0,25.0,55.0,95.0,145.0]:
			var cap: float = sqrt(race.vehicle.grip*0.65/maxf(absf(race.track.curvature(race.distance+ahead)),0.0001))
			safe = minf(safe,sqrt(cap*cap+2*25*ahead))
		var bend: float = absf(race.track.curvature(race.distance+25))
		var tap: bool = race.speed > 28 and not race.drifting and bend > 0.002
		if race.drifting and bend < 0.0008: tap = true
		await tree.physics_frame
		race.step(1.0/60,axis,tap,true,race.speed > safe+0.5)
		peak_hearts = maxi(peak_hearts,race.coast_drift.hearts)
		if race.laps_completed >= 1: break
	print("Gorge driving: length=",section.length," lap=",race.laps_completed," walls=",race.wall_hits," hearts=",peak_hearts," score=",race.score)
	check(race.laps_completed == 1 and race.wall_hits == 0,"실제 입력으로 다리와 협곡을 장벽 접촉 없이 한 바퀴 완주해야 합니다")
	check(peak_hearts > 0,"협곡 코너에서도 실제 슬라이드 보상이 발생해야 합니다")
	for ramp in section.features.filter(func(f): return f.kind == "ramp"):
		for launch_speed in [65.0,95.0]:
			race.restart()
			race.state = "racing"
			for rival in race.rivals: rival.active = false
			race.world_race.teleport(0,ramp.distance-35,ramp.lane)
			body.velocity = body.forward_direction()*launch_speed
			race.speed = launch_speed
			var flew := false
			var landed := false
			for frame in range(210):
				var f: Vector3 = body.forward_direction()
				var r := Vector3(-f.z,0,f.x).normalized()
				var aim: Vector3 = race.track.point(race.distance+25,ramp.lane)-body.feet_position()
				var angle := atan2(aim.dot(r),aim.dot(f))
				var wheel: float = (0.46+race.vehicle.handling*.007)/(1+race.speed*.035)*race.world_race.WorldCar.steering_scale(race.speed)
				var axis := clampf(atan(5.4*sin(angle)/25)/wheel,-1,1)
				await tree.physics_frame
				race.step(1.0/60,axis,false,false,false)
				if frame>8 and not body.grounded and body.feet_position().y-race.track.point(race.distance).y>.5: flew = true
				if flew and body.grounded and race.distance>ramp.distance+25: landed = true; break
			check(flew and landed and race.wall_hits==0,"두 점프대 모두 실제 차체가 장벽 접촉 없이 이륙·착지해야 합니다")
	race.open_courses()
	race.menu_focus = 4
	race.pad_pressed(JOY_BUTTON_A)
	check(race.selected_course == 4 and race.state == "ready","패드로 다섯 번째 코스를 시작해야 합니다")
	race.queue_free()
	await tree.process_frame
	print("Tour bridge / canyon ads / TRACK05 / actual floor rays ",rays," / driven lap: ","PASS" if failures == 0 else "FAIL")
	return failures
