extends RefCounted
# The return viaduct crosses the lakeside straight in X/Z, with real vertical
# clearance. This is one continuous closed route, not two overlapping lap maps.
const POINTS := [
	Vector3(-300, 8, 350),
	Vector3(0, 8, 350),
	Vector3(360, 12, 350),
	Vector3(540, 22, 280),
	Vector3(620, 38, 100),
	Vector3(570, 58, -30),
	Vector3(450, 68, -65),
	Vector3(300, 65, -65),
	Vector3(210, 60, -115),
	Vector3(230, 52, -190),
	Vector3(320, 45, -215),
	Vector3(485, 38, -215),
	Vector3(600, 30, -320),
	Vector3(540, 23, -475),
	Vector3(350, 18, -530),
	Vector3(60, 14, -530),
	Vector3(-250, 20, -500),
	Vector3(-450, 35, -380),
	Vector3(-510, 48, -220),
	Vector3(-400, 54, -90),
	Vector3(-270, 50, 60),
	Vector3(-180, 45, 250),
	Vector3(-90, 40, 440),
	Vector3(50, 30, 600),
	Vector3(-80, 20, 760),
	Vector3(-350, 12, 740),
	Vector3(-560, 8, 610),
	Vector3(-560, 8, 420),
	Vector3(-480, 8, 350)
]


static func build(section: Node3D) -> void:
	section.curve.clear_points()
	section.curve.bake_interval = 1
	for i in range(POINTS.size() + 1):
		var index := i % POINTS.size()
		var tangent: Vector3 = (POINTS[(index + 1) % POINTS.size()] - POINTS[posmod(index - 1, POINTS.size())]) / 6
		section.curve.add_point(POINTS[index], -tangent, tangent)
	section.length = section.curve.get_baked_length()
	# Excavate an actual descent beneath the original ground before the gallery.
	var original: Curve3D = section.curve.duplicate()
	var count := int(ceil(section.length / 3))
	var samples: Array[Vector3] = []
	for i in range(count):
		var d: float = section.length * i / count
		var p := original.sample_baked(d)
		p.y -= section.excavation_depth(d)
		samples.append(p)
	section.curve.clear_points()
	for i in range(count + 1):
		var index := i % count
		var tangent := (samples[(index + 1) % count] - samples[posmod(index - 1, count)]) / 6
		section.curve.add_point(samples[index], -tangent, tangent)
	section.length = section.curve.get_baked_length()
	# Camber is sampled and smoothed longitudinally so the road has no roll steps.
	count = int(ceil(section.length / 4))
	var raw := PackedFloat32Array()
	for i in range(count):
		var d: float = section.length * i / count
		var a: Vector3 = section.curve.sample_baked(fposmod(d - 24, section.length))
		var b: Vector3 = section.curve.sample_baked(d)
		var c: Vector3 = section.curve.sample_baked(fposmod(d + 24, section.length))
		var before := atan2(-(b - a).x, -(b - a).z)
		var after := atan2(-(c - b).x, -(c - b).z)
		var bend := wrapf(after - before, -PI, PI) / 24
		raw.append(signf(bend) * deg_to_rad(13) * smoothstep(0.001, 0.022, absf(bend)))
	for i in range(count):
		var bank := 0.0
		var weights := 0.0
		for offset in range(-8, 9):
			var weight := 9.0 - absf(offset)
			bank += raw[posmod(i + offset, count)] * weight
			weights += weight
		section.bank_samples.append(bank / weights)
	section.bank_samples.append(section.bank_samples[0])
	section.bridge_span = Vector2(
		section.curve.get_closest_offset(Vector3(-270, 50, 60)), section.curve.get_closest_offset(Vector3(50, 30, 600))
	)
	# Locate the exact crossing on the baked centreline rather than assuming
	# the Catmull-Rom curve passes through a hand-estimated X/Z position.
	var best := INF
	for i in range(401):
		var d: float = lerpf(section.bridge_span.x, section.bridge_span.y, i / 400.0)
		var p: Vector3 = section.curve.sample_baked(d)
		var error := absf(p.z - 350)
		if error < best:
			best = error
			section.bridge_upper_distance = d
	var first: float = section.bridge_upper_distance - (section.bridge_span.y - section.bridge_span.x) / 400
	var last: float = section.bridge_upper_distance + (section.bridge_span.y - section.bridge_span.x) / 400
	for iteration in range(22):
		var middle: float = (first + last) * 0.5
		var p: Vector3 = section.curve.sample_baked(middle)
		if p.z < 350:
			first = middle
		else:
			last = middle
	section.bridge_upper_distance = (first + last) * 0.5
	var upper: Vector3 = section.curve.sample_baked(section.bridge_upper_distance)
	section.bridge_lower_distance = section.curve.get_closest_offset(Vector3(upper.x, 8, 350))
