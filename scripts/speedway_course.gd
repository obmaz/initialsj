extends RefCounted
# An original coastal tri-oval. The pit straight stays low while the outer
# turns climb coastal ridges and the back straight rolls down into the infield.
const POINTS := [
	Vector3(-490,8,400),Vector3(-240,8,510),Vector3(50,8,555),
	Vector3(340,12,505),Vector3(590,24,380),Vector3(805,34,160),
	Vector3(860,38,-120),Vector3(745,33,-360),Vector3(500,21,-475),
	Vector3(150,10,-490),Vector3(-200,9,-490),Vector3(-540,16,-475),
	Vector3(-790,28,-340),Vector3(-885,31,-90),Vector3(-815,22,175),
	Vector3(-650,12,325)
]
static func build(section: Node3D) -> void:
	section.curve.clear_points()
	section.curve.bake_interval = 1
	for i in range(POINTS.size()+1):
		var index := i%POINTS.size()
		var tangent: Vector3 = (POINTS[(index+1)%POINTS.size()]-POINTS[posmod(index-1,POINTS.size())])/6
		section.curve.add_point(POINTS[index],-tangent,tangent)
	section.length = section.curve.get_baked_length()
	# Cache a smooth signed bank profile. point() reads this without recursing
	# through heading(), and the closing sample equals the first one.
	var count := int(ceil(section.length/4))
	for i in range(count+1):
		var d: float = section.length*(i%count)/count
		var a: Vector3 = section.curve.sample_baked(fposmod(d-36,section.length))
		var b: Vector3 = section.curve.sample_baked(fposmod(d,section.length))
		var c: Vector3 = section.curve.sample_baked(fposmod(d+36,section.length))
		var before := atan2(-(b-a).x,-(b-a).z)
		var after := atan2(-(c-b).x,-(c-b).z)
		var curvature := wrapf(after-before,-PI,PI)/36
		section.bank_samples.append(signf(curvature)*deg_to_rad(26)*smoothstep(0.0003,0.0033,absf(curvature)))

	var raw: PackedFloat32Array = section.bank_samples.duplicate()
	for i in range(count):
		var value := 0.0
		var weights := 0.0
		for offset in range(-15,16):
			var weight := 16.0-absf(offset)
			value += raw[posmod(i+offset,count)]*weight
			weights += weight
		section.bank_samples[i] = value/weights
	section.bank_samples[count] = section.bank_samples[0]
