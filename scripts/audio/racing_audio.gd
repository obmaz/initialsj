extends AudioStreamPlayer
# 차량 고유 음향 믹스를 네이티브·웹에 동일하게 전달한다.
# 공간 음향도 공통 관측값을 쓰며 네이티브의 두 보이스는 자식 어댑터가 소유한다.
const RaceState = preload("res://scripts/race/race_state.gd")
const VehicleAudio = preload("res://scripts/audio/vehicle_audio.gd")
var race: Node3D
var gain := 0.0
var web_audio
var vehicle := -1
var boost_level := 0.0
var drift_level := 0.0
var last_nitro := false
var drift_sound := AudioStreamPlayer.new()
var boost_sound := AudioStreamPlayer.new()
var start_sound := AudioStreamPlayer.new()
var cue := AudioStreamPlayer.new()
var impact_sound := AudioStreamPlayer.new()
var last_pads := 0
var last_count := 0
var last_launch := 0.0
var last_drifts := 0
var last_impact := 0.0
var last_misses := 0
var last_overtakes := 0
var last_checkpoint := 0.0
var last_ramp := 0
var last_landing := 0.0
var last_reward := 0
var reward_pending := 0.0
var reward_pitch := 1.0
var cue_busy := 0.0
var extra_loops: Dictionary = {}
var extra_levels := {"coast": 0.0, "gravel": 0.0, "wet": 0.0}
var spatial: Node
var environment_audio: Node
const COUNT_TONE = preload("res://assets/audio/countdown.wav")
const LAUNCH_TONE = preload("res://assets/audio/launch.wav")
const REWARD_TONE = preload("res://assets/audio/reward.wav")
const LAP_TONE = preload("res://assets/audio/lap.wav")


func _ready() -> void:
	var mode := AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	playback_type = mode
	volume_db = -80
	for voice in [drift_sound, boost_sound, start_sound, cue, impact_sound]:
		voice.playback_type = mode
		add_child(voice)
	for key in extra_levels:
		var voice := AudioStreamPlayer.new()
		voice.playback_type = mode
		voice.volume_db = -80
		add_child(voice)
		extra_loops[key] = voice
	extra_loops.gravel.stream = VehicleAudio.load_loop(VehicleAudio.GRAVEL)
	extra_loops.wet.stream = VehicleAudio.load_loop(VehicleAudio.WET)
	drift_sound.volume_db = -80
	boost_sound.volume_db = -80
	impact_sound.stream = preload("res://assets/audio/impact.wav")
	impact_sound.volume_db = -15
	cue.volume_db = -18
	if OS.has_feature("web"):
		var source := FileAccess.get_file_as_string("res://web/file_audio.js")
		var environment_source := FileAccess.get_file_as_string("res://web/environment_audio.js")
		var recordings := FileAccess.get_file_as_string("res://assets/audio/web-loops.json")
		JavaScriptBridge.eval(
			(
				environment_source
				+ "\n"
				+ source
				+ "\nwindow.initialsjFileAudio = new window.InitialSJFileAudio("
				+ recordings
				+ ");"
			)
		)
		web_audio = JavaScriptBridge.get_interface("window").initialsjFileAudio
	else:
		environment_audio = preload("res://scripts/audio/environment_audio.gd").new()
		add_child(environment_audio)
		bus = environment_audio.bus_name
		for voice in [boost_sound, drift_sound, extra_loops.coast, extra_loops.gravel, extra_loops.wet]:
			voice.bus = environment_audio.bus_name
		spatial = preload("res://scripts/audio/spatial_driving_audio.gd").new()
		add_child(spatial)
		for spatial_bus in spatial.buses:
			AudioServer.set_bus_send(AudioServer.get_bus_index(spatial_bus), environment_audio.bus_name)
	apply_vehicle()


# 선택 차량의 다섯 음원을 바꾼다. 차고에서는 음소거 상태다.
func apply_vehicle() -> void:
	vehicle = race.selected_vehicle
	var p := VehicleAudio.profile(vehicle)
	stream = VehicleAudio.load_loop(p.engine)
	boost_sound.stream = VehicleAudio.load_loop(p.boost)
	drift_sound.stream = VehicleAudio.load_loop(p.drift)
	start_sound.stream = VehicleAudio.load_one_shot(p.boost_start)
	extra_loops.coast.stream = VehicleAudio.load_loop(p.coast)
	for key in extra_levels:
		extra_levels[key] = 0.0
		extra_loops[key].volume_db = -80
	start_sound.volume_db = linear_to_db(VehicleAudio.start_level(vehicle))
	boost_level = 0.0
	drift_level = 0.0
	if web_audio != null:
		web_audio.setVehicle(VehicleAudio.web_id(vehicle))


