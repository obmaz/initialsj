extends RefCounted
# 버튼을 켜 둔 것만으로 점수를 주지 않습니다. 실제 접지·미끄러짐과
# 깨끗한 노면 주행이 유지될 때만 하트가 쌓이며 짧은 S자 전환은 연결합니다.
var points := 0.0
var duration := 0.0
var hearts := 0
var multiplier := 1
var grace := 0.0
var visible_time := 0.0
var active := false
var broken := false


func reset() -> void:
	points = 0
	duration = 0
	hearts = 0
	multiplier = 1
	grace = 0
	visible_time = 0
	active = false
	broken = false


func step(
	delta: float, speed: float, slip: float, drifting: bool, grounded: bool, clean: bool, contact_hold: bool = false
) -> float:
	visible_time = maxf(0, visible_time - delta)
	if not clean:
		if active:
			active = false
			broken = true
			hearts = 0
			grace = 0
			visible_time = 0.85
		return 0
	if contact_hold:
		return 0
	var sliding := drifting and grounded and speed > 25 and absf(slip) >= 0.12 and absf(slip) < 1.1
	if not sliding:
		grace = maxf(0, grace - delta)
		if active and grace <= 0:
			active = false
			visible_time = 1.5
		return 0
	if not active:
		reset()
		active = true
	duration += delta
	multiplier = mini(5, 1 + int(duration / 1.5))
	var earned := delta * speed * 2.5 * multiplier
	points += earned
	hearts = mini(7, int(points / 250))
	grace = 0.85
	visible_time = 1.5
	return earned
