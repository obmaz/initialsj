extends Node
# 루프·공기 소리만 보내는 공통 잔향 버스. UI·카운트다운·보상 안내는 원래의 건조한 소리를 유지한다.
var bus_name: StringName
var reverb := AudioEffectReverb.new()
var muted := true
var gain := 0.0
var last_wet := -1.0
var last_room := -1.0


func _ready() -> void:
	bus_name = StringName("DrivingEnvironment%d" % get_instance_id())
	var index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(index, bus_name)
	reverb.dry = 1
	reverb.wet = 0
	reverb.hipass = .12
	reverb.predelay_feedback = .12
	reverb.spread = .8
	AudioServer.add_bus_effect(index, reverb)
	AudioServer.set_bus_mute(index, true)


func update(state: RefCounted, active: bool, delta: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var should_mute := not active
	if muted != should_mute:
		muted = should_mute
		AudioServer.set_bus_mute(index, muted)
	gain = lerpf(gain, 1.0 if active else 0.0, 1 - exp(-maxf(delta, 0) * 28)) if active else 0.0
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(gain, .0001)))
	var wet: float = state.wet if active and state.wet >= .0001 else 0.0
	var room: float = state.enclosure if state.enclosure >= .001 else 0.0
	if absf(wet - last_wet) > .0001 or (wet == 0 and last_wet != 0):
		reverb.wet = wet
		last_wet = wet
	if absf(room - last_room) > .001 or (room == 0 and last_room != 0):
		reverb.room_size = lerpf(.25, .62, room)
		reverb.damping = lerpf(.45, .7, room)
		reverb.predelay_msec = lerpf(22, 58, room)
		last_room = room


func _exit_tree() -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0:
		AudioServer.remove_bus(index)
