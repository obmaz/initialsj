extends Node3D

const Track = preload("res://scripts/track.gd")
const Car = preload("res://scripts/car.gd")
const HUD = preload("res://scripts/hud.gd")
const LAPS := 3
const Brain = preload("res://scripts/rival_brain.gd")
var brain := Brain.new()
var lane_velocity := 0.0
var mini_turbo := 0.0
var drift_charge := 0.0
var draft_charge := 0.0
var drafting := false
var near_misses := 0
var near_miss_flash := 0.0
var impact := 0.0
var boost_kick := 0.0
var motion_reduced := false
var sound_enabled := true
var launch_flash := 0.0
var camera_time := 0.0
var camera_offset := Vector3.ZERO
var track: Track
var player: Car
var camera: Camera3D
var speed_effect: ColorRect
var tire_trails: Node3D
var speed_ambience: Node3D
var hud: HUD
var rivals: Array[Dictionary] = []
var distance := 0.0
var lane := -3.2
var speed := 0.0
var nitro := 100.0
var score := 0.0
var elapsed := 0.0
var countdown := 3.0
var state := "ready"
var drifting := false
var boosting := false
var steer := 0.0
var bump_cooldown := 0.0
var best_time := 0.0
var save_records := true

func _ready() -> void:
	track = Track.new()
	add_child(track)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = track.scenery.make_sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e4eceb")
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("a3c9d7")
	env.fog_density = 0.0003
	env.fog_sky_affect = 0.0
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	add_child(sun)
	tire_trails = preload("res://scripts/tire_trails.gd").new()
	add_child(tire_trails)
	speed_ambience = preload("res://scripts/speed_ambience.gd").new()
	add_child(speed_ambience)
	player = Car.new()
	add_child(player)
	var colors := ["ffc94d", "438aef", "a58aeb", "eee6db", "44bea9", "ee843f", "6c92a1"]
	for i in range(7):
		var car := Car.new()
		car.paint = Color(colors[i])
		add_child(car)
		rivals.append({"car": car, "distance": 10.0 + i * 9.0, "lane": 3.0 if i % 2 == 0 else -3.0, "pace": 47.0 + i * 0.85})
	brain.initialize(rivals)
	camera = Camera3D.new()
	camera.far = 2400
	camera.fov = 68
	add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	speed_effect = ColorRect.new()
	speed_effect.visible = false
	speed_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var effect_material := ShaderMaterial.new()
	effect_material.shader = preload("res://shaders/speed_blur.gdshader")
	speed_effect.material = effect_material
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
	var save := ConfigFile.new()
	if save.load("user://records.cfg") == OK:
		best_time = float(save.get_value("race", "best_time", 0.0))
	place_cars()
	update_camera(1.0)

