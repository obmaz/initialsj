extends RefCounted
# 선택값은 전 트랙 공용, 활성값은 경기 시작 시 고정한다.
const WEATHER := ["clear", "rain"]
const PERIODS := ["day", "dusk", "night"]
var weather := "clear"
var time_of_day := "day"
var active_weather := "clear"
var active_period := "day"
var applied_road_id := 0
var ambient_target := .28
var active_course := 0
const MOON_PHASES := [2.25, 0.0, 1.25, -1.57, -2.5]
const MOON_ROLLS := [-.25, .0, .35, -.55, .75]


func supported(race: Node3D) -> bool:
	return race.mode == "track" and race.selected_course >= 0 and race.selected_course < 5


func read(config: ConfigFile) -> void:
	var saved_weather: Variant = config.get_value("track_environment", "weather", "clear")
	var saved_period: Variant = config.get_value("track_environment", "time_of_day", "day")
	weather = saved_weather if saved_weather in WEATHER else "clear"
	time_of_day = saved_period if saved_period in PERIODS else "day"


func write(config: ConfigFile) -> void:
	config.set_value("track_environment", "weather", weather)
	config.set_value("track_environment", "time_of_day", time_of_day)


func cycle_weather() -> void:
	weather = WEATHER[(WEATHER.find(weather) + 1) % WEATHER.size()]


func cycle_period() -> void:
	time_of_day = PERIODS[(PERIODS.find(time_of_day) + 1) % PERIODS.size()]


func activate(race: Node3D) -> void:
	if not supported(race):
		return
	var changed: bool = (
		applied_road_id != race.track.active.get_instance_id()
		or active_weather != weather
		or active_period != time_of_day
	)
	active_weather = weather
	active_course = race.selected_course
	active_period = time_of_day
	applied_road_id = race.track.active.get_instance_id()
	race.track.active.region_metadata = {"weather": active_weather, "time_of_day": active_period}
	# world_assets가 분리한 코스 인스턴스 재질만 변경한다. 원본·다른 코스에는 전파하지 않는다.
	race.track.active.road_surface.material_override.set_shader_parameter(
		"rain_wetness", 1.0 if active_weather == "rain" else 0.0
	)
	var guide: Node3D = race.track.active.get_node_or_null("RoadsideGuidance")
	if guide != null:
		guide.install_chevrons()
		for node in guide.get_children():
			if node is MultiMeshInstance3D and str(node.name).begins_with("ApproachArrow"):
				node.material_override.set_shader_parameter("night", active_period == "night")
	var fixtures: Node3D = race.track.active.get_node_or_null("CourseLighting")
	if fixtures != null:
		fixtures.configure(race)
	if is_instance_valid(race.tour_weather):
		race.tour_weather.configure(active_weather)
	if changed:
		race.lighting.apply_course()


func lighting_profile() -> Dictionary:
	var period := PERIODS.find(active_period)
	var wet := active_weather == "rain"
	var day_rotations := [
		Vector3(-42, -32, 0), Vector3(-26, -137, 0), Vector3(-38, -95, 0), Vector3(-57, 70, 0), Vector3(-35, 54, 0)
	]
	var dusk_rotations := [
		Vector3(-6, 142, 0), Vector3(-8, -137, 0), Vector3(-7, -95, 0), Vector3(-6, 70, 0), Vector3(-5, 54, 0)
	]
	var night_rotations := [
		Vector3(-20, 142, 0), Vector3(-25, -90, 0), Vector3(-23, 79, 0), Vector3(-22, 55, 0), Vector3(-18, 118, 0)
	]
	var sun_levels := [[1.0, 1.1, .9, .95, .9], [.42, .55, .4, .5, .48], [.045, .12, .09, .10, .07]]
	var ambient_levels := [[.28, .36, .28, .3, .29], [.23, .34, .27, .3, .26], [.11, .24, .18, .19, .15]]
	return {
		"sun": sun_levels[period][active_course] * (.4 if wet else 1.0),
		"ambient": ambient_levels[period][active_course] * (1.08 if wet else 1.0),
		"sun_color": [Color("ffe4be"), Color("ffbd83"), Color("a6bce9")][period],
		"ambient_color": [Color("b5cce0"), Color("7184a8"), Color("6882ae")][period],
		"fog":
		(
			(Color("152033") if period == 2 else Color("7e939d"))
			if wet
			else [Color("b3d3df"), Color("bd9b92"), Color("101d32")][period]
		),
		"density": .0008 if wet else [.00035, .00035, .0005][period],
		"rotation": [day_rotations, dusk_rotations, night_rotations][period][active_course]
	}


func apply_lighting(race: Node3D) -> void:
	var profile := lighting_profile()
	race.sun_light.rotation_degrees = profile.rotation
	race.sun_light.light_energy = profile.sun
	race.sun_light.light_color = profile.sun_color
	race.atmosphere.ambient_light_color = profile.ambient_color
	race.atmosphere.ambient_light_energy = profile.ambient
	ambient_target = profile.ambient
	race.atmosphere.fog_light_color = profile.fog
	race.atmosphere.fog_density = profile.density
	race.atmosphere.tonemap_exposure = .95 if active_period == "night" else .88
	race.rim_light.light_energy = (.025 if active_course == 0 else .055) if active_period == "night" else .1
	race.rim_light.light_color = profile.ambient_color


func update(race: Node3D, delta: float) -> void:
	var sheltered: bool = race.track.active.in_tunnel(race.distance)
	var target := ambient_target
	race.atmosphere.ambient_light_energy = lerpf(
		race.atmosphere.ambient_light_energy, minf(target, .12) if sheltered else target, 1 - exp(-delta * 3)
	)


func configure_sky(race: Node3D) -> void:
	if supported(race) and race.atmosphere.sky != null:
		var material: ShaderMaterial = race.atmosphere.sky.sky_material
		material.set_shader_parameter("environment_period", PERIODS.find(active_period))
		material.set_shader_parameter("rain_amount", 1.0 if active_weather == "rain" else 0.0)
		material.set_shader_parameter("environment_course", active_course)
		material.set_shader_parameter("moon_phase", MOON_PHASES[active_course])
		material.set_shader_parameter("moon_roll", MOON_ROLLS[active_course])
		material.set_shader_parameter("celestial_direction", race.sun_light.basis.z.normalized())
		var road_material: ShaderMaterial = race.track.active.road_surface.material_override
		road_material.set_shader_parameter("wet_panorama", material.get_shader_parameter("panorama"))
		road_material.set_shader_parameter("wet_fuji", active_course == 0)
		road_material.set_shader_parameter("wet_reflection_ready", true)
		road_material.set_shader_parameter("wet_horizon_offset", .12 if active_course == 2 else 0.0)
		if active_course == 0:
			road_material.set_shader_parameter("wet_back_a", material.get_shader_parameter("back_a"))
			road_material.set_shader_parameter("wet_back_b", material.get_shader_parameter("back_b"))
		road_material.set_shader_parameter(
			"wet_sky_tint", [Color(.8, .9, .99), Color(.72, .42, .3), Color(.18, .23, .32)][PERIODS.find(active_period)]
		)
		material.set_shader_parameter(
			"moon_surface",
			preload("res://scripts/rendering/render_resources.gd").fetch("res://assets/environment/moon_surface.png")
		)


func needs_headlights(race: Node3D) -> bool:
	return supported(race) and (active_period != "day" or active_weather == "rain")
