extends RefCounted
# 음량은 저장·UI에서 0~100, 믹서에서 0~1 선형 게인을 사용한다.
const DEFAULT_MUSIC := 70
const DEFAULT_SOUND := 50
var music_volume := DEFAULT_MUSIC
var sound_volume := DEFAULT_SOUND
var effects_bus: StringName


static func valid_volume(value: Variant, fallback: int) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return clampi(roundi(value), 0, 100)
	return fallback


func read(config: ConfigFile) -> void:
	music_volume = valid_volume(config.get_value("preferences", "music_volume", DEFAULT_MUSIC), DEFAULT_MUSIC)
	sound_volume = valid_volume(config.get_value("preferences", "sound_volume", DEFAULT_SOUND), DEFAULT_SOUND)


func write(config: ConfigFile) -> void:
	config.set_value("preferences", "music_volume", music_volume)
	config.set_value("preferences", "sound_volume", sound_volume)


func music_gain() -> float:
	return music_volume / 100.0


func sound_gain() -> float:
	return sound_volume / 100.0


func create_bus() -> void:
	if not effects_bus.is_empty():
		return
	effects_bus = StringName("Effects%d" % get_instance_id())
	var index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(index, effects_bus)
	apply(true)


func apply(enabled: bool) -> void:
	var index := AudioServer.get_bus_index(effects_bus)
	if index <= 0:
		return
	AudioServer.set_bus_mute(index, not enabled or sound_volume == 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(sound_gain(), .0001)))


func release_bus() -> void:
	var index := AudioServer.get_bus_index(effects_bus)
	if index > 0:
		AudioServer.remove_bus(index)
	effects_bus = &""
