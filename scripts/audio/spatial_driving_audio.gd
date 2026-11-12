extends Node
# 네이티브의 고정된 두 보이스·두 패닝 버스. 웹은 같은 관측값을 StereoPanner로 재생한다.
const VehicleAudio = preload("res://scripts/audio/vehicle_audio.gd")
const PASS := "res://assets/audio/traffic-pass.wav"
const DRAFT := "res://assets/audio/traffic-draft.ogg"
var pass_sound := AudioStreamPlayer.new()
var draft_sound := AudioStreamPlayer.new()
var panners: Array[AudioEffectPanner] = []
var buses: Array[StringName] = []
var last_serial := -1
var draft_gain := 0.0


func _ready() -> void:
	for voice in [pass_sound, draft_sound]:
		var bus_name := StringName("DrivingSpatial%d_%d" % [get_instance_id(), buses.size()])
		var index := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index, bus_name)
		var pan := AudioEffectPanner.new()
		AudioServer.add_bus_effect(index, pan)
		panners.append(pan)
		buses.append(bus_name)
		voice.bus = bus_name
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.max_polyphony = 1
		voice.volume_db = -80
		add_child(voice)
	pass_sound.stream = load(PASS)
	draft_sound.stream = VehicleAudio.load_loop(DRAFT)


func update(state: RefCounted, active: bool, delta: float = 1.0 / 60) -> void:
	if not active:
		pass_sound.stop()
		draft_sound.stop()
		draft_gain = 0
		last_serial = state.serial
		return
	panners[0].pan = state.pass_pan
	panners[1].pan = state.draft_pan
	pass_sound.pitch_scale = state.pass_pitch
	draft_sound.pitch_scale = state.draft_pitch
	if state.serial != last_serial:
		last_serial = state.serial
		if state.pass_level > .0002:
			pass_sound.volume_db = linear_to_db(state.pass_level)
			pass_sound.play()
		else:
			pass_sound.stop()
	if state.pass_level <= .0002:
		pass_sound.stop()
	# 음소거 해제 시 이미 큰 후류 상태로 복귀해도 클릭 없이 올라오게 한다.
	draft_gain = lerpf(draft_gain, state.draft_level, 1 - exp(-maxf(0, delta) * 28))
	draft_sound.volume_db = linear_to_db(maxf(draft_gain, .0001))
	if draft_gain <= .0002:
		draft_sound.stop()
	elif not draft_sound.playing:
		draft_sound.play()


func _exit_tree() -> void:
	pass_sound.stop()
	draft_sound.stop()
	for bus_name in buses:
		var index := AudioServer.get_bus_index(bus_name)
		if index > 0:
			AudioServer.remove_bus(index)
