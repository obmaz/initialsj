extends RefCounted
# MIDNIGHT HARBOR: an original night circuit of about 2737 m made of hairpins, a long back
# straight and linked medium bends, so that the tight corners reward drifting. The centreline was
# designed as straights and constant-radius arcs (R 36-89 m) and sampled every 30 m; the corner
# list below is only a reference for the signs and sections.
# Corners (start m, end m, radius m, turn deg; the sign is the turn direction): 300-412 R58 +110; 561-669 R69 +90; 738-838 R38 -150; 1004-1086 R78 -60; 1162-1298 R43 +180; 1747-1857 R48 +130; 1998-2095 R36 -150; 2184-2318 R42 +180; 2413-2503 R85 -60; 2618-2758 R89 +90
const POINTS := [
	Vector3(-100.0,12.9,-30.0),Vector3(-70.0,12.9,-30.0),Vector3(-40.0,12.9,-30.0),
	Vector3(-10.0,12.7,-30.0),Vector3(20.0,12.5,-30.0),Vector3(50.0,12.2,-30.0),
	Vector3(80.0,11.9,-30.0),Vector3(110.0,11.6,-30.0),Vector3(140.0,11.3,-30.0),
	Vector3(170.0,11.0,-30.0),Vector3(200.0,10.7,-30.0),Vector3(234.9,10.4,-18.4),
	Vector3(256.0,10.1,11.7),Vector3(254.9,10.0,48.4),Vector3(242.2,10.0,83.4),
	Vector3(229.5,10.1,118.4),Vector3(216.7,10.3,153.4),Vector3(204.0,10.5,188.4),
	Vector3(183.4,10.9,217.8),Vector3(150.9,11.3,232.9),Vector3(115.2,11.7,229.8),
	Vector3(82.8,12.1,218.0),Vector3(50.5,12.4,206.2),Vector3(18.3,12.8,209.0),
	Vector3(-0.2,13.1,235.5),Vector3(8.1,13.3,266.7),Vector3(29.4,13.6,292.0),
	Vector3(50.7,13.8,317.4),Vector3(72.0,13.9,342.8),Vector3(93.3,14.1,368.2),
	Vector3(114.6,14.2,393.6),Vector3(147.9,14.3,416.9),Vector3(188.4,14.4,420.4),
	Vector3(225.7,14.6,413.9),Vector3(263.0,14.8,407.3),Vector3(295.2,15.1,414.4),
	Vector3(313.0,15.4,442.3),Vector3(305.8,15.7,474.5),Vector3(278.0,16.2,492.2),
	Vector3(246.3,16.6,497.8),Vector3(214.7,17.1,503.4),Vector3(183.1,17.7,508.9),
	Vector3(151.4,18.2,514.5),Vector3(119.8,18.7,520.1),Vector3(88.1,19.2,525.7),
	Vector3(56.5,19.7,531.3),Vector3(24.8,20.0,536.8),Vector3(-6.8,20.3,542.4),
	Vector3(-38.5,20.4,548.0),Vector3(-70.1,20.4,553.6),Vector3(-101.8,20.2,559.2),
	Vector3(-133.4,19.9,564.7),Vector3(-165.1,19.5,570.3),Vector3(-199.9,18.8,563.1),
	Vector3(-220.3,17.9,534.0),Vector3(-215.1,16.9,498.8),Vector3(-197.4,15.8,468.2),
	Vector3(-179.7,14.6,437.5),Vector3(-162.0,13.3,406.8),Vector3(-144.3,12.1,376.1),
	Vector3(-141.6,11.0,345.1),Vector3(-163.6,10.0,323.0),Vector3(-194.7,9.1,325.7),
	Vector3(-233.2,7.9,348.0),Vector3(-271.7,7.1,370.2),Vector3(-304.2,6.7,374.5),
	Vector3(-330.2,6.4,354.6),Vector3(-334.4,6.4,322.1),Vector3(-314.5,6.5,296.1),
	Vector3(-287.0,6.7,280.3),Vector3(-259.6,7.1,264.4),Vector3(-232.1,7.6,248.6),
	Vector3(-200.8,8.4,217.2),Vector3(-189.3,9.3,174.4),Vector3(-189.3,10.1,136.1),
	Vector3(-189.3,10.8,97.7),Vector3(-189.3,11.5,59.3),Vector3(-182.5,12.0,25.1),
	Vector3(-163.2,12.4,-3.8),Vector3(-134.2,12.7,-23.2)
]
static func build(section: Node3D) -> void:
	section.curve.clear_points()
	section.curve.bake_interval = 1
	for i in range(POINTS.size()+1):
		var index := i%POINTS.size()
		var tangent: Vector3 = (POINTS[(index+1)%POINTS.size()]-POINTS[posmod(index-1,POINTS.size())])/6
		section.curve.add_point(POINTS[index],-tangent,tangent)
	section.length = section.curve.get_baked_length()
	# A little camber into each bend, smoothed along the road so the roll never steps.
	var count := int(ceil(section.length/4))
	var raw := PackedFloat32Array()
	for i in range(count):
		var d: float = section.length*i/count
		var a: Vector3 = section.curve.sample_baked(fposmod(d-30,section.length))
		var b: Vector3 = section.curve.sample_baked(d)
		var c: Vector3 = section.curve.sample_baked(fposmod(d+30,section.length))
		var before := atan2(-(b-a).x,-(b-a).z)
		var after := atan2(-(c-b).x,-(c-b).z)
		var bend := wrapf(after-before,-PI,PI)/30
		raw.append(signf(bend)*deg_to_rad(4.5)*smoothstep(0.002,0.012,absf(bend)))
	for i in range(count):
		var value := 0.0
		var weights := 0.0
		for offset in range(-10,11):
			var weight := 11.0-absf(offset)
			value += raw[posmod(i+offset,count)]*weight
			weights += weight
		section.bank_samples.append(value/weights)
	section.bank_samples.append(section.bank_samples[0])
