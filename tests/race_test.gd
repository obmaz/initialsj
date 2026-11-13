extends SceneTree
const Library = preload("res://scripts/track/route_library.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures += 1


func clear_traffic(race: Node3D) -> void:
	for r in race.rivals:
		r.distance = 10000.0


func reset_drive(race: Node3D) -> void:
	race.restart()
	race.state = "racing"
	clear_traffic(race)


func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.auto_accelerate = false
	race.hud.configure_pedals()
	await process_frame
	check(
		race.track.point(0).distance_to(race.track.point(race.track.length)) > 1200,
		"Road must be open, not a closed lap"
	)
	check(
		race.track.point(-10).distance_to(race.track.point(race.track.length - 10)) > 1000,
		"Negative road positions must extrapolate rather than wrap"
	)
	check(
		race.track.previews[0].point(300).distance_to(race.track.previews[1].point(300)) > 50,
		"Forks must be two physical roads"
	)
	check(race.track.point(800).y > race.track.point(80).y + 8, "Road must have real elevation")
	var arrays = race.track.road_surface.mesh.surface_get_arrays(0)
	check(
		arrays[Mesh.ARRAY_NORMAL][0].y > 0.8 and arrays[Mesh.ARRAY_TEX_UV].size() > 0,
		"Road must have upward faces and texture coordinates"
	)
	var themes := {}
	for row in Library.THEMES:
		for theme in row:
			themes[theme] = true
	check(themes.size() == 15, "All fifteen route nodes must have different themes")
	for stage in range(4):
		for node in range(stage + 1):
			check(
				Library.theme(stage + 1, node) != Library.theme(stage + 1, node + 1),
				"Every fork must lead to different left and right themes"
			)
	var art = race.track.scenery.roadside_art
	check(
		art.models.placements.size() + race.track.active.scenery.get_node("TourNativeVegetation").tree_count > 30,
		"The actual starting road must instantiate a 3D regional foreground"
	)
	for i in range(art.positions.size()):
		var p: Vector3 = art.positions[i]
		var d: float = race.track.active.curve.get_closest_offset(p)
		var width: float = art.widths[i]
		check(
			(
				Vector2(p.x - race.track.point(d).x, p.z - race.track.point(d).z).length() - width * 0.5
				> race.track.half_width(d) + 2
			),
			"Solid foreground bounds must stay outside the drivable road and rails"
		)
	for path in range(16):
		var visited := {Library.theme(0, 0): true}
		var node := 0
		for stage in range(1, 5):
			node += (path >> (stage - 1)) & 1
			var theme_id := Library.theme(stage, node)
			check(not visited.has(theme_id), "A complete tour must never repeat a theme")
			visited[theme_id] = true

	# 실제 주행·충돌·분기·제한시간은 tour_world_checks.gd에서 차체로 검증한다.
	race.state = "racing"
	for viewport in [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(390, 844)]:
		root.size = viewport
		race.hud.fingers.clear()
		for action in ["gas", "brake", "nitro"]:
			var event := InputEventScreenTouch.new()
			event.index = {"gas": 1, "brake": 2, "nitro": 3}[action]
			event.position = race.hud.buttons[action].get_center() * race.hud.ui_scale() + race.hud.ui_offset()
			event.pressed = true
			race.hud.handle_pointer(event)
		check(
			race.hud.held("gas") and race.hud.held("brake") and race.hud.held("nitro"),
			"Gas, brake and nitro touch targets must remain aligned on resize"
		)
	root.size = Vector2i(1280, 720)
	check(not race.hud.buttons.gas.intersects(race.hud.buttons.brake), "Gas and brake must have distinct touch targets")
	reset_drive(race)
	var minimum := INF
	var maximum := 0.0
	for i in range(100):
		var d: float = race.track.length * i / 100
		minimum = minf(minimum, race.track.half_width(d))
		maximum = maxf(maximum, race.track.half_width(d))
	check(maximum - minimum > 2.5, "The same road must visibly widen and narrow")
	var road_faces: PackedVector3Array = race.track.road_surface.mesh.get_faces()
	for segment in [0, 230, 540, 830]:
		var d: float = race.track.length * segment / 900
		var edge: Vector3 = road_faces[segment * 6]
		check(
			absf(edge.distance_to(race.track.point(d)) - race.track.half_width(d)) < 0.02,
			"Rendered road edges must follow the same width as driving bounds"
		)
	var start: Vector2 = race.hud.route_map_point(0, 0)
	var left: Vector2 = race.hud.route_map_point(1, 0)
	var right: Vector2 = race.hud.route_map_point(1, 1)
	check(
		start.y > left.y and start.y > right.y and left.x < start.x and right.x > start.x,
		"Route map must travel upward with left/right matching the physical fork"
	)
	check(
		(
			not race.hud.buttons.nitro.intersects(race.hud.buttons.drift)
			and not race.hud.buttons.nitro.intersects(race.hud.buttons.gas)
		),
		"Nitro must have its own visible touch target"
	)
	race.speed_ambience.update(race)
	check(not race.speed_ambience.petals.emitting, "Normal driving must not emit ambient particles")
	race.checkpoints = 1
	race.speed_ambience.update(race)
	check(race.speed_ambience.petals.one_shot, "Celebrations must be bounded one-shot bursts")
	var canopies := 0
	for stage in range(5):
		for node in range(stage + 1):
			var span := Library.canopy_span(stage, node)
			if span.y > span.x:
				canopies += 1
	check(
		canopies <= 2 and Library.canopy_span(0, 0) == Vector2.ZERO,
		"Glass roofs must be rare and absent from the starting coast"
	)
	var city_tunnel := Library.tunnel_span(1, 1)
	check(
		city_tunnel.y - city_tunnel.x >= 200 and city_tunnel.y - city_tunnel.x <= 400,
		"도시 터널은 시야를 오래 가리지 않는 짧은 연결 구간이어야 한다"
	)
	var section = load("res://scripts/track/road_section.gd")
	var easy = section.new(Vector3.ZERO, -PI / 2, 4, 0)
	var hard = section.new(Vector3.ZERO, -PI / 2, 4, 4)
	var easy_width := 0.0
	var hard_width := 0.0
	var easy_bends := 0.0
	var hard_bends := 0.0
	for i in range(100):
		var t := 0.15 + i * 0.007
		easy_width += easy.half_width(easy.length * t)
		hard_width += hard.half_width(hard.length * t)
		easy_bends += absf(easy.curvature(easy.length * t))
		hard_bends += absf(hard.curvature(hard.length * t))
	check(
		hard.length > easy.length + 500 and hard_width < easy_width * .92 and hard_bends > easy_bends * 1.25,
		"오른쪽 경로는 더 길고 평균 폭이8% 이상 좁으며 굴곡이 커야 한다"
	)
	easy.free()
	hard.free()
	race.track.reset(4, 4)
	var active_count := 0
	for r in race.rivals:
		if r.active:
			active_count += 1
	check(active_count == 0, "투어는 실제 차체 전환 뒤에도 단독 타임어택을 유지해야 한다")
	print("Tour checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await process_frame
	failures += await preload("res://tests/tour_world_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_world_geometry_checks.gd").new().run(self)
	failures += await preload("res://tests/garage_checks.gd").new().run(self)
	failures += await preload("res://tests/modes_checks.gd").new().run(self)
	failures += await preload("res://tests/road_feature_checks.gd").new().run(self)
	failures += await preload("res://tests/drift_rpm_checks.gd").new().run(self)
	failures += await preload("res://tests/speedway_checks.gd").new().run(self)
	failures += await preload("res://tests/rolling_start_checks.gd").new().run(self)
	failures += await preload("res://tests/air_checks.gd").new().run(self)
	failures += await preload("res://tests/tunnel_lights_checks.gd").new().run(self)
	failures += await preload("res://tests/render_budget_checks.gd").new().run(self)
	failures += await preload("res://tests/streaming_frame_checks.gd").new().run(self)
	failures += await preload("res://tests/rival_frame_budget_checks.gd").new().run(self)
	failures += await preload("res://tests/circuit_curvature_checks.gd").new().run(self)
	failures += await preload("res://tests/fork_checks.gd").new().run(self)
	failures += await preload("res://tests/shoulder_checks.gd").new().run(self)
	failures += await preload("res://tests/driving_state_checks.gd").new().run(self)
	failures += await preload("res://tests/back_navigation_checks.gd").new().run(self)
	failures += await preload("res://tests/tunnel_render_checks.gd").new().run(self)
	failures += await preload("res://tests/scenery_3d_checks.gd").new().run(self)
	failures += await preload("res://tests/speedway_structure_checks.gd").new().run(self)
	failures += await preload("res://tests/collision_feedback_checks.gd").new().run(self)
	failures += await preload("res://tests/world_car_checks.gd").new().run(self)
	failures += await preload("res://tests/circuit_progress_checks.gd").new().run(self)
	failures += await preload("res://tests/fuji_geometry_checks.gd").new().run(self)
	failures += await preload("res://tests/fuji_world_checks.gd").new().run(self)
	failures += await preload("res://tests/world_rival_checks.gd").new().run(self)
	failures += await preload("res://tests/boost_lane_checks.gd").new().run(self)
	failures += await preload("res://tests/boost_feedback_checks.gd").new().run(self)
	failures += await preload("res://tests/vehicle_audio_checks.gd").new().run(self)
	failures += await preload("res://tests/background_music_checks.gd").new().run(self)
	failures += await preload("res://tests/imported_vehicle_checks.gd").new().run(self)
	failures += await preload("res://tests/game_feel_checks.gd").new().run(self)
	failures += await preload("res://tests/camera_spatial_checks.gd").new().run(self)
	failures += await preload("res://tests/slipstream_environment_checks.gd").new().run(self)
	failures += await preload("res://tests/gamepad_checks.gd").new().run(self)
	failures += await preload("res://tests/guardrail_checks.gd").new().run(self)
	failures += await preload("res://tests/road_width_checks.gd").new().run(self)
	failures += await preload("res://tests/runoff_checks.gd").new().run(self)
	failures += await preload("res://tests/loading_screen_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_gimmick_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_comfort_checks.gd").new().run(self)
	failures += await preload("res://tests/result_screen_checks.gd").new().run(self)
	failures += await preload("res://tests/result_drive_checks.gd").new().run(self)
	failures += await preload("res://tests/juice_checks.gd").new().run(self)
	failures += await preload("res://tests/driving_effect_checks.gd").new().run(self)
	failures += await preload("res://tests/suncoast_world_checks.gd").new().run(self)
	failures += await preload("res://tests/midnight_checks.gd").new().run(self)
	failures += await preload("res://tests/harbor_corridor_checks.gd").new().run(self)
	failures += await preload("res://tests/riviera_checks.gd").new().run(self)
	failures += await preload("res://tests/riviera_transition_checks.gd").new().run(self)
	failures += await preload("res://tests/night_arch_checks.gd").new().run(self)
	failures += await preload("res://tests/structural_mass_checks.gd").new().run(self)
	failures += await preload("res://tests/advertising_checks.gd").new().run(self)
	failures += await preload("res://tests/rockfall_checks.gd").new().run(self)
	failures += await preload("res://tests/arch_collapse_checks.gd").new().run(self)
	failures += await preload("res://tests/gorge_checks.gd").new().run(self)
	failures += await preload("res://tests/corner_feel_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_geometry_checks.gd").new().run(self)
	failures += await preload("res://tests/crash_recovery_checks.gd").new().run(self)
	failures += await preload("res://tests/recovery_ui_checks.gd").new().run(self)
	failures += await preload("res://tests/world_crash_checks.gd").new().run(self)
	failures += await preload("res://tests/fullscreen_checks.gd").new().run(self)
	failures += await preload("res://tests/resource_lifecycle_checks.gd").new().run(self)
	failures += await preload("res://tests/render_resource_checks.gd").new().run(self)
	failures += await preload("res://tests/model_contract_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_scenery_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_facade_checks.gd").new().run(self)
	failures += await preload("res://tests/facade_variant_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_weather_checks.gd").new().run(self)
	failures += await preload("res://tests/jungle_sky_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_traffic_checks.gd").new().run(self)
	failures += await preload("res://tests/track_background_checks.gd").new().run(self)
	failures += await preload("res://tests/road_recovery_checks.gd").new().run(self)
	failures += await preload("res://tests/drive_revision_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_refinement_checks.gd").new().run(self)
	failures += await preload("res://tests/rail_escape_checks.gd").new().run(self)
	failures += await preload("res://tests/skill_rewards_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_challenge_checks.gd").new().run(self)
	failures += await preload("res://tests/rival_personality_checks.gd").new().run(self)
	failures += await preload("res://tests/personal_run_checks.gd").new().run(self)
	failures += await preload("res://tests/route_challenge_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_passport_checks.gd").new().run(self)
	failures += await preload("res://tests/tuning_checks.gd").new().run(self)
	failures += await preload("res://tests/tuning_ui_checks.gd").new().run(self)
	failures += await preload("res://tests/loading_presentation_checks.gd").new().run(self)
	failures += await preload("res://tests/roadside_guidance_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_landmark_checks.gd").new().run(self)
	failures += await preload("res://tests/track_environment_checks.gd").new().run(self)
	failures += await preload("res://tests/bright_menu_checks.gd").new().run(self)
	failures += await preload("res://tests/pre_race_ui_checks.gd").new().run(self)
	failures += await preload("res://tests/arcade_flow_checks.gd").new().run(self)
	failures += await preload("res://tests/momentum_checks.gd").new().run(self)
	failures += await preload("res://tests/drift_flow_checks.gd").new().run(self)
	failures += await preload("res://tests/contact_flow_checks.gd").new().run(self)
	failures += await preload("res://tests/grip_exit_checks.gd").new().run(self)
	failures += await preload("res://tests/driving_feedback_checks.gd").new().run(self)
	failures += await preload("res://tests/driving_preview_checks.gd").new().run(self)
	failures += await preload("res://tests/effect_item_checks.gd").new().run(self)
	failures += await preload("res://tests/race_boundary_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_record_selection_checks.gd").new().run(self)
	failures += await preload("res://tests/runtime_boundary_checks.gd").new().run(self)
	quit(1 if failures else 0)
