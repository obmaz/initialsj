extends Node3D
const Track = preload("res://scripts/track.gd")
const Car = preload("res://scripts/car.gd")
const HUD = preload("res://scripts/hud.gd")
const Library = preload("res://scripts/route_library.gd")
const Contact = preload("res://scripts/car_contact.gd")
const Brain = preload("res://scripts/rival_brain.gd")
const RECORD_GROUP := "coast_rush_v2"
var brain := Brain.new()
var track: Track
var player: Car
var atmosphere: Environment
var sky_colors: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var visual_theme := "hawaii"
var atmosphere_transition := 0.0
var camera: Camera3D
var hud: HUD
var speed_effect: ColorRect
var tire_trails: Node3D
var speed_ambience: Node3D
var impacts: Node3D
var rivals: Array[Dictionary] = []
var state := "ready"
var distance := 80.0
var completed_distance := 0.0
var lane := -3.2
var speed := 0.0
var lane_velocity := 0.0
var steer := 0.0
var slip_angle := 0.0
var elapsed := 0.0
var countdown := 3.0
var time_left := Library.START_TIME
var score := 0.0
var throttling := false
var braking := false
var drifting := false
var boosting := false
var nitro := 70.0
var nitro_active := false
var nitro_locked := false
var nitro_seconds := 0.0
var checkpoint_award := Library.CHECKPOINT_BONUS
var drift_latched := false
var drift_sign := 0.0
var drift_straight := 0.0
var drift_charge := 0.0
var drifts_completed := 0
var brake_armed := 0.0
var previous_brake := false
var draft_charge := 0.0
var drafting := false
var recommended_speed := 80.0
var corner_warning := 0.0
var near_misses := 0
var near_miss_flash := 0.0
var overtakes := 0
var overtake_flash := 0.0
var checkpoint_flash := 0.0
var checkpoints := 0
var wall_hits := 0
var traffic_hits := 0
var impact := 0.0
var boost_kick := 0.0
var bump_cooldown := 0.0
var launch_flash := 0.0
var motion_reduced := false
var sound_enabled := true
var camera_time := 0.0
var camera_offset := Vector3.ZERO
var best_time := 0.0
var save_records := true
var stage_index: int:
	get: return track.active.stage
var route_node: int:
	get: return track.active.route_node
var journey_distance: float:
	get: return completed_distance + distance - 80

func _ready() -> void:
	track = Track.new()
	add_child(track)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	atmosphere = env
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_colors = sky_material
	sky_material.sky_top_color = Color("438cce")
	sky_material.sky_horizon_color = Color("cce5e9")
	sky_material.ground_bottom_color = Color("688370")
	sky_material.ground_horizon_color = Color("c3d9db")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9e6ea")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("b3d3df")
	env.fog_density = 0.00065
	env.fog_sky_affect = 0
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	add_child(sun)
	tire_trails = preload("res://scripts/tire_trails.gd").new()
	add_child(tire_trails)
	speed_ambience = preload("res://scripts/speed_ambience.gd").new()
	add_child(speed_ambience)
	impacts = preload("res://scripts/impact_effect.gd").new()
	add_child(impacts)
	player = Car.new()
	player.model = "ae86"
	player.paint = Color("f0f1ed")
	add_child(player)
	var colors := ["e7c456","91aabe","aaa3b7","e8e5dc","4c9c97","ad6f55","62798c"]
	for i in range(16):
		var car := Car.new()
		car.traffic = true
		car.paint = Color(colors[i % colors.size()])
		add_child(car)
		rivals.append({"car":car})
	brain.initialize(rivals)
	camera = Camera3D.new()
	camera.far = 1800
	camera.fov = 68
	add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	speed_effect = ColorRect.new()
	speed_effect.visible = false
	speed_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://shaders/speed_blur.gdshader")
	speed_effect.material = effect
	canvas.add_child(speed_effect)
	hud = HUD.new()
	hud.race = self
	canvas.add_child(hud)
	if DisplayServer.get_name() != "headless":
		var audio = preload("res://scripts/racing_audio.gd").new()
		audio.race = self
		add_child(audio)
		if OS.has_feature("web"):
			motion_reduced = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
	var saved := ConfigFile.new()
	if saved.load("user://records.cfg") == OK: best_time = float(saved.get_value(RECORD_GROUP,"best_time",0))
	place_cars()
	update_camera(1)

