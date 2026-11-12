extends RefCounted
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
		"공용 날씨·시간대 변경은 즉시 저장한다"
	)
	climate.weather = "clear"
	climate.time_of_day = "day"
	race.load_preferences()
	check(climate.weather == "rain" and climate.time_of_day == "dusk", "다음 실행에서 공용 환경 선택을 복원한다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(race.preferences_path))
	race.choose_mode("track", 0)
	var curvature = race.track.curvature_cache
	var night_clear := 0.0
	for weather in ["clear", "rain"]:
		for period in ["day", "dusk", "night"]:
			var old_weather: String = climate.active_weather
			climate.weather = weather
			climate.time_of_day = period
			check(climate.active_weather == old_weather, "설정 선택만으로 진행 중인 경기 환경을 바꾸지 않는다")
			race.restart(false)
			race.warming_world = true
			race.sync_world_rendering()
			race.render_budget.level = 0
			race.state = "racing"
			race.track.visible = true
			race.tour_weather._process(0)
			var material: ShaderMaterial = race.atmosphere.sky.sky_material
			check(
				int(material.get_shader_parameter("environment_period")) == climate.PERIODS.find(period),
				"트랙1 실제 하늘에 활성 시간대를 전달한다"
			)
			check(
				float(material.get_shader_parameter("rain_amount")) == (1.0 if weather == "rain" else 0.0),
				"트랙1 하늘의 비구름을 활성 날씨와 맞춘다"
			)
			check(
				(
					float(race.track.active.road_surface.material_override.get_shader_parameter("rain_wetness"))
					== (1.0 if weather == "rain" else 0.0)
				),
				"비와 젖은 노면은 같은 활성 프리셋을 사용한다"
			)
			check(race.tour_weather.particles.emitting == (weather == "rain"), "트랙1 야외 비 입자가 실제 활성 날씨를 따른다")
			check(climate.headlights(race) == (period != "day" or weather == "rain"), "저녁·밤·비에서는 자동 전조등을 사용한다")
			check(race.track.curvature_cache == curvature, "환경 변경으로 노면·곡률 캐시를 재생성하지 않는다")
			if period == "night":
				if weather == "clear":
					night_clear = race.sun_light.light_energy
				else:
					check(race.sun_light.light_energy < night_clear, "비 오는 밤이 맑은 밤보다 밝아지지 않는다")
	race.render_budget.level = 2
	race.tour_weather._process(0)
	check(race.tour_weather.particles.amount == 90, "트랙 비는 성능 단계에서 입자 예산을 낮춘다")
	var span: Vector2 = race.track.active.underpass_span()
	race.player.global_position = race.track.point((span.x + span.y) / 2)
	race.tour_weather._process(0)
	check(not race.tour_weather.particles.emitting, "후지 지하차도 안에서는 비가 관통하지 않는다")
	for course in range(1, 5):
		race.choose_mode("track", course)
		check(not climate.supported(race), "현재 환경 기능은 트랙1만 활성화한다")
		check(
			float(race.track.active.road_surface.material_override.get_shader_parameter("rain_wetness")) == 0.0,
			"다른 트랙에 젖은 노면 재질이 전파되지 않는다"
		)
	race.choose_mode("tour")
	check(
		(
			race.sun_light.rotation_degrees.is_equal_approx(Vector3(-42, -32, 0))
			and is_equal_approx(race.atmosphere.tonemap_exposure, .88)
		),
		"투어 복귀 시 트랙의 달 방향·노출이 남지 않는다"
	)
	check(not climate.supported(race) and climate.weather == "rain", "투어는 기존 지역 날씨를 유지하고 공용 선택은 보존한다")
	race.free()
	await tree.process_frame
	print("공용 환경 저장·복원 / 트랙1 날씨×시간6조합 / 야간 광량·전조등 / 비 예산·지하차도 / 다른 코스 격리: ", "PASS" if failures == 0 else "FAIL")
	return failures