func restart() -> void:
	distance = 0
	lane = -3.2
	speed = 0
	nitro = 100
	score = 0
	elapsed = 0
	countdown = 3
	launch_flash = 0
	bump_cooldown = 0
	state = "countdown"
	lane_velocity = 0
	mini_turbo = 0
	drift_charge = 0
	draft_charge = 0
	impact = 0
	boost_kick = 0
	steer = 0
	camera_offset = Vector3.ZERO
	drifting = false
	boosting = false
	drafting = false
	near_misses = 0
	near_miss_flash = 0
	tire_trails.reset()
	brain.initialize(rivals)
	for i in range(rivals.size()):
		rivals[i].distance = 10.0 + i * 9.0
	place_cars()
	update_camera(1)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and state in ["ready", "finished"]:
			restart()
		elif event.keycode == KEY_V:
			sound_enabled = not sound_enabled
		elif event.keycode == KEY_M:
			motion_reduced = not motion_reduced
		elif event.keycode == KEY_R:
			restart()
		elif event.keycode in [KEY_ESCAPE, KEY_P]:
			if state == "racing":
				state = "paused"
			elif state == "paused":
				state = "racing"
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		hud.handle_pointer(event)
	if event is InputEventScreenDrag:
		hud.move_pointer(event.index, event.position)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		hud.move_pointer(-1, event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "racing":
		state = "paused"
		hud.fingers.clear()

func _physics_process(delta: float) -> void:
	if state == "countdown":
		countdown -= delta
		if countdown <= 0:
			state = "racing"
			launch_flash = 0.7
	if state == "racing":
		var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		axis = clampf(axis + hud.touch_axis(), -1, 1)
		step(delta, axis, Input.is_physical_key_pressed(KEY_SPACE) or hud.held("drift"), Input.is_physical_key_pressed(KEY_SHIFT) or hud.held("boost"), Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or hud.held("brake"))
	place_cars()
	tire_trails.update(self)
	speed_ambience.update(self)
	speed_effect.visible = state == "racing" and not motion_reduced and speed > 35
	speed_effect.material.set_shader_parameter("strength", clampf((speed - 35) / 53, 0, 1))
	update_camera(delta)
	player.road_speed = speed if state == "racing" else 0.0
	player.animate(steer, drifting and state == "racing", (boosting or mini_turbo > 0) and state == "racing", delta)
	for rival in rivals:
		rival.car.road_speed = rival.speed if state == "racing" else 0.0
		rival.car.animate(clampf((float(rival.target_lane) - float(rival.lane)) / 2, -1, 1), false, rival.boosting and state == "racing", delta)
	hud.queue_redraw()

func step(delta: float, axis: float, drift_input: bool, boost_input: bool, brake: bool) -> void:
	elapsed += delta
	launch_flash = maxf(0, launch_flash - delta)
	near_miss_flash = maxf(0, near_miss_flash - delta)
	var old_gaps: Array[float] = []
	for rival in rivals:
		old_gaps.append(wrapf(float(rival.distance) - distance, -track.length / 2, track.length / 2))
	impact = maxf(0, impact - delta * 2.8)
	boost_kick = maxf(0, boost_kick - delta * 2)
	mini_turbo = maxf(0, mini_turbo - delta)
	steer = move_toward(steer, axis, delta * 7)
	var was_drifting := drifting
	var was_boosting := boosting
	drifting = drift_input and absf(steer) > 0.1 and speed > 22
	boosting = boost_input and nitro > (0 if was_boosting else 8) and not brake
	if boosting and not was_boosting:
		boost_kick = 1
	if drifting and absf(lane) < 7.2:
		drift_charge = minf(2.5, drift_charge + delta)
	elif was_drifting:
		if drift_charge > 0.55 and not brake and absf(lane) < 7.4:
			mini_turbo = minf(1.35, drift_charge * 0.5)
			speed = minf(88, speed + 3)
			boost_kick = 0.7
		drift_charge = 0
	drafting = false
	for rival in rivals:
		var gap: float = wrapf(float(rival.distance) - distance, -track.length / 2, track.length / 2)
		if gap > 6 and gap < 32 and absf(float(rival.lane) - lane) < 1.8:
			drafting = true
	draft_charge = move_toward(draft_charge, 1.0 if drafting else 0.0, delta * (0.65 if drafting else 1.3))
	var target := 88.0 if boosting else (77.0 if mini_turbo > 0 else 68.0 + draft_charge * 4)
	if brake:
		target = 18
	elif drifting:
		target = 61 if not boosting else 76
	speed = move_toward(speed, target, (34.0 if brake else (26.0 if boosting else 20.0)) * delta)
	var bend_rate := wrapf(track.heading(distance + 16) - track.heading(distance), -PI, PI) / 16
	var target_lateral := steer * (10.5 if drifting else 7.6) * minf(speed / 20, 1) + bend_rate * speed * speed * 0.04
	lane_velocity = move_toward(lane_velocity, target_lateral, delta * (17 if drifting else 33))
	lane += lane_velocity * delta
	if absf(lane) > 7.4:
		speed = move_toward(speed, 24, delta * 65)
		if absf(lane) > 7.75 and bump_cooldown <= 0:
			impact = 0.65
			bump_cooldown = 0.4
			lane_velocity *= -0.25
	lane = clampf(lane, -7.8, 7.8)
	if boosting:
		nitro = maxf(0, nitro - delta * 24)
	else:
		nitro = minf(100, nitro + delta * (13 if drifting else 3 + draft_charge * 3))
	if drifting and absf(lane) < 7.2:
		score += delta * speed * (2.5 + drift_charge)
	distance += speed * delta
	bump_cooldown = maxf(0, bump_cooldown - delta)
	brain.tick(self, delta)
	for i in range(rivals.size()):
		var rival: Dictionary = rivals[i]
		var gap: float = wrapf(float(rival.distance) - distance, -track.length / 2, track.length / 2)
		var lateral_gap: float = absf(float(rival.lane) - lane)
		if old_gaps[i] > 0 and old_gaps[i] < 8 and gap <= 0 and lateral_gap > 1.95 and lateral_gap < 3.6:
			near_misses += 1
			near_miss_flash = 1.1
			nitro = minf(100, nitro + 7)
			score += 100
	for rival in rivals:
		var separation := wrapf(float(rival.distance) - distance, -track.length / 2, track.length / 2)
		if absf(separation) < 4.1 and absf(float(rival.lane) - lane) < 1.9 and bump_cooldown <= 0:
			speed *= 0.74
			rival.speed *= 0.88
			lane_velocity += -3.0 if lane < float(rival.lane) else 3.0
			impact = 1
			bump_cooldown = 0.65
	if distance >= track.length * LAPS:
		state = "finished"
		boosting = false
		if best_time == 0 or elapsed < best_time:
			best_time = elapsed
			var save := ConfigFile.new()
			save.set_value("race", "best_time", best_time)
			if save_records:
				save.save("user://records.cfg")

func place_cars() -> void:
	player.position = track.point(distance, lane) + Vector3.UP * 0.12
	player.rotation.y = track.heading(distance)
	for rival in rivals:
		var car: Node3D = rival.car
		car.position = track.point(float(rival.distance), float(rival.lane)) + Vector3.UP * 0.12
		car.rotation.y = track.heading(float(rival.distance))

func update_camera(delta: float) -> void:
	var forward := (track.point(distance + 3) - track.point(distance)).normalized()
	var right := Vector3(-forward.z, 0, forward.x)
	var pace := clampf(speed / 88, 0, 1)
	var active := state == "racing"
	camera_time += delta if active else 0.0
	var turbo := boosting or mini_turbo > 0
	var shake := (0.012 * pace * pace + impact * 0.14) if active and not motion_reduced else 0.0
	var vibration := right * sin(camera_time * 53) * shake + Vector3.UP * cos(camera_time * 67) * shake * 0.55
	var desired_offset := -forward * (5.3 + pace * 0.25 + (boost_kick * 0.55 if not motion_reduced else 0.0)) + Vector3.UP * (2.75 - pace * 0.30) + vibration
	if drifting and not motion_reduced:
		desired_offset += right * steer * 0.9
	# Smooth the relative chase offset, not world position: speed must not add 10 m of camera lag.
	camera_offset = camera_offset.lerp(desired_offset, 1.0 - exp(-delta * 9.0))
	camera.position = player.position + camera_offset
	camera.look_at(player.position + forward * (2.5 + pace * 0.8) + right * steer * (0 if motion_reduced else 0.7) + Vector3.UP * 0.7)
	if not motion_reduced:
		camera.rotate_object_local(Vector3.FORWARD, -steer * pace * (0.022 if drifting else 0.01))
	var target_fov := (68.0 if motion_reduced else 64.0 + pace * 17.0) + (9 if turbo and active and not motion_reduced else 0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * (8 if turbo else 4)))

func rank_position() -> int:
	var rank := 1
	for rival in rivals:
		if float(rival.distance) > distance:
			rank += 1
	return rank
