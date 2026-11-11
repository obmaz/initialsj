extends RefCounted
# 협곡 중심 범위는 생활 건물 배치·해안 경사·암벽에서 공유한다.
const CANYONS: Array[Vector2] = [Vector2(950, 1320), Vector2(2220, 2530)]
const TRANSITION := 200.0
const NARROWS := [Vector4(780, 960, 1290, 1470), Vector4(2100, 2260, 2480, 2670)]
const SEA_CLIFF_OFFSETS := [32.0, 40.0, 56.0, 68.0, 102.0, 180.0, 250.0, 390.0]
const SEA_CLIFF_HEIGHTS := [-2.0, 36.0, 44.0, 78.0, 96.0, 110.0, 48.0, -8.0]


static func canyon_amount(d: float) -> float:
	var amount := 0.0
	for span in CANYONS:
		amount = maxf(
			amount,
			smoothstep(span.x - TRANSITION, span.x + 80, d) * (1 - smoothstep(span.y - 80, span.y + TRANSITION, d))
		)
	return amount


static func half_width(d: float, length: float) -> float:
	d = fposmod(d, length)
	var width := 12.4 + 1.4 * pow(sin(TAU * d / length), 2)
	for i in range(NARROWS.size()):
		var span: Vector4 = NARROWS[i]
		var blend := smoothstep(span.x, span.y, d) * (1 - smoothstep(span.z, span.w, d))
		width = lerpf(width, 9.8 if i == 0 else 10.0, blend)
	return width


static func warning(d: float) -> String:
	for span in NARROWS:
		if d >= span.x - 180 and d <= span.y + 20:
			return "ROAD NARROWS"
	return ""
