extends RefCounted
const Report = preload("res://tests/report.gd")
const Library = preload("res://scripts/track/route_library.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
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
	race.auto_accelerate = false
	race.hud.configure_pedals()
	var rows := []
	await tree.physics_frame
	await tree.physics_frame
	var left: Node3D = race.track.previews[0]
	var right: Node3D = race.track.previews[1]
	check(left.entry_buffer_length == 0 and right.entry_buffer_length == 0, "양 분기는 추가 직진 연결부 없이 원래 지역으로 진입한다")
	check(left.point(20).distance_to(right.point(20)) < 10, "분기 시작점의 두 도로는 부드럽게 이어진다")
	var gap: Vector3 = (left.point(300) + right.point(300)) * .5
	check(race.track.in_fork_gap(gap, race.track.length + 300), "두 분기 사이의 빈 틈을 낙하 전에 감지한다")
	check(not race.track.in_fork_gap(left.point(300), race.track.length + 300), "정상 분기 노면은 중앙 틈으로 오인하지 않는다")
	var space: PhysicsDirectSpaceState3D = left.get_world_3d().direct_space_state
	check(
		not (
			space
			. intersect_ray(
				PhysicsRayQueryParameters3D.create(left.point(300) + Vector3.UP * .7, gap + Vector3.UP * .7, 2)
			)
			. is_empty()
		),
		"분기 중앙으로 진입하는 실제 차체 경로에는 투명 장벽이 있다"
	)
	for road in [left, right]:
		for d in [20.0, 80.0, 119.0, 121.0, 180.0]:
			for lane in [-6.0, 0.0, 6.0]:
				var p: Vector3 = road.point(d, lane)
				check(
					not (
						space
						. intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * .4, p - Vector3.UP * .4, 1))
						. is_empty()
					),
					"진입부와 원래 지역의 이음매는 실제 주행 가능한 바닥이다"
				)
	# 바닥 높이에 있어도 중앙 틈에 들어가면 이 틱에 즉시 복구한다.
	race.state = "racing"
	race.distance = race.track.length + 300
	race.world_race.player_body.reset_pose(gap, Vector3.RIGHT, Vector3.UP)
	race.world_race.update_recovery(1.0 / 60, {"valid": false})
	check(race.distance < race.track.length and race.protection_left > 0, "중앙 틈은 낙하 대기 없이 안전 노면으로 즉시 복구한다")
	race.restart()
	# Visual chips are small, but hit areas retain a phone-sized target. Neither
	# target may steal pause/map touches or cover the central forward road view.
	var phone_scale := minf(896.0 / 1280, 414.0 / 720)
	for side in [0, 1]:
		var visual: Rect2 = race.hud.ROUTE_LEFT if side == 0 else race.hud.ROUTE_RIGHT
		var touch: Rect2 = race.hud.route_touch_rect(side)
		check(
			visual.size.y <= 64 and touch.size.y * phone_scale >= 44,
			"Compact route chips must retain a usable phone touch height"
		)
		check(not touch.intersects(race.hud.pause_touch_rect()), "A route choice must not overlap the pause target")
		check(not touch.intersects(Rect2(1087, 83, 185, 132)), "Route choices must leave the minimap clear")
		check(
			not visual.intersects(Rect2(230, 175, 820, 325)),
			"Route choices must leave the central forward road view unobstructed"
		)
		for title in Library.TITLES.values():
			check(
				(
					(
						race
						. hud
						. FONT
						. get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, race.hud.route_title_size(title))
						. x
					)
					<= 224
				),
				"Every route name must fit beside its arrow and selection tick"
			)
	for stage in range(4):
		for node in range(stage + 1):
			race.track.reset(stage, node)
			var arrows: MeshInstance3D = race.track.active.get_node("ForkRoadArrows")
			check(
				arrows.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0].y > 0.8,
				"Fork direction paint must face upward and remain visible"
			)
			var max_bend := 0.0
			var gate: float = race.track.active.checkpoint_distance()
			for sample in range(30):
				max_bend = maxf(
					max_bend, absf(race.track.curvature(lerpf(gate + 20, race.track.length - 15, sample / 29.0)))
				)
			check(max_bend < 0.0001, "Every route must remain straight between its checkpoint and fork")
			rows.append(
				{"stage": stage, "node": node, "straight_m": race.track.length - gate, "maximum_curvature": max_bend}
			)
	# 주행 중 다음 구간은 여러 프레임에 나눠 만들어지고, 완성된 결과는 한 번에 만든 구간과 같아야 한다.
	race.track.reset(1, 0)
	var whole: Node3D = race.track.previews[0]
	var whole_names := whole.get_children().map(func(child: Node) -> String: return child.get_class())
	var whole_triangles := 0
	for child in whole.get_children():
		if child is MeshInstance3D and child.mesh != null:
			whole_triangles += child.mesh.get_faces().size() / 3
	var whole_collision: Vector2i = Vector2i(
		whole.get_node("WorldCollision").get_meta("ground_triangles"),
		whole.get_node("WorldCollision").get_meta("barrier_triangles")
	)
	race.track.advance(0, race.track.length + Library.FORK_COMMIT, 0)
	race.track.advance(1, race.track.length + Library.FORK_COMMIT, 0)
	race.track.reset(1, 0)
	for node in race.track.previews:
		race.track.retire(node)
	race.track.previews.clear()
	race.track.maintain(100)
	check(race.track.previews.is_empty(), "Fork previews must not be built before the passed roads are released")
	var build_frames := 0
	var longest := 0
	while (
		build_frames < 4000
		and (
			race.track.previews.size() < 2
			or race.track.previews[0].build_pending()
			or race.track.previews[1].build_pending()
		)
	):
		var began := Time.get_ticks_usec()
		race.track.maintain(430)
		longest = maxi(longest, Time.get_ticks_usec() - began)
		if race.track.previews.size() == 2 and race.track.previews[1].build_pending():
			check(
				not race.track.previews[1].visible,
				"An unfinished fork road must stay hidden until its collision is registered"
			)
		build_frames += 1
		# 화면 프레임마다 준비하는 계약을 실제 SceneTree 프레임으로 검증한다.
		await tree.process_frame
	check(
		build_frames > 60 and build_frames < 4000,
		"Fork roads built while driving must be spread over many frames, not one"
	)
	var staged: Node3D = race.track.previews[0]
	var staged_triangles := 0
	for child in staged.get_children():
		if child is MeshInstance3D and child.mesh != null:
			staged_triangles += child.mesh.get_faces().size() / 3
	check(
		(
			staged.visible
			and not staged.staged
			and staged.get_children().map(func(child: Node) -> String: return child.get_class()) == whole_names
			and staged_triangles == whole_triangles
		),
		"A fork road built over several frames must match one built at once"
	)
	check(
		(
			Vector2i(
				staged.get_node("WorldCollision").get_meta("ground_triangles"),
				staged.get_node("WorldCollision").get_meta("barrier_triangles")
			)
			== whole_collision
		),
		"A staged fork road must register the same collision triangles"
	)
	race.track.reset(1, 0)
	for node in race.track.previews:
		race.track.retire(node)
	race.track.previews.clear()
	race.track.maintain(430)
	race.track.advance(0, race.track.length + Library.FORK_COMMIT, 0)
	check(
		(
			race.track.active.has_node("WorldCollision")
			and race.track.active.visible
			and not race.track.sibling.build_pending()
		),
		"Entering a fork must finish any road still being built"
	)
	rows.append({"staged_build_frames": build_frames, "longest_build_frame_ms": longest / 1000.0})
	var fastest := 0.0
	for index in range(preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()):
		var v := Catalog.spec(index)
		fastest = maxf(fastest, maxf(v.overdrive_speed + 2, v.max_speed + 21))
	check(
		Library.CHECKPOINT_RUNUP / (fastest * race.GAME_PACE) >= 1.5 and Library.CHECKPOINT_RUNUP < 300,
		"The short approach must still leave one and a half seconds of choice time at maximum boost"
	)
	race.track.reset()
	race.restart()
	race.state = "racing"
	for r in race.rivals:
		r.active = false
	preload("res://tests/tour_world_checks.gd").new().set_car(
		race, race.track.active.checkpoint_distance() - 0.5, 0, 65
	)
	for frame in range(4):
		race.step(1.0 / 60, 0, false, true, false)
	check(
		race.checkpoints == 1 and race.stage_index == 0 and race.route_choices_visible(),
		"Checkpoint must award time and expose route choices before changing stage"
	)
	var checkpoint_time: float = race.time_left
	for frame in range(85):
		race.speed = fastest
		race.step(race.GAME_PACE / 60, 0, false, false, false)
	check(
		race.stage_index == 0 and race.distance < race.track.length,
		"One real second after checkpoint must still leave the car on the straight approach"
	)
	check(
		race.checkpoints == 1 and race.time_left < checkpoint_time,
		"The straight approach must not award a checkpoint twice"
	)
	for index in range(preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()):
		for side in [0, 1]:
			race.open_garage()
			race.select_vehicle(index)
			race.restart()
			race.state = "racing"
			await tree.physics_frame
			for r in race.rivals:
				r.active = false
			race.award_checkpoint()
			preload("res://tests/tour_world_checks.gd").new().set_car(
				race, race.track.length - 165, 3.5 if side == 0 else -3.5, 65
			)
			race.hud.fingers[1] = race.hud.buttons.gas.get_center()
			var tap := InputEventScreenTouch.new()
			tap.index = 7
			tap.pressed = true
			var rect: Rect2 = race.hud.route_touch_rect(side)
			# A near-edge tap uses the padded target outside the visible chip.
			tap.position = (rect.position + Vector2(4, rect.size.y * 0.5)) * race.hud.ui_scale() + race.hud.ui_offset()
			race.hud.handle_pointer(tap)
			check(race.route_preference == side, "Padded compact route choices must select the intended side by touch")
			tap.pressed = false
			race.hud.handle_pointer(tap)
			check(
				race.hud.held("gas") and not race.hud.fingers.has(7),
				"Choosing a route with a second finger must preserve the held gas control"
			)
			var last: Vector3 = race.track.point(race.distance, race.lane)
			var max_step := 0.0
			for frame in range(600):
				race.step(1.0 / 60, 0, false, true, false)
				var world: Vector3 = race.track.point(race.distance, race.lane)
				max_step = maxf(max_step, world.distance_to(last))
				last = world
				if race.stage_index == 1:
					break
			check(
				race.stage_index == 1 and race.route_node == side,
				"Touch choice must steer each vehicle into the chosen physical branch"
			)
			check(
				race.wall_hits == 0 and max_step < 2.5, "Route assistance must stay inside bounds without teleporting"
			)
			check(
				race.checkpoints == 1 and not race.route_choices_visible(),
				"Branch commitment must hide the cards without a second checkpoint"
			)
	race.open_garage()
	race.state = "racing"
	race.award_checkpoint()
	race.distance = race.track.length - 100
	race.select_route(1)
	check(
		is_equal_approx(race.world_race.assisted_axis(-0.8), -0.8) and race.route_preference == -1,
		"Manual steering must override optional route assistance immediately"
	)
	FileAccess.open(Report.path("fork-metrics.json"), FileAccess.WRITE).store_string(
		(
			JSON.stringify(
				{
					"straight_routes": rows,
					"minimum_real_seconds_at_fastest_boost": Library.CHECKPOINT_RUNUP / (fastest * race.GAME_PACE),
					"failures": failures
				},
				"\t"
			)
			+ "\n"
		)
	)
	print(
		"Checkpoint / straight approach / mobile route choice / manual override: ", "PASS" if failures == 0 else "FAIL"
	)
	race.queue_free()
	await tree.process_frame
	return failures
