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
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	race.add_child(sun)
	race.rim_light = DirectionalLight3D.new()
	race.rim_light.rotation_degrees = Vector3(-18,145,0)
	race.rim_light.light_color = Color("a1bce8")
	race.rim_light.light_energy = 0.10
	race.rim_light.shadow_enabled = false
	race.rim_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	race.add_child(race.rim_light)

# 코스를 바꾼 직후의 고정 조명. 하늘은 실제로 렌더할 때 race.gd가 만든다.
func apply_course() -> void:
	race.atmosphere.sky = null
	race.rim_light.light_color = Color.WHITE
	if race.mode == "track":
		if race.selected_course == 2:
			# Night: a dim cool moon, deep blue ambient light and dark blue haze.
			race.atmosphere.fog_light_color = Color("0c1a30")
			race.atmosphere.fog_density = 0.0016
			race.atmosphere.ambient_light_color = Color("5a78b8")
			race.atmosphere.ambient_light_energy = 0.55
			race.atmosphere.tonemap_exposure = 1.0
			race.sun_light.rotation_degrees = Vector3(-38,150,0)
			race.sun_light.light_energy = 0.32
			race.sun_light.light_color = Color("a8c0ff")
			race.rim_light.light_energy = 0.18
		else:
			race.atmosphere.fog_light_color = Color("b3d3df")
			race.atmosphere.fog_density = 0.00065
			race.atmosphere.ambient_light_color = Color("b5cce0")
			race.atmosphere.tonemap_exposure = 0.88
			race.sun_light.rotation_degrees = Vector3(-42,-32,0)
			race.sun_light.light_energy = 1.0
			race.sun_light.light_color = Color("ffe4be")
			race.rim_light.light_energy = 0.10
			race.atmosphere.ambient_light_energy = 0.28
		if race.selected_course in [3,4]:
			race.atmosphere.fog_light_color = Color("87bdcf")
			race.atmosphere.fog_density = 0.00022
			race.atmosphere.tonemap_exposure = 0.76
			race.sun_light.light_energy = 0.85
		if race.selected_course == 4:
			# 파노라마 태양 U=.65,V=.49와 같은 방위·낮은 고도의 주광을 고정한다.
			race.sun_light.rotation_degrees = Vector3(-5,54,0)
			race.sun_light.light_color = Color("ffbf82")
			race.sun_light.light_energy = .78
			race.atmosphere.ambient_light_color = Color("899ec5")
			race.atmosphere.ambient_light_energy = .38
			race.atmosphere.fog_light_color = Color("bd9fa8")
			race.atmosphere.fog_density = .00038
			race.atmosphere.tonemap_exposure = .9
			race.rim_light.light_color = Color("a2b6db")
			race.rim_light.light_energy = .14
	else:
		race.visual_theme = ""

func update(delta: float) -> void:
	if race.mode == "track" and race.selected_course == 2:
		# The moon stays low in the sky ahead and slightly to the left, whichever way the road turns.
		var look: Vector3 = -race.camera.global_transform.basis.z
		look.y = 0
		if look.length_squared() > 0.01 and race.atmosphere.sky != null and race.atmosphere.sky.sky_material is ShaderMaterial:
			var heading := look.normalized().rotated(Vector3.UP,deg_to_rad(24))
			(race.atmosphere.sky.sky_material as ShaderMaterial).set_shader_parameter("moon_direction",Vector3(heading.x,0.115,heading.z))
		return
	if race.mode == "track" and race.selected_course == 4: return
	if race.mode == "track":
		var sheltered: bool = race.track.active.in_tunnel(race.distance)
		var blend := 1-exp(-delta*3)
		race.atmosphere.ambient_light_energy = lerpf(race.atmosphere.ambient_light_energy,0.12 if sheltered else 0.28,blend)
		race.rim_light.light_energy = lerpf(race.rim_light.light_energy,0.025 if sheltered else 0.10,blend)
		return
	var theme_id: String = race.track.scenery.theme
	var region: Dictionary = race.track.active.region_metadata
	var mood_key: String = theme_id+str(region.get("weather","clear"))+str(region.get("time_of_day","day"))
	if race.visual_theme != mood_key:
		race.visual_theme = mood_key
		race.atmosphere_transition = 3.0
	if race.atmosphere_transition <= 0: return
	var profile := {"top":Color("438cce"),"horizon":Color("cce5e9"),"fog":Color("b3d3df"),"sun":0.95,"ambient":0.35,"sun_color":Color("fff0d4")}
	match theme_id:
		"neon": profile.merge({"top":Color("101027"),"horizon":Color("383456"),"fog":Color("292a46"),"sun":0.12,"ambient":0.5,"sun_color":Color("b7c4ef")},true)
		"snow": profile.merge({"top":Color("90b9d4"),"horizon":Color("e6eff6"),"fog":Color("dbe5ec"),"sun":0.8,"ambient":0.45,"sun_color":Color("e9f0ff")},true)
		"volcano": profile.merge({"top":Color("8a655e"),"horizon":Color("bc8265"),"fog":Color("8b635a"),"sun":0.7,"ambient":0.4,"sun_color":Color("ffd2aa")},true)
		"canyon": profile.merge({"top":Color("ad927e"),"horizon":Color("f2cc8e"),"fog":Color("bfb190"),"sun":0.9},true)
		"harbor": profile.merge({"top":Color("587e97"),"horizon":Color("b6ccda"),"fog":Color("96b1c1"),"sun":0.8,"ambient":0.4},true)
		"bamboo": profile.merge({"top":Color("6d9f99"),"horizon":Color("c0d3b6"),"fog":Color("90b1a4"),"sun":0.8},true)
	var weather: String = region.get("weather","clear")
	var period: String = region.get("time_of_day","day")
	if period == "night": profile.merge({"top":Color("101027"),"horizon":Color("383456"),"fog":Color("292a46"),"sun":.12,"ambient":.5,"sun_color":Color("b7c4ef")},true)
	if period == "dawn": profile.merge({"sun":.62,"ambient":.38,"sun_color":Color("edd7c7")},true)
	if weather == "rain": profile.merge({"top":Color("52616b"),"horizon":Color("98a6ac"),"fog":Color("82959f"),"sun":.3,"ambient":.48,"sun_color":Color("beced8")},true)
	if weather == "sand": profile.merge({"fog":Color("c4ad82"),"sun_color":Color("f0d2a3")},true)
	race.atmosphere.fog_density = .001 if weather == "sand" else (.0008 if weather == "rain" else (.0005 if weather == "snow" else .00035))
	var blend := 1.0 if delta >= race.atmosphere_transition else 1-exp(-delta*2)
	race.sky_colors.sky_top_color = race.sky_colors.sky_top_color.lerp(profile.top,blend)
	race.sky_colors.sky_horizon_color = race.sky_colors.sky_horizon_color.lerp(profile.horizon,blend)
	race.atmosphere.fog_light_color = race.atmosphere.fog_light_color.lerp(profile.fog,blend)
	race.atmosphere.ambient_light_energy = lerpf(race.atmosphere.ambient_light_energy,profile.ambient,blend)
	race.sun_light.light_energy = lerpf(race.sun_light.light_energy,profile.sun,blend)
	race.sun_light.light_color = race.sun_light.light_color.lerp(profile.sun_color,blend)
	race.rim_light.light_energy = lerpf(race.rim_light.light_energy,0.035 if theme_id == "neon" else 0.10,blend)
	race.atmosphere_transition = maxf(0,race.atmosphere_transition-delta)
