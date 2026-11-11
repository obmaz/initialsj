extends RefCounted


# 긴 곡선 사이로 고개 세 개를 넘습니다. 폐곡선의 위치·접선·높이가 이어져야
# 출발선을 통과할 때 카메라와 실제 바퀴 접지가 끊기지 않습니다.
static func build(section: Node3D) -> void:
	section.curve.clear_points()
	section.curve.bake_interval = 1
	var points: Array[Vector3] = []
	for i in range(128):
		var t := TAU * i / 128.0 - PI * 0.5
		points.append(
			Vector3(
				650 * cos(t) + 84 * sin(3 * t),
				31 + 19 * (1 - cos(2 * t)) + 10 * sin(3 * t),
				460 * sin(t) + 72 * sin(2 * t)
			)
		)
	for i in range(points.size() + 1):
		var index := i % points.size()
		var tangent: Vector3 = (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]) / 6
		section.curve.add_point(points[index], -tangent, tangent)
	section.length = section.curve.get_baked_length()
	var count := int(ceil(section.length / 4))
	for i in range(count + 1):
		var d: float = section.length * (i % count) / count
		var a: Vector3 = section.curve.sample_baked(fposmod(d - 24, section.length))
		var b: Vector3 = section.curve.sample_baked(d)
		var c: Vector3 = section.curve.sample_baked(fposmod(d + 24, section.length))
		var turn := wrapf(atan2(-(c - b).x, -(c - b).z) - atan2(-(b - a).x, -(b - a).z), -PI, PI) / 24
		section.bank_samples.append(signf(turn) * deg_to_rad(5) * smoothstep(0.001, 0.009, absf(turn)))
