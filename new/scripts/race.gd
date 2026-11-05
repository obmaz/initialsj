extends Node3D

const Track = preload("res://scripts/track.gd")
const Car = preload("res://scripts/car.gd")
const HUD = preload("res://scripts/hud.gd")
const LAPS := 3
var track: Track
var player: Car
var camera: Camera3D
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
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("407fab")
	sky_mat.sky_horizon_color = Color("b6dbe2")
	sky_mat.ground_horizon_color = Color("b6dbe2")
	sky_mat.ground_bottom_color = Color("57765d")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3e1f1")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("a3c9d7")
	env.fog_density = 0.00065
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	add_child(sun)
	player = Car.new()
	add_child(player)
	var colors := ["ffc94d", "438aef", "a58aeb", "eee6db", "44bea9", "ee843f", "6c92a1"]
	for i in range(7):
		var car := Car.new()
		car.paint = Color(colors[i])
		add_child(car)
		rivals.append({"car": car, "distance": -10.0 - i * 9.0, "lane": 3.0 if i % 2 == 0 else -3.0, "pace": 47.0 + i * 0.85})
	camera = Camera3D.new()
	camera.far = 2400
	camera.fov = 68
	add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HUD.new()
	hud.race = self
	canvas.add_child(hud)
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
	bump_cooldown = 0
	state = "countdown"
	for i in range(rivals.size()):
		rivals[i].distance = -10.0 - i * 9.0
	place_cars()
	update_camera(1)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and state in ["ready", "finished"]:
			restart()
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
	if state == "racing":
		var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		axis = clampf(axis + hud.touch_axis(), -1, 1)
		step(delta, axis, Input.is_physical_key_pressed(KEY_SPACE) or hud.held("drift"), Input.is_physical_key_pressed(KEY_SHIFT) or hud.held("boost"), Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or hud.held("brake"))
	place_cars()
	update_camera(delta)
	player.animate(steer, drifting and state == "racing", boosting and state == "racing", delta)
	hud.queue_redraw()

func step(delta: float, axis: float, drift_input: bool, boost_input: bool, brake: bool) -> void:
	elapsed += delta
	steer = axis
	drifting = drift_input and absf(steer) > 0.1 and speed > 22
	boosting = boost_input and nitro > 1 and not brake
	var target := 77.0 if boosting else 56.0
	if brake:
		target = 18
	elif drifting:
		target = 46
	speed = move_toward(speed, target, (28.0 if brake else 12.0) * delta)
	lane += steer * (12.0 if drifting else 8.5) * delta * minf(speed / 20, 1.0)
	# Road shoulders slow the car; it cannot leave the playable ribbon.
	if absf(lane) > 7.4:
		speed = move_toward(speed, 24, delta * 45)
	lane = clampf(lane, -7.8, 7.8)
	if boosting:
		nitro = maxf(0, nitro - delta * 24)
	else:
		nitro = minf(100, nitro + delta * (12 if drifting else 3))
	if drifting:
		score += delta * speed * 2.5
	distance += speed * delta
	bump_cooldown = maxf(0, bump_cooldown - delta)
	for rival in rivals:
		rival.distance += float(rival.pace) * delta
		var separation := wrapf(float(rival.distance) - distance, -track.length / 2, track.length / 2)
		if absf(separation) < 4.1 and absf(float(rival.lane) - lane) < 1.9 and bump_cooldown <= 0:
			speed *= 0.68
			lane = clampf(lane + (-1.2 if lane < float(rival.lane) else 1.2), -7.8, 7.8)
			bump_cooldown = 0.8
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
	var back := (track.point(distance) - track.point(distance + 3)).normalized()
	var desired := player.position + back * 10.5 + Vector3.UP * 5.0
	camera.position = camera.position.lerp(desired, 1.0 - exp(-delta * 7.0))
	camera.look_at(player.position + (track.point(distance + 16) - track.point(distance)) + Vector3.UP * 1.6)
	camera.fov = lerpf(camera.fov, 77.0 if boosting else 68.0, minf(delta * 3, 1))

func rank_position() -> int:
	var rank := 1
	for rival in rivals:
		if float(rival.distance) > distance:
			rank += 1
	return rank