func restart() -> void:
	if state != "ready": track.reset()
	distance = 80
	completed_distance = 0
	lane = -3.2
	speed = 0
	lane_velocity = 0
	steer = 0
	slip_angle = 0
	elapsed = 0
	countdown = 3
	time_left = Library.START_TIME
	score = 0
	throttling = false
	braking = false
	drifting = false
	boosting = false
	nitro = 70
	nitro_active = false
	nitro_locked = false
	nitro_seconds = 0
	checkpoint_award = Library.CHECKPOINT_BONUS
	drift_latched = false
	drift_sign = 0
	drift_straight = 0
	drift_charge = 0
	drifts_completed = 0
	brake_armed = 0
	previous_brake = false
	draft_charge = 0
	drafting = false
	near_misses = 0
	near_miss_flash = 0
	overtakes = 0
	overtake_flash = 0
	checkpoint_flash = 0
	checkpoints = 0
	wall_hits = 0
	traffic_hits = 0
	impact = 0
	boost_kick = 0
	bump_cooldown = 0
	launch_flash = 0
	camera_offset = Vector3.ZERO
	state = "countdown"
	brain.initialize(rivals)
	tire_trails.reset()
	place_cars()
	update_camera(1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and state in ["ready","finished","failed"]: restart()
		elif event.keycode == KEY_V: sound_enabled = not sound_enabled
		elif event.keycode == KEY_M: motion_reduced = not motion_reduced
		elif event.keycode == KEY_R: restart()
		elif event.keycode in [KEY_ESCAPE,KEY_P]:
			if state == "racing": state = "paused"
			elif state == "paused": state = "racing"
	if event is InputEventScreenTouch or event is InputEventMouseButton: hud.handle_pointer(event)
	if event is InputEventScreenDrag: hud.move_pointer(event.index,event.position)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): hud.move_pointer(-1,event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "racing":
		state = "paused"
		hud.fingers.clear()

func _physics_process(delta: float) -> void:
	update_atmosphere(delta)
	if state == "countdown":
		countdown -= delta
		if countdown <= 0:
			state = "racing"
			launch_flash = 0.7
	if state == "racing":
		var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		axis = clampf(axis + hud.touch_axis(),-1,1)
		var nitro_input := Input.is_physical_key_pressed(KEY_SHIFT) or hud.held("nitro")
		var gas := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or hud.held("gas") or nitro_input
		var brake := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or hud.held("brake")
		step(delta,axis,Input.is_physical_key_pressed(KEY_SPACE) or hud.held("drift"),gas,brake,nitro_input)
	place_cars(delta)
	tire_trails.update(self)
	speed_ambience.update(self)
	speed_effect.visible = state == "racing" and not motion_reduced and speed > 35
	speed_effect.material.set_shader_parameter("strength",clampf((speed-35)/53,0,1))
	update_camera(delta)
	player.road_speed = speed if state == "racing" else 0.0
	player.animate(steer,drifting and state == "racing",nitro_active and state == "racing",delta,slip_angle,braking and state == "racing",impact)
	if player.headlight != null: player.headlight.visible = track.active.in_tunnel(distance) or track.scenery.theme == "neon"
	for r in rivals:
		r.car.road_speed = r.speed if state == "racing" else 0.0
		r.car.animate(clampf((r.target_lane-r.lane)/2,-1,1),false,false,delta,r.visual_yaw)
	hud.queue_redraw()

func step(delta: float, axis: float, drift_input: bool, gas: bool, brake: bool, nitro_input: bool = false) -> void:
	elapsed += delta
	time_left = maxf(0,time_left-delta)
	for field in ["near_miss_flash","overtake_flash","checkpoint_flash","launch_flash"]:
		set(field,maxf(0,float(get(field))-delta))
	impact = maxf(0,impact-delta*3.5)
	boost_kick = maxf(0,boost_kick-delta*2)
	bump_cooldown = maxf(0,bump_cooldown-delta)
	brake_armed = maxf(0,brake_armed-delta)
	throttling = gas and not brake
	braking = brake
	steer = move_toward(steer,axis,delta*6.5)
	if brake and not previous_brake and speed > 25: brake_armed = 0.45
	var was_drifting := drifting
	if not brake and speed > 25 and absf(steer) > 0.2 and (drift_input or (previous_brake and brake_armed > 0 and gas)):
		if not drift_latched: drift_sign = signf(steer)
		drift_latched = true
	if brake or speed < 22: drift_latched = false
	var curve := track.curvature(distance)
	if drift_latched and absf(curve) < 0.0008 and absf(steer) < 0.14:
		drift_straight += delta
		if drift_straight > 0.4: drift_latched = false
	else: drift_straight = 0
	drifting = drift_latched
	previous_brake = brake
	if drifting: drift_charge = minf(3,drift_charge+delta)
	elif was_drifting:
		if drift_charge > 0.55 and absf(lane) < track.half_width(distance)-1:
			drifts_completed += 1
		drift_charge = 0
	var desired_yaw := (-drift_sign*0.30-steer*0.30) if drifting else -steer*0.07
	slip_angle = lerp_angle(slip_angle,desired_yaw,1-exp(-delta*6))
	var old_gaps: Array[float] = []
	drafting = false
	for r in rivals:
		var gap: float = r.distance-distance
		old_gaps.append(gap)
		if r.active and r.detached == null and gap > 8 and gap < 75 and absf(r.lane-lane) < 2.1: drafting = true
	draft_charge = move_toward(draft_charge,1.0 if drafting else 0.0,delta*(1.0 if drafting else 1.2))
	if nitro <= 0: nitro_locked = true
	if nitro >= 12: nitro_locked = false
	nitro_active = nitro_input and throttling and not drifting and speed > 25 and nitro > 0 and not nitro_locked and impact < 0.15
	if nitro_active:
		nitro = maxf(0,nitro-delta*20)
		nitro_seconds += delta
	else:
		nitro = minf(100,nitro+delta*(8 if drifting else 3))
	var was_boosting := boosting
	boosting = nitro_active or (draft_charge > 0.65 and throttling and not drifting)
	if boosting and not was_boosting: boost_kick = 0.35
	if brake: speed = move_toward(speed,0,delta*44)
	elif not gas: speed = move_toward(speed,0,delta*5)
	elif drifting: speed = maxf(0,speed-delta*0.35)
	else: speed = move_toward(speed,96 if nitro_active else 80+draft_charge*8,delta*(34 if nitro_active else 22))
	var grip := 24.0 if drifting else 11.5
	var demand := absf(curve) * speed * speed
	var excess := maxf(0,demand-grip)
	var authority := clampf(1-excess/(grip*2),0.38,1)
	var outward := signf(curve) * (demand * 0.055 + excess * 1.6)
	var lateral := steer * (10.8 if drifting else 8.0) * minf(speed/20,1) * authority + outward
	lane_velocity = move_toward(lane_velocity,lateral,delta*(17 if drifting else 34))
	lane += lane_velocity*delta
	var limits := track.lane_limits(distance)
	var radius := Contact.HALF_WIDTH * absf(cos(slip_angle)) + Contact.HALF_LENGTH * absf(sin(slip_angle))
	limits += Vector2(radius-Contact.HALF_WIDTH,-radius+Contact.HALF_WIDTH)
	var margin := minf(lane-limits.x,limits.y-lane)
	if margin < 1.0: speed = move_toward(speed,minf(speed,38),delta*32)
	if lane < limits.x or lane > limits.y:
		var side := -1.0 if lane < limits.x else 1.0
		lane = clampf(lane,limits.x,limits.y)
		lane_velocity *= -0.28
		if bump_cooldown <= 0:
			wall_hits += 1
			speed *= 0.72
			register_impact(0.8,Vector2(-side,0))
	distance += speed*delta
	brain.tick(self,delta)
	for i in range(rivals.size()):
		var r: Dictionary = rivals[i]
		if not r.active or r.detached != null: continue
		var gap: float = r.distance-distance
		if absf(gap) > 8: continue
		var forward := (track.point(distance+2)-track.point(distance)).normalized()
		var right := Vector3(-forward.z,0,forward.x).normalized()
		var other_world := track.traffic_point(r.distance,r.lane,r.route_side)
		var relative_world := other_world-track.point(distance,lane)
		var lateral_gap := relative_world.dot(right)
		var other_forward := track.traffic_point(r.distance+2,r.lane,r.route_side)-other_world
		var other_yaw := wrapf(atan2(-other_forward.x,-other_forward.z)-track.heading(distance),-PI,PI)
		other_yaw += r.visual_yaw
		var contact := Contact.overlap(relative_world.dot(forward),lateral_gap,slip_angle,other_yaw)
		if old_gaps[i] > 0 and gap <= 0:
			overtakes += 1
			overtake_flash = 1
			score += 100
			if contact.is_empty() and absf(lateral_gap) < 3.8:
				near_misses += 1
				near_miss_flash = 1.1
				nitro = minf(100,nitro+12)
				score += 150
		if not contact.is_empty(): resolve_contact(r,contact)
	if drifting and margin > 1 and impact < 0.1:
		score += delta * speed * (2.0+drift_charge)
	recommended_speed = 80
	for look in [15.0,45.0,85.0]:
		var k: float = absf(track.curvature(distance+look))
		recommended_speed = minf(recommended_speed,sqrt(15.0/maxf(k,0.0001)))
	corner_warning = move_toward(corner_warning,clampf((speed-recommended_speed-4)/15,0,1),delta*3)
	var reconsidered := track.reconsider(distance,lane)
	if not reconsidered.is_empty():
		var old_section = track.sibling
		distance = reconsidered.distance
		lane = reconsidered.lane
		for r in rivals:
			if r.detached == track.active: r.detached = null
			elif r.detached == null and r.distance > 0: r.detached = old_section
		var corrected_bonus := Library.checkpoint_bonus(route_node)
		time_left += corrected_bonus-checkpoint_award
		checkpoint_award = corrected_bonus
		brain.stage_changed(self)
	track.maintain(distance)
	if stage_index == Library.STAGES-1 and distance >= track.length:
		finish()
	elif stage_index < Library.STAGES-1 and distance >= track.length+Library.FORK_COMMIT:
		advance_route()
	if time_left <= 0 and state != "finished":
		state = "failed"
		nitro_active = false
		drifting = false
		boosting = false

func advance_route() -> void:
	var choice := 0 if lane < 0 else 1
	var result := track.advance(choice,distance,lane)
	completed_distance += result.old_length
	distance = result.distance
	lane = result.lane
	for r in rivals:
		if r.detached != null: continue
		r.distance -= result.old_length
		if r.distance > 20 and r.route_side != choice: r.detached = result.sibling
	checkpoints += 1
	checkpoint_flash = 2
	checkpoint_award = Library.checkpoint_bonus(route_node)
	time_left += checkpoint_award
	nitro = minf(100,nitro+25)
	brain.stage_changed(self)

func finish() -> void:
	state = "finished"
	nitro_active = false
	drifting = false
	boosting = false
	score += int(time_left)*100
	if best_time == 0 or elapsed < best_time:
		best_time = elapsed
		if save_records:
			var saved := ConfigFile.new()
			saved.load("user://records.cfg")
			saved.set_value(RECORD_GROUP,"best_time",best_time)
			saved.save("user://records.cfg")

func contact_with(r: Dictionary) -> Dictionary:
	var forward := (track.point(distance+2)-track.point(distance)).normalized()
	var right := Vector3(-forward.z,0,forward.x).normalized()
	var other := track.traffic_point(r.distance,r.lane,r.route_side)
	var delta := other-track.point(distance,lane)
	var direction := track.traffic_point(r.distance+2,r.lane,r.route_side)-other
	var yaw := wrapf(atan2(-direction.x,-direction.z)-track.heading(distance),-PI,PI)+float(r.visual_yaw)
	return Contact.overlap(delta.dot(forward),delta.dot(right),slip_angle,yaw)

func resolve_contact(r: Dictionary, contact: Dictionary) -> void:
	var normal: Vector2 = contact.normal
	for iteration in range(5):
		var depth: float = contact.depth + 0.02
		var n: Vector2 = contact.normal
		var old_lane := lane
		var radius := Contact.HALF_WIDTH*absf(cos(slip_angle))+Contact.HALF_LENGTH*absf(sin(slip_angle))
		var limits := track.lane_limits(distance)+Vector2(radius-Contact.HALF_WIDTH,-radius+Contact.HALF_WIDTH)
		lane = clampf(lane-n.x*depth*0.6,limits.x,limits.y)
		distance += n.y*depth*0.6
		var traffic_edge: float = track.half_width(r.distance)
		r.lane = clampf(r.lane+n.x*depth+(lane-old_lane),-traffic_edge,traffic_edge)
		r.distance -= n.y*depth*0.4
		contact = contact_with(r)
		if contact.is_empty(): break
	if bump_cooldown > 0: return
	var relative := speed-float(r.speed)
	if absf(normal.x) > 0.65:
		speed *= 0.87
		r.speed *= 0.91
	else:
		var impulse := absf(relative) * 0.6
		if normal.y < 0:
			speed = maxf(0,speed-impulse-4)
			r.speed = minf(70,r.speed+impulse*0.35)
		else:
			speed = minf(88,speed+minf(5,impulse*0.3))
			r.speed = maxf(0,r.speed-impulse)
	lane_velocity -= normal.x*(3+absf(relative)*0.12)
	traffic_hits += 1
	register_impact(clampf(absf(relative)/35+absf(lane_velocity)/15,0.3,1),-normal)

func register_impact(strength: float, normal: Vector2) -> void:
	impact = maxf(impact,strength)
	nitro_active = false
	drift_charge = 0
	drift_latched = false
	bump_cooldown = 0.45
	if DisplayServer.get_name() != "headless":
		var f := (track.point(distance+2)-track.point(distance)).normalized()
		var right := Vector3(-f.z,0,f.x)
		impacts.burst(track.point(distance,lane) + Vector3.UP*0.65 - right*normal.x*1.25 + f*normal.y*2.0, right*normal.x-f*normal.y,motion_reduced)

func place_cars(delta: float = 1.0) -> void:
	set_car_frame(player,track.point(distance,lane),track.point(distance+2,lane)-track.point(distance-2,lane),delta)
	player.body.rotation.y = slip_angle
	for r in rivals:
		if not r.active:
			r.car.visible = false
			continue
		var p: Vector3
		var f: Vector3
		if r.detached != null and is_instance_valid(r.detached):
			p = r.detached.point(r.distance,r.lane)
			f = r.detached.point(r.distance+2,r.lane)-r.detached.point(r.distance-2,r.lane)
		else:
			p = track.traffic_point(r.distance,r.lane,r.route_side)
			f = track.traffic_point(r.distance+2,r.lane,r.route_side)-track.traffic_point(r.distance-2,r.lane,r.route_side)
		set_car_frame(r.car,p,f,delta)
		r.car.body.rotation.y = r.visual_yaw
		var gap := p.distance_to(player.position)
		r.car.visible = gap < 460
		r.car.set_detail(gap)

func set_car_frame(car: Node3D, p: Vector3, forward: Vector3, delta: float) -> void:
	car.position = p + Vector3.UP*0.12
	var f := forward.normalized()
	car.rotation.y = lerp_angle(car.rotation.y,atan2(-f.x,-f.z),1-exp(-delta*13))
	car.rotation.x = lerp_angle(car.rotation.x,asin(clampf(f.y,-1,1)),1-exp(-delta*10))

func update_camera(delta: float) -> void:
	var forward := (track.point(distance+3)-track.point(distance)).normalized()
	var right := Vector3(-forward.z,0,forward.x)
	var pace := clampf(speed/88,0,1)
	var active := state == "racing"
	camera_time += delta if active else 0
	var shake := (0.012*pace*pace + impact*0.24) if active and not motion_reduced else 0.0
	var vibration := right*sin(camera_time*53)*shake + Vector3.UP*cos(camera_time*67)*shake*0.55
	var desired := -forward*(5.3+pace*0.25+(boost_kick*0.55 if not motion_reduced else 0.0)-(0.25 if braking else 0.0)) + Vector3.UP*(2.75-pace*0.30) + vibration
	if drifting and not motion_reduced: desired += right*steer*0.9
	camera_offset = camera_offset.lerp(desired,1-exp(-delta*9))
	camera.position = player.position+camera_offset
	camera.look_at(player.position+forward*(2.5+pace*0.8)+right*steer*(0 if motion_reduced else 0.7)+Vector3.UP*0.7)
	if not motion_reduced: camera.rotate_object_local(Vector3.FORWARD,-steer*pace*(0.024 if drifting else 0.01))
	var target_fov := (68.0 if motion_reduced else 64+pace*17) + (6 if boosting and active and not motion_reduced else 0)
	camera.fov = lerpf(camera.fov,target_fov,1-exp(-delta*(8 if boosting else 4)))

func update_atmosphere(delta: float) -> void:
	var theme_id: String = track.scenery.theme
	if visual_theme != theme_id:
		visual_theme = theme_id
		atmosphere_transition = 3.0
	if atmosphere_transition <= 0: return
	var profile := {"top":Color("438cce"),"horizon":Color("cce5e9"),"fog":Color("b3d3df"),"sun":0.95,"ambient":0.35,"sun_color":Color("fff0d4")}
	match theme_id:
		"neon": profile.merge({"top":Color("101027"),"horizon":Color("383456"),"fog":Color("292a46"),"sun":0.12,"ambient":0.5,"sun_color":Color("b7c4ef")},true)
		"snow": profile.merge({"top":Color("90b9d4"),"horizon":Color("e6eff6"),"fog":Color("dbe5ec"),"sun":0.8,"ambient":0.45,"sun_color":Color("e9f0ff")},true)
		"volcano": profile.merge({"top":Color("8a655e"),"horizon":Color("bc8265"),"fog":Color("8b635a"),"sun":0.7,"ambient":0.4,"sun_color":Color("ffd2aa")},true)
		"canyon": profile.merge({"top":Color("ad927e"),"horizon":Color("f2cc8e"),"fog":Color("bfb190"),"sun":0.9},true)
		"harbor": profile.merge({"top":Color("587e97"),"horizon":Color("b6ccda"),"fog":Color("96b1c1"),"sun":0.8,"ambient":0.4},true)
		"bamboo": profile.merge({"top":Color("6d9f99"),"horizon":Color("c0d3b6"),"fog":Color("90b1a4"),"sun":0.8},true)
	var blend := 1.0 if delta >= atmosphere_transition else 1-exp(-delta*2)
	sky_colors.sky_top_color = sky_colors.sky_top_color.lerp(profile.top,blend)
	sky_colors.sky_horizon_color = sky_colors.sky_horizon_color.lerp(profile.horizon,blend)
	atmosphere.fog_light_color = atmosphere.fog_light_color.lerp(profile.fog,blend)
	atmosphere.ambient_light_energy = lerpf(atmosphere.ambient_light_energy,profile.ambient,blend)
	sun_light.light_energy = lerpf(sun_light.light_energy,profile.sun,blend)
	sun_light.light_color = sun_light.light_color.lerp(profile.sun_color,blend)
	atmosphere_transition = maxf(0,atmosphere_transition-delta)
