extends RefCounted
# 니트로의 풍압으로 맺힌 물방울은 짧게 붙었다가 가장자리로 흘러 사라진다.
const RaceState = preload("res://scripts/race/race_state.gd")
var amount := 0.0
var clock := 0.0
var was_boosting := false


func reset() -> void:
	amount = 0
	clock = 0
	was_boosting = false


func update(race: Node3D, delta: float) -> void:
	var weather: String = race.track.active.region_metadata.get("weather", "clear")
	if weather != "rain" or race.motion_reduced or race.state in RaceState.MENUS:
		reset()
		return
	if race.state != RaceState.RACING:
		return
	var sheltered: bool = race.track.active.in_tunnel(race.distance)
	var boosting: bool = (race.nitro_active or race.nitro_burst_left > 0) and not sheltered
	var dt := clampf(delta, 0, .1)
	if boosting and not was_boosting:
		amount = maxf(amount, .72)
	amount = move_toward(amount, .95 if boosting else 0.0, dt * (.75 if boosting else .42))
	if amount > 0:
		clock += dt * (1.0 + minf(race.speed, 110) * .006)
	was_boosting = boosting
