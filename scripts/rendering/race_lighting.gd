extends RefCounted
# 하늘·안개·주광·보조광. 코스별 고정 조명과 투어 지역·날씨에 따른 전환을 맡는다.
var race: Node3D


func _init(owner: Node3D) -> void:
	race = owner


func setup() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	race.atmosphere = env
	var sky_material := ProceduralSkyMaterial.new()
	race.sky_colors = sky_material
	sky_material.sky_top_color = Color("438cce")
	sky_material.sky_horizon_color = Color("cce5e9")
	sky_material.ground_bottom_color = Color("688370")
	sky_material.ground_horizon_color = Color("c3d9db")
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5cce0")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.fog_enabled = true
	env.fog_light_color = Color("b3d3df")
	env.fog_density = 0.00065
	env.fog_sky_affect = 0
	world.environment = env
	race.add_child(world)
	var sun := DirectionalLight3D.new()
	race.sun_light = sun
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	race.add_child(sun)
	race.rim_light = DirectionalLight3D.new()
	race.rim_light.rotation_degrees = Vector3(-18, 145, 0)
	race.rim_light.light_color = Color("a1bce8")
	race.rim_light.light_energy = 0.10
	race.rim_light.shadow_enabled = false
	race.rim_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	race.add_child(race.rim_light)


# 코스를 바꾼 직후의 고정 조명. 하늘은 실제로 렌더할 때 race.gd가 만든다.
func apply_course() -> void:
	race.atmosphere.sky = null
	race.rim_light.light_color = Color.WHITE
	if race.track_environment.supported(race):
		race.track_environment.apply_lighting(race)
		preload("res://scripts/rendering/neon_style.gd").apply(race)
		return
	race.visual_theme = ""
	race.sun_light.rotation_degrees = Vector3(-42, -32, 0)
	race.sun_light.light_color = Color("fff0d4")
	race.sun_light.light_energy = .95
	race.atmosphere.ambient_light_color = Color("b5cce0")
	race.atmosphere.ambient_light_energy = .35
	race.atmosphere.tonemap_exposure = .88
	race.atmosphere.fog_light_color = Color("b3d3df")
	race.atmosphere.fog_density = .00065
	race.rim_light.light_energy = .10


func update(delta: float) -> void:
	if race.track_environment.supported(race):
		race.track_environment.update(race, delta)
		return
	var theme_id: String = race.track.scenery.theme
	var region: Dictionary = race.track.active.region_metadata
	var mood_key: String = theme_id + str(region.get("weather", "clear")) + str(region.get("time_of_day", "day"))
	if race.visual_theme != mood_key:
		race.visual_theme = mood_key
		race.atmosphere_transition = 3.0
		preload("res://scripts/rendering/neon_style.gd").apply(race)
	if race.atmosphere_transition <= 0:
		return
	var profile := {
		"top": Color("438cce"),
		"horizon": Color("cce5e9"),
		"fog": Color("b3d3df"),
		"sun": 0.95,
		"ambient": 0.35,
		"sun_color": Color("fff0d4")
	}
	match theme_id:
		"neon":
			profile.merge(
				{
					"top": Color("16121d"),
					"horizon": Color("493039"),
					"fog": Color("30232d"),
					"sun": 0.16,
					"ambient": 0.34,
					"sun_color": Color("f3d5b3")
				},
				true
			)
		"snow":
			profile.merge(
				{
					"top": Color("90b9d4"),
					"horizon": Color("e6eff6"),
					"fog": Color("dbe5ec"),
					"sun": 0.8,
					"ambient": 0.45,
					"sun_color": Color("e9f0ff")
				},
				true
			)
		"volcano":
			profile.merge(
				{
					"top": Color("8a655e"),
					"horizon": Color("bc8265"),
					"fog": Color("8b635a"),
					"sun": 0.7,
					"ambient": 0.4,
					"sun_color": Color("ffd2aa")
				},
				true
			)
		"canyon":
			profile.merge(
				{"top": Color("ad927e"), "horizon": Color("f2cc8e"), "fog": Color("bfb190"), "sun": 0.9}, true
			)
		"harbor":
			profile.merge(
				{
					"top": Color("587e97"),
					"horizon": Color("b6ccda"),
					"fog": Color("96b1c1"),
					"sun": 0.8,
					"ambient": 0.4
				},
				true
			)
		"bamboo":
			profile.merge(
				{"top": Color("6d9f99"), "horizon": Color("c0d3b6"), "fog": Color("90b1a4"), "sun": 0.8}, true
			)
	var weather: String = region.get("weather", "clear")
	var period: String = region.get("time_of_day", "day")
	if period == "night":
		profile.merge(
			{
				"top": Color("101027"),
				"horizon": Color("383456"),
				"fog": Color("292a46"),
				"sun": .12,
				"ambient": .5,
				"sun_color": Color("b7c4ef")
			},
			true
		)
	if period == "dawn":
		profile.merge({"sun": .62, "ambient": .38, "sun_color": Color("edd7c7")}, true)
	if weather == "rain":
		profile.merge(
			{
				"top": Color("52616b"),
				"horizon": Color("98a6ac"),
				"fog": Color("82959f"),
				"sun": .3,
				"ambient": .48,
				"sun_color": Color("beced8")
			},
			true
		)
	if weather == "sand":
		profile.merge({"fog": Color("c4ad82"), "sun_color": Color("f0d2a3")}, true)
	race.atmosphere.fog_density = (
		.001 if weather == "sand" else (.0008 if weather == "rain" else (.0005 if weather == "snow" else .00035))
	)
	var blend := 1.0 if delta >= race.atmosphere_transition else 1 - exp(-delta * 2)
	race.sky_colors.sky_top_color = race.sky_colors.sky_top_color.lerp(profile.top, blend)
	race.sky_colors.sky_horizon_color = race.sky_colors.sky_horizon_color.lerp(profile.horizon, blend)
	race.atmosphere.fog_light_color = race.atmosphere.fog_light_color.lerp(profile.fog, blend)
	race.atmosphere.ambient_light_energy = lerpf(race.atmosphere.ambient_light_energy, profile.ambient, blend)
	race.sun_light.light_energy = lerpf(race.sun_light.light_energy, profile.sun, blend)
	race.sun_light.light_color = race.sun_light.light_color.lerp(profile.sun_color, blend)
	race.rim_light.light_energy = lerpf(race.rim_light.light_energy, 0.035 if theme_id == "neon" else 0.10, blend)
	race.atmosphere_transition = maxf(0, race.atmosphere_transition - delta)
