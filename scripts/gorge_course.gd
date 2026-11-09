extends RefCounted
# 짧아진 고개 다리와 조밀한 협곡 S자·복귀 코너를 잇는 폐곡선입니다.
static func build(section: Node3D) -> void:
	section.bridge_span = Vector2(150,710)
	section.curve.clear_points()
	section.curve.bake_interval = 1
	var points: Array[Vector3] = []
	for part in range(4):
		var count := 48 if part == 2 else 32
		for i in range(count):
			var t := float(i)/count
			var p: Vector3
			match part:
				0: p = Vector3(-450+900*t,42+28*pow(sin(PI*t),2),-220)
				1:
					var a := -PI/2+PI*t
					p = Vector3(450+220*cos(a),42+22*pow(sin(PI*t),2),220*sin(a))
				2: p = Vector3(450-900*t,42+38*pow(sin(PI*t),2)+8*pow(sin(3*PI*t),2),220+65*pow(sin(2*PI*t),3))
				_:
					var a := PI/2+PI*t
					p = Vector3(-450+220*cos(a),42+26*pow(sin(PI*t),2),220*sin(a))
			points.append(p)
	for i in range(points.size()+1):
		var n := i%points.size()
		var tangent := (points[(n+1)%points.size()]-points[posmod(n-1,points.size())])/6
		section.curve.add_point(points[n],-tangent,tangent)
	section.length = section.curve.get_baked_length()
	var count := int(ceil(section.length/4))
	for i in range(count+1):
		var d: float = section.length*(i%count)/count
		var a: Vector3 = section.curve.sample_baked(fposmod(d-25,section.length))
		var b: Vector3 = section.curve.sample_baked(d)
		var c: Vector3 = section.curve.sample_baked(fposmod(d+25,section.length))
		var bend := wrapf(atan2(-(c-b).x,-(c-b).z)-atan2(-(b-a).x,-(b-a).z),-PI,PI)/25
		section.bank_samples.append(signf(bend)*deg_to_rad(5)*smoothstep(0.001,0.008,absf(bend)))
