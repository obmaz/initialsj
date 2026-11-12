extends RefCounted
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func lens_checks(race: Node3D) -> void:
	var lens = race.rain_lens
	race.state = "racing"
	race.distance = 80
	race.nitro_active = true
	race.speed = 70
	lens.update(race, 1.0 / 60)
	check(lens.amount > .6, "비 오는 날 니트로를 누르면 렌즈 물방울이 맺힌다")
	for tick in range(120):
		lens.update(race, 1.0 / 60)
	check(lens.amount <= .95, "니트로를 계속 눌러도 물방울 강도는 상한을 넘지 않는다")
	race.nitro_active = false
	for tick in range(60):
		lens.update(race, 1.0 / 60)
	check(lens.amount > .1 and lens.amount < .6, "물방울은 니트로 종료 뒤 잠시 남았다가 흐른다")
	var clock: float = lens.clock
	race.state = "paused"
	lens.update(race, 1)
	check(lens.clock == clock, "일시정지는 렌즈 물방울 시간도 멈춘다")
	race.state = "racing"
	for tick in range(180):
		lens.update(race, 1.0 / 60)
	check(is_zero_approx(lens.amount), "니트로 종료 뒤 물방울이 계속 누적되지 않는다")
	var span: Vector2 = race.track.active.underpass_span()
	race.distance = (span.x + span.y) / 2
	race.nitro_active = true
	lens.update(race, .1)
	check(is_zero_approx(lens.amount), "지하차도 안에서는 니트로를 써도 물방울을 새로 맺히지 않는다")
	race.distance = 80
	race.motion_reduced = true
	lens.update(race, .1)
	check(is_zero_approx(lens.amount), "동작 감소는 렌즈 굴절을 끈다")
	race.motion_reduced = false
	race.nitro_active = false


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.motion_reduced = false
	var climate = race.track_environment
	var config := ConfigFile.new()
	config.set_value("track_environment", "weather", "invalid")
	config.set_value("track_environment", "time_of_day", 99)
	climate.read(config)
	check(climate.weather == "clear" and climate.time_of_day == "day", "손상된 공용 환경 설정은 맑은 낮으로 복구한다")
	race.preferences_path = "user://track_environment_checks.cfg"
	race.save_records = true
	race.cycle_track_weather()
	race.cycle_track_period()
	race.save_records = false
	config.load(race.preferences_path)
	check(
		(
			config.get_value("track_environment", "weather") == "rain"
			and config.get_value("track_environment", "time_of_day") == "dusk"
		),
		"공용 선택은 즉시 저장한다"
	)
	climate.weather = "clear"
	climate.time_of_day = "day"
	race.load_preferences()
	check(climate.weather == "rain" and climate.time_of_day == "dusk", "다음 실행에서 공용 환경 선택을 복원한다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(race.preferences_path))
	var phases := {}
	var night_ambient: Array[float] = []
	var street_counts: Array[int] = []
	var previous_material: ShaderMaterial
	for course in range(5):
		climate.weather = "clear"
		climate.time_of_day = "day"
		race.choose_mode("track", course)
		check(climate.supported(race), "모든 서킷에 공용 날씨·시간대를 적용한다")
		if previous_material != null:
			check(previous_material.get_shader_parameter("rain_wetness") == 1.0, "새 코스의 맑음이 이전 코스 재질을 변경하면 안 된다")
		var curvature = race.track.curvature_cache
		var fixtures: Node3D = race.track.active.get_node("CourseLighting")
		street_counts.append(fixtures.street_lights.size())
		check(fixtures.lights.size() == 4, "거리 조명 수와 무관하게 실제 스폿 풀은4개로 제한한다")
		var night_sun := 0.0
		for weather in ["clear", "rain"]:
			for period in ["day", "dusk", "night"]:
				var old_weather: String = climate.active_weather
				climate.weather = weather
				climate.time_of_day = period
				check(climate.active_weather == old_weather, "설정 선택만으로 현재 경기 환경을 바꾸지 않는다")
				race.restart(false)
				race.warming_world = true
				race.sync_world_rendering()
				race.render_budget.level = 0
				race.state = "racing"
				race.track.visible = true
				race.tour_weather._process(0)
				var material: ShaderMaterial = race.atmosphere.sky.sky_material
				check(
					material.get_shader_parameter("environment_period") == climate.PERIODS.find(period),
					"실제 하늘에 활성 시간대를 전달한다"
				)
				check(material.get_shader_parameter("environment_course") == course, "달과 하늘은 현재 코스의 프리셋을 사용한다")
				check(
					material.get_shader_parameter("rain_amount") == (1.0 if weather == "rain" else 0.0),
					"비구름은 활성 날씨와 일치한다"
				)
				var surface: ShaderMaterial = race.track.active.road_surface.material_override
				check(
					surface.get_shader_parameter("rain_wetness") == (1.0 if weather == "rain" else 0.0),
					"강수와 젖은 노면을 함께 켜고 끈다"
				)
				check(
					(
						surface.get_shader_parameter("wet_reflection_ready") == true
						and surface.get_shader_parameter("wet_panorama") == material.get_shader_parameter("panorama")
					),
					"젖은 반사는 현재 하늘 이미지와 실제 자원을 공유한다"
				)
				check(race.tour_weather.particles.emitting == (weather == "rain"), "야외 강수는 현재 설정을 따른다")
				check(climate.headlights(race) == (period != "day" or weather == "rain"), "저녁·밤·비에서는 자동 전조등을 사용한다")
				var window_materials := 0
				for object in preload("res://scripts/rendering/world_assets.gd").nodes(race.track.active):
					if not object is GeometryInstance3D or not object.material_override is ShaderMaterial:
						continue
					var facade: ShaderMaterial = object.material_override
					if (
						facade.shader.resource_path.get_file()
						not in ["building_facade.gdshader", "prop_facade.gdshader"]
					):
						continue
					window_materials += 1
					var expected := .88 if period == "dusk" else (.36 if period == "night" else 0.0)
					check(
						is_equal_approx(facade.get_shader_parameter("window_density"), expected),
						"황혼·야간·낮 창문 점등 밀도를 실제 재질에 적용한다"
					)
				check(window_materials > 0, "트랙의 건물 전용 재질을 점검한다")
				check(fixtures.is_night == (period != "day"), "광고·거리 조명은 낮에는 끄고 어두워지면 켠다")
				check(race.track.curvature_cache == curvature, "환경 변경으로 노면·곡률 캐시를 재생성하지 않는다")
				if period == "night":
					if weather == "clear":
						night_sun = race.sun_light.light_energy
						night_ambient.append(race.atmosphere.ambient_light_energy)
						phases[material.get_shader_parameter("moon_phase")] = true
					else:
						check(race.sun_light.light_energy < night_sun, "비 오는 밤이 맑은 밤보다 밝아지지 않는다")
		previous_material = race.track.active.road_surface.material_override
		race.render_budget.level = 2
		race.tour_weather._process(0)
		check(race.tour_weather.particles.amount == 90, "성능 단계에서는 강수 입자 예산을 낮춘다")
		fixtures._process(.2)
		check(fixtures.lights.filter(func(light): return light.visible).size() <= 2, "성능 단계에서는 실제 거리 광원을 최대2개 켠다")
		for light in fixtures.lights:
			check(not light.shadow_enabled, "거리 광원은 추가 그림자 맵을 만들지 않는다")
	check(phases.size() == 5, "5개 코스의 달 위상은 모두 달라야 한다")
	check(street_counts[1] > street_counts[0] * 3 and street_counts[4] == 0, "경기장 조명은 후지보다 촘촘하고 협곡에는 도로 가로등을 두지 않는다")
	for course in range(1, 5):
		check(night_ambient[0] < night_ambient[course], "후지의 야간 주변광이 다른 코스보다 어두워야 한다")
	previous_material = null
	climate.weather = "rain"
	climate.time_of_day = "night"
	race.choose_mode("track", 0)
	race.warming_world = true
	race.sync_world_rendering()
	race.state = "racing"
	lens_checks(race)
	var span: Vector2 = race.track.active.underpass_span()
	race.distance = (span.x + span.y) / 2
	race.player.global_position = race.track.point((span.x + span.y) / 2)
	race.tour_weather._process(0)
	check(not race.tour_weather.particles.emitting, "후지 지하차도 안에서는 비가 관통하지 않는다")
	race.choose_mode("tour")
	check(
		(
			race.sun_light.rotation_degrees.is_equal_approx(Vector3(-42, -32, 0))
			and is_equal_approx(race.atmosphere.tonemap_exposure, .88)
		),
		"투어 복귀 때 트랙의 달 방향·노출을 복구한다"
	)
	check(not climate.supported(race) and climate.weather == "rain", "투어 지역 날씨는 공용 트랙 선택과 분리한다")
	race.free()
	await tree.process_frame
	print("공용 환경 저장 /5트랙×6조합 /5달 / 밤 조도·가로등·광원 상한 / 젖은 반사 공유 / 렌즈 강수·수명·접근성: ", "PASS" if failures == 0 else "FAIL")
	return failures
