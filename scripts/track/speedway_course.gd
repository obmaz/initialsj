extends RefCounted
# 외곽 고속 뱅크와 호수 남쪽 인필드 S자·헤어핀을 잇는 독립 서킷. 단위는 미터다.
const PLAN_SCALE := .78
const POINTS := [
	Vector3(-350, 8, 530),
	Vector3(50, 8, 550),
	Vector3(450, 12, 500),
	Vector3(760, 24, 280),
	Vector3(850, 36, -60),
	Vector3(740, 33, -350),
	Vector3(450, 19, -490),
	Vector3(50, 12, -500),
	Vector3(-400, 8, -500),
	Vector3(-740, 8, -390),
	Vector3(-840, 9, -130),
	Vector3(-720, 11, 90),
	Vector3(-500, 13, 55),
	Vector3(-330, 13, 10),
	Vector3(-180, 11, 95),
	Vector3(30, 9, 175),
	Vector3(260, 9, 180),
	Vector3(440, 10, 80),
	Vector3(570, 12, 30),
	Vector3(650, 14, 155),
	Vector3(560, 14, 285),
	Vector3(320, 11, 320),
	Vector3(80, 9, 275),
	Vector3(-180, 8, 260),
	Vector3(-440, 8, 245),
	Vector3(-620, 8, 305),
	Vector3(-700, 8, 400),
	Vector3(-650, 8, 475),
	Vector3(-500, 8, 520),
]


static func offset(section: Node3D, index: int) -> float:
	return section.get_meta("speedway_offsets")[index]


static func infield_amount(section: Node3D, distance: float) -> float:
	var d := fposmod(distance, section.length)
	return (
		smoothstep(offset(section, 10), offset(section, 12), d)
		* (1 - smoothstep(offset(section, 25), offset(section, 28), d))
	)


static func build(section: Node3D) -> void:
	section.curve.clear_points()
	section.curve.bake_interval = 1
	var points: Array[Vector3] = []
	for point in POINTS:
		points.append(point * Vector3(PLAN_SCALE, 1, PLAN_SCALE))
	for i in range(points.size() + 1):
		var index := i % points.size()
		var tangent: Vector3 = (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]) / 6
		section.curve.add_point(points[index], -tangent, tangent)
	section.length = section.curve.get_baked_length()
	var offsets := PackedFloat32Array()
	for point in points:
		offsets.append(section.curve.get_closest_offset(point))
	section.set_meta("speedway_offsets", offsets)
	var count := int(ceil(section.length / 4))
	for i in range(count + 1):
		var d: float = section.length * (i % count) / count
		var a: Vector3 = section.curve.sample_baked(fposmod(d - 24, section.length))
		var b: Vector3 = section.curve.sample_baked(fposmod(d, section.length))
		var c: Vector3 = section.curve.sample_baked(fposmod(d + 24, section.length))
		var before := atan2(-(b - a).x, -(b - a).z)
		var after := atan2(-(c - b).x, -(c - b).z)
		var curvature := wrapf(after - before, -PI, PI) / 24
		var tilt := lerpf(26, 6, infield_amount(section, d))
		section.bank_samples.append(signf(curvature) * deg_to_rad(tilt) * smoothstep(.0003, .0033, absf(curvature)))
	var raw: PackedFloat32Array = section.bank_samples.duplicate()
	for i in range(count):
		var value := 0.0
		var weights := 0.0
		for shift in range(-10, 11):
			var weight := 11.0 - absf(shift)
			value += raw[posmod(i + shift, count)] * weight
			weights += weight
		section.bank_samples[i] = value / weights
	section.bank_samples[count] = section.bank_samples[0]
