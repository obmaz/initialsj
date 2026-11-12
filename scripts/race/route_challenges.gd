extends RefCounted
# 위험 구간에 정상 진입해 실제로 통과·착지한 경우만 보상한다.
var awarded: Dictionary = {}
var gates: Dictionary = {}
var jump: Dictionary = {}
var skill_jumps := 0
var safe_passes := 0


func reset() -> void:
	awarded.clear()
	invalidate()
	skill_jumps = 0
	safe_passes = 0


func invalidate() -> void:
	gates.clear()
	jump.clear()


func gate(key: String, d: float, start: float, end: float, seconds: float, clean: bool) -> bool:
	if awarded.has(key):
		return false
	if not clean:
		gates.erase(key)
		return false
	if d >= start - 80 and d <= start and not gates.has(key):
		gates[key] = seconds
	if d >= end and gates.has(key):
		var duration: float = seconds - float(gates[key])
		gates.erase(key)
		if duration < 0.4 or d > end + 20:
			return false
		awarded[key] = true
		safe_passes += 1
		return true
	return false


func launch(race: Node3D) -> void:
	jump.clear()
	if race.protection_left > 0 or race.crash.active or race.impact >= .15:
		return
	var section: Node3D = race.track.active
	var d: float = fposmod(race.distance, section.length) if section.closed_loop else race.distance
	for feature in section.features:
		if feature.kind != "ramp":
			continue
		var exit: float = feature.distance + feature.length * .5
		if absf(d - exit) > 18 or absf(race.lane - float(feature.lane)) > float(feature.width) * .5:
			continue
		var key := "%s:%d:%d:%s" % [race.mode, race.stage_index, race.laps_completed, feature.id]
		if awarded.has(key):
			return
		var minimum := exit + 10
		var bridge: bool = section.collapse != null and absf(float(feature.distance) - section.collapse.span.x) < 60
		if bridge:
			minimum = section.collapse.span.y + 5
		jump = {"key": key, "stage": race.stage_index, "minimum": minimum, "start": d, "bridge": bridge}
		return


func land(race: Node3D, clean: bool) -> void:
	if jump.is_empty():
		return
	var d: float = fposmod(race.distance, race.track.length) if race.mode == "track" else race.distance
	if clean and race.stage_index == int(jump.stage) and d >= float(jump.minimum) and d < float(jump.start) + 500:
		awarded[jump.key] = true
		skill_jumps += 1
		var points := 750 if bool(jump.bridge) else 300
		race.score += points
		race.rewards.announce(
			("BRIDGE JUMP" if bool(jump.bridge) else "SKILL JUMP") + "  +%d / BOOST" % points,
			1.6,
			1.2 if bool(jump.bridge) else .8,
			7 if bool(jump.bridge) else 4
		)
	jump.clear()


func observe(race: Node3D) -> void:
	var clean: bool = (
		race.protection_left <= 0
		and not race.crash.active
		and race.impact < .15
		and race.offroad_amount < .15
		and race.speed > 25
	)
	if not clean:
		invalidate()
		return
	if race.mode != "track" or race.air.active:
		return
	var section: Node3D = race.track.active
	var d: float = fposmod(race.distance, section.length)
	if section.collapse != null:
		var span: Vector2 = section.collapse.span
		if gate(
			"bridge:%d" % race.laps_completed, d, span.x - 80, span.y + 30, race.elapsed, clean and race.lane < 1.0
		):
			reward_safe(race)
	if section.rockfall != null:
		for plan in section.rockfall.plans:
			if plan.elapsed < 0:
				continue
			var key := "rock:%d:%d" % [plan.lap, race.laps_completed]
			if gate(key, d, float(plan.distance) - 80, float(plan.distance) + 45, race.elapsed, clean):
				reward_safe(race)
	if race.selected_course == 3:
		for fall in section.scenery.rock_arches.falls:
			if fall.elapsed < 0:
				continue
			var key := "arch:%d:%d" % [int(fall.distance), race.laps_completed]
			var side: bool = absf(race.lane) > section.half_width(d) * .4
			if gate(key, d, float(fall.distance) - 110, float(fall.distance) + 45, race.elapsed, clean and side):
				reward_safe(race)


func reward_safe(race: Node3D) -> void:
	race.score += 200
	if race.vehicle.mode != "charges":
		race.nitro = minf(100, race.nitro + 4)
	race.rewards.announce("CLEAN SAFE LINE  +200", 1.4)