func _process(delta: float) -> void:
	if vehicle != race.selected_vehicle:
		apply_vehicle()
	var active: bool = race.state in RaceState.DRIVING and race.sound_enabled
	var number: int = (
		ceili(race.countdown)
		if race.state == RaceState.COUNTDOWN
		else (
			ceili(race.time_left)
			if race.state == RaceState.RACING and race.mode == "tour" and race.time_left <= 10
			else 0
		)
	)
	if active:
		cue_busy = maxf(0, cue_busy - delta)
		reward_pending = maxf(0, reward_pending - delta)
		if race.rewards.event_id < last_reward or race.protection_left > 0 or race.crash.active:
			reward_pending = 0
		elif race.rewards.event_id > last_reward:
			# 안내음과 겹치면 다음 프레임으로 미룬다. 큐는 하나이며 오래된 보상은 버린다.
			reward_pending = .2
			reward_pitch = race.sound_state.reward_pitch
		var tone: AudioStream
		var tone_pitch := 1.0
		if number > 0 and number != last_count:
			tone = COUNT_TONE
		elif race.launch_flash > last_launch + 0.05:
			tone = LAUNCH_TONE
		elif race.surface.boosts_hit > last_pads:
			tone = LAUNCH_TONE
		elif race.air.launches > last_ramp:
			tone = LAUNCH_TONE
		elif race.checkpoint_flash > last_checkpoint + 0.05:
			tone = LAP_TONE
		elif reward_pending > 0 and cue_busy <= 0:
			tone = REWARD_TONE
			tone_pitch = reward_pitch
			reward_pending = 0
		elif (
			cue_busy <= 0
			and (
				race.drifts_completed > last_drifts or race.near_misses > last_misses or race.overtakes > last_overtakes
			)
		):
			tone = REWARD_TONE
		if tone != null:
			cue_busy = .12
			cue.pitch_scale = tone_pitch
			cue.stream = tone
			cue.play()
		if race.impact > last_impact + 0.05:
			impact_sound.pitch_scale = 1
			impact_sound.volume_db = -15
			impact_sound.play()
		elif race.air.landing_flash > last_landing + 0.05:
			impact_sound.pitch_scale = 0.72
			impact_sound.volume_db = -21 if race.air.trick else -25
			impact_sound.play()
		# Each nitro shot, cell or held gauge starts with the vehicle's own ignition hit.
		if race.state == RaceState.RACING and race.nitro_active and not last_nitro:
			start_sound.play()
	else:
		reward_pending = 0
		cue_busy = 0
		cue.stop()
		impact_sound.stop()
		start_sound.stop()
	last_nitro = race.nitro_active
	last_pads = race.surface.boosts_hit
	last_count = number
	last_launch = race.launch_flash
	last_drifts = race.drifts_completed
	last_impact = race.impact
	last_misses = race.near_misses
	last_overtakes = race.overtakes
	last_checkpoint = race.checkpoint_flash
	last_ramp = race.air.launches
	last_landing = race.air.landing_flash
	last_reward = race.rewards.event_id
	var mixed := VehicleAudio.mix(race)
	var nearby: RefCounted = race.proximity_audio
	var spatial_active: bool = active and race.state == RaceState.RACING and nearby.active
	if OS.has_feature("web"):
		if web_audio != null:
			web_audio.updateEnvironment(active, race.acoustics.wet, race.acoustics.enclosure)
			web_audio.update(
				active,
				mixed.engine_pitch,
				mixed.engine,
				mixed.boost,
				mixed.boost_pitch,
				mixed.drift,
				mixed.drift_pitch,
				mixed.coast,
				mixed.gravel,
				mixed.wet,
				mixed.road_pitch
			)
			web_audio.updateSpatial(
				spatial_active,
				nearby.draft_level,
				nearby.draft_pan,
				nearby.draft_pitch,
				nearby.serial,
				nearby.pass_level,
				nearby.pass_pan,
				nearby.pass_pitch
			)
		return
	environment_audio.update(race.acoustics, active, delta)
	spatial.update(nearby, spatial_active, delta)
	gain = move_toward(gain, 1.0 if active else 0.0, delta * 2)
	if gain <= 0 and not active:
		stop()
		drift_sound.stop()
		boost_sound.stop()
		for voice in extra_loops.values():
			voice.stop()
		return
	# Short smoothing, like the Web Audio gain ramps, so a shot or a drift never clicks in.
	var follow := 1 - exp(-delta * 28)
	boost_level = lerpf(boost_level, float(mixed.boost) * gain, follow)
	drift_level = lerpf(drift_level, float(mixed.drift) * gain, follow)
	pitch_scale = lerpf(pitch_scale, mixed.engine_pitch, 1 - exp(-delta * 9))
	volume_db = linear_to_db(maxf(float(mixed.engine) * gain, 0.0001))
	boost_sound.pitch_scale = mixed.boost_pitch
	boost_sound.volume_db = linear_to_db(maxf(boost_level, 0.0001))
	drift_sound.pitch_scale = mixed.drift_pitch
	drift_sound.volume_db = linear_to_db(maxf(drift_level, 0.0001))
	for key in extra_levels:
		extra_levels[key] = lerpf(float(extra_levels[key]), float(mixed[key]) * gain, follow)
		var voice: AudioStreamPlayer = extra_loops[key]
		voice.pitch_scale = pitch_scale if key == "coast" else mixed.road_pitch
		voice.volume_db = linear_to_db(maxf(float(extra_levels[key]), .0001))
		if float(extra_levels[key]) <= .0002:
			voice.stop()
		elif not voice.playing:
			voice.play()
	if not playing:
		play()
		drift_sound.play()
		boost_sound.play()


func _exit_tree() -> void:
	if web_audio != null:
		web_audio.close()
	stop()
	drift_sound.stop()
	boost_sound.stop()
	start_sound.stop()
	cue.stop()
	impact_sound.stop()
	for voice in extra_loops.values():
		voice.stop()
