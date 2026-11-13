extends RefCounted
# 이 상태는 시각 피벗·후처리만 조절하고 실제 차체·속도·카메라 기준을 변경하지 않는다.
const RaceState = preload("res://scripts/race/race_state.gd")
var spin := 0.0
var spin_time := -1.0
var spin_duration := .65
var used_jump := false
var axis := Vector3.FORWARD


func reset() -> void:
	spin = 0
	spin_time = -1
	used_jump = false


func advance(race: Node3D, delta: float) -> void:
	var equipped: Array = race.player.equipped_effects
	var active: bool = race.state == RaceState.RACING and not race.motion_reduced and not race.crash.active
	var body: CharacterBody3D = race.world_race.player_body
	if not active or race.protection_left > 0 or body.grounded:
		spin = 0
		spin_time = -1
		used_jump = false
		return
	if "air_spin" in equipped and not used_jump and race.air.trick and race.air.height >= 4 and race.air.velocity > 0:
		used_jump = true
		spin_time = 0
		var gravity: float = body.GRAVITY
		var remaining: float = (
			(race.air.velocity + sqrt(race.air.velocity * race.air.velocity + 2 * gravity * race.air.height)) / gravity
		)
		spin_duration = clampf(remaining * .78, .25, .75)
		axis = Vector3.FORWARD if race.player.model in ["hatch", "muscle"] else Vector3.RIGHT
	if spin_time >= 0:
		spin_time += maxf(0, delta)
		spin = TAU * smoothstep(0, spin_duration, spin_time)
		if spin_time >= spin_duration:
			spin = 0
			spin_time = -1
