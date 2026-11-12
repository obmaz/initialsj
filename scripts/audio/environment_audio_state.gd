extends RefCounted
# 실제 도로의 닫힌 구간만 울린다. DSP·버스·노드 생성은 재생 어댑터가 맡는다.
const RaceState = preload("res://scripts/race/race_state.gd")
const Harbor = preload("res://scripts/track/harbor_corridor.gd")
var wet := 0.0
var enclosure := 0.0


func reset() -> void:
	wet = 0
	enclosure = 0


func advance(race: Node3D, delta: float) -> void:
	if delta <= 0 or race.state == RaceState.PAUSED:
		return
	var target := Vector2.ZERO
	if race.state in RaceState.DRIVING:
		var section: Node3D = race.track.active
		var player: CharacterBody3D = race.world_race.player_body
		var height: float = (player.feet_position() - race.track.point(race.distance, race.lane)).dot(
			player.surface_normal
		)
		if absf(height) < 4.5:
			if section.in_tunnel(race.distance):
				target = Vector2(.22, 1.0)
			elif Harbor.contains(section, race.distance):
				target = Vector2(.095 * Harbor.weight(fposmod(race.distance, section.length)), .25)
	var follow := 1 - exp(-delta * 5)
	wet = lerpf(wet, target.x, follow)
	enclosure = lerpf(enclosure, target.y, follow)
