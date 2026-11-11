extends RefCounted
# 실제 주행 결과만 보상한다. 코너별 지급 이력은 경기 안에서만 보유한다.
var exit_boost := 0.0
var clean_exits := 0
var message := ""
var flash := 0.0
var drift_seconds := 0.0
var drift_metres := 0.0
var drift_turn := 0.0
var settle := 0.0
var corner_key := ""
var rewarded_corners: Dictionary = {}


func reset() -> void:
	exit_boost = 0
	clean_exits = 0
	message = ""
	flash = 0
	cancel_drift()
	rewarded_corners.clear()


func cancel_drift() -> void:
	drift_seconds = 0
	drift_metres = 0
	drift_turn = 0
	settle = 0
	corner_key = ""


func tick(delta: float) -> void:
	exit_boost = maxf(0, exit_boost - delta)
	flash = maxf(0, flash - delta)


func drift_step(
	delta: float, drifting: bool, slip: float, speed: float, metres: float, curvature: float, clean: bool, key: String
) -> int:
	if not clean or speed < 25 or metres < 0 or metres > speed * delta * 2 + 1:
		cancel_drift()
		exit_boost = 0
		return 0
	if drifting:
		settle = 0
		if absf(slip) >= 0.12 and absf(slip) < 1.1:
			if corner_key.is_empty():
				corner_key = key
			drift_seconds += delta
			drift_metres += metres
			drift_turn += absf(curvature) * metres
		return 0
	if drift_seconds <= 0:
		return 0
	settle += delta
	if settle > 0.65:
		cancel_drift()
		return 0
	if absf(slip) > 0.18:
		return 0
	var earned := 0
	if drift_seconds >= 0.7 and drift_metres >= 18 and drift_turn >= 0.12 and not rewarded_corners.has(corner_key):
		rewarded_corners[corner_key] = true
		clean_exits += 1
		exit_boost = clampf(0.4 + drift_seconds * 0.08, 0.45, 0.75)
		earned = 200 + mini(200, int(drift_turn * 150))
		message = "CLEAN EXIT  +%d" % earned
		flash = 1.4
	cancel_drift()
	return earned
