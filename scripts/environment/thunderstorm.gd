extends Node3D
# 야간 우천의 일부 서킷만 사용한다. 번개 하나·그림자 없는 광원 하나·음원 하나를 재사용한다.
const RaceState = preload("res://scripts/race/race_state.gd")
var race: Node3D
var light: DirectionalLight3D
var bolt: MeshInstance3D
var audio: AudioStreamPlayer
var wait := 10.0
var flash := 0.0
var thunder_delay := -1.0
var road_id := 0
var rng := RandomNumberGenerator.new()
var strikes := 0


func eligible() -> bool:
	return (
		race.mode == "track"
		and race.selected_course in [0, 4]
		and race.track_environment.active_weather == "rain"
		and race.track_environment.active_period == "night"
		and not race.motion_reduced
	)


func configure() -> void:
	reset()
	road_id = race.track.active.get_instance_id()
	if not eligible() or bolt != null:
		return
	var root := preload("res://models/shared/scene_source.gd").instantiate_static(
		"res://models/props/distant_lightning/model.tscn"
	)
	bolt = MeshInstance3D.new()
	bolt.mesh = preload("res://models/shared/scene_source.gd").collect_meshes(root)[0].mesh
	root.free()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("d9eaff")
	material.emission_enabled = true
	material.emission = Color("bbd5ff")
	material.emission_energy_multiplier = 1.8
	bolt.material_override = material
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.visible = false
	add_child(bolt)
	light = DirectionalLight3D.new()
	light.light_color = Color("bbd5ff")
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	audio = AudioStreamPlayer.new()
	audio.stream = load("res://assets/audio/distant-thunder.ogg")
	audio.volume_db = -9
	add_child(audio)


func reset() -> void:
	rng.randomize()
	wait = rng.randf_range(8, 14)
	strikes = 0
	cancel()


func strike() -> void:
	if bolt == null or not eligible():
		return
	var forward: Vector3 = -race.camera.global_basis.z
	forward.y = 0
	forward = forward.normalized().rotated(Vector3.UP, rng.randf_range(-.48, .48))
	bolt.global_position = race.player.global_position + forward * 950 + Vector3.UP * rng.randf_range(85, 155)
	bolt.look_at(race.camera.global_position, Vector3.UP)
	bolt.scale = Vector3.ONE * rng.randf_range(85, 120)
	flash = 1
	thunder_delay = rng.randf_range(2, 3.5) if race.sound_enabled else -1.0
	wait = rng.randf_range(12, 24)
	strikes += 1


func cancel() -> void:
	flash = 0
	thunder_delay = -1
	if bolt != null:
		bolt.visible = false
		light.visible = false
		audio.stop()


func advance(delta: float) -> void:
	# 모션을 끄는 설정은 일시정지 중에도 즉시 반영한다.
	if not eligible():
		cancel()
		return
	# 일시정지 중 켠 경우 주행을 재개하기 전에 한 번만 준비한다.
	if road_id != race.track.active.get_instance_id() or bolt == null:
		configure()
	if audio != null:
		if not race.sound_enabled:
			thunder_delay = -1
			audio.stop()
		audio.stream_paused = race.state == RaceState.PAUSED
	if race.state == RaceState.PAUSED:
		return
	if race.state != RaceState.RACING or race.track.active.in_tunnel(race.distance):
		cancel()
		return
	if bolt == null:
		return
	wait -= maxf(0, delta)
	flash = maxf(0, flash - delta * 3.8)
	if wait <= 0:
		strike()
	bolt.visible = flash > .25
	light.visible = flash > .01
	light.light_energy = flash * .9
	if not race.sound_enabled:
		thunder_delay = -1
		audio.stop()
	elif thunder_delay >= 0:
		thunder_delay -= delta
		if thunder_delay < 0:
			audio.play()
