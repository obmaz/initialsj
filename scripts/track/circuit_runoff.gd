extends RefCounted
# 코스별 여유 부지. 관중석·광고·다리는 밀착 경계를 유지하고 완만하게 폭을 바꾼다.
const SPANS := {
	1: [Vector2(2070, 2780), Vector2(2980, 3630), Vector2(4800, 5360)],
	2: [Vector2(330, 720), Vector2(1000, 1240), Vector2(1800, 2090)],
	3: [Vector2(220, 610), Vector2(1190, 1570), Vector2(2320, 2660)],
	4: [Vector2(900, 1110), Vector2(1940, 2190)]
}


static func build(section: Node3D) -> PackedVector2Array:
	var samples := PackedVector2Array()
	var count := ceili(section.length / 8)
	for i in range(count + 1):
		var d: float = section.length * (i % count) / count
		var amount := 0.0
		for span in SPANS.get(section.course_id, []):
			amount = maxf(amount, smoothstep(span.x, span.x + 80, d) * (1 - smoothstep(span.y - 80, span.y, d)))
		if section.bridge_span.y > section.bridge_span.x:
			amount *= (
				1
				- (
					smoothstep(section.bridge_span.x - 100, section.bridge_span.x - 20, d)
					* (1 - smoothstep(section.bridge_span.y + 20, section.bridge_span.y + 100, d))
				)
			)
		var curvature: float = section.curvature(d)
		var edge := Vector2.ZERO
		for side in [-1.0, 1.0]:
			var base := .35 if section.course_id == 1 and side > 0 else 1.5
			var extra := 6.5
			if curvature * side < 0:
				extra = minf(extra, maxf(2, .65 / maxf(.001, absf(curvature)) - section.half_width(d) - base - 2))
			edge[0 if side < 0 else 1] = base + amount * extra
		samples.append(edge)
	return samples
