extends RefCounted
# 실제 주행 결과만 보상한다. 코너별 지급 이력은 경기 안에서만 보유한다.
var exit_boost := 0.0
var boost_gain := 4.0
var clean_exits := 0
var message := ""
var flash := 0.0
var drift_seconds := 0.0
var drift_metres := 0.0
var drift_turn := 0.0
var settle := 0.0
var corner_key := ""
var rewarded_corners: Dictionary = {}
var pass_chain := 0
var max_pass_chain := 0
var pass_window := 0.0
var close_passes := 0
var traffic_gaps: Dictionary = {}
var passed_traffic: Dictionary = {}
var event_id := 0
var event_boost := false
var event_chain := 1


func reset() -> void:
	exit_boost = 0
	boost_gain = 4
	clean_exits = 0
	message = ""
	flash = 0
	cancel_drift()
	rewarded_corners.clear()
	pass_chain = 0
	max_pass_chain = 0
	pass_window = 0
	close_passes = 0
	traffic_gaps.clear()
	passed_traffic.clear()
	event_id = 0
	event_boost = false
	event_chain = 1


# 점수는 주행 규칙에서 지급하고, 이 사건 하나로 기존 팝업·음향·진동을 묶는다.
func announce(text: String, duration: float, boost: float = 0, gain: float = 4, chain: int = 1) -> void:
	message = text
	flash = duration
	event_id += 1
	event_boost = boost > 0
	event_chain = clampi(chain, 1, 5)
	if boost > 0:
		exit_boost = maxf(exit_boost, boost)
		boost_gain = gain


func cancel_drift() -> void:
	drift_seconds = 0
	drift_metres = 0
	drift_turn = 0
	settle = 0
	corner_key = ""


func tick(delta: float) -> void:
	exit_boost = maxf(0, exit_boost - delta)
	flash = maxf(0, flash - delta)
	pass_window = maxf(0, pass_window - delta)
	if pass_window <= 0:
		pass_chain = 0


func break_pass_chain() -> void:
	pass_chain = 0
	pass_window = 0


# 관측한 앞차가 실제 뒤쪽으로 넘어온 순간만 인정한다. 차체 참조는 저장하지 않는다.
func observe_traffic(id: int, ahead: float, lateral: float, height: float, clean: bool) -> bool:
	if passed_traffic.has(id):
		return false
	var before: float = traffic_gaps.get(id, ahead)
	traffic_gaps[id] = ahead
	if before <= 0 or ahead > 0:
		return false
	passed_traffic[id] = true
	traffic_gaps.erase(id)
	if not clean or ahead < -12 or height > 1.5 or lateral < 2.25 or lateral > 4.0:
		return false
	close_passes += 1
	pass_chain = mini(5, pass_chain + 1)
	max_pass_chain = maxi(max_pass_chain, pass_chain)
	pass_window = 5.0
	announce("CLOSE PASS x%d  +%d" % [pass_chain, 150 * pass_chain], 1.4, 0, 4, pass_chain)
	return true


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
		earned = 200 + mini(200, int(drift_turn * 150))
		announce("CLEAN EXIT  +%d" % earned, 1.4, clampf(0.4 + drift_seconds * 0.08, 0.45, 0.75))
	cancel_drift()
	return earned
