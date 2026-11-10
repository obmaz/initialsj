extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var bark := Color("73513a")
	# 연속된 곡선 줄기와 잎맥·소엽으로 판자처럼 보이는 큰 잎을 교체합니다.
	for ring in range(16):
		for side in range(12):
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for row in [ring,ring+1]:
				var t: float = row/16.0
				var center := Vector3(.5*t*t,8.4*t,.12*sin(t*PI))
				var radius := lerpf(.32,.16,t)
				for segment in [side,side+1]:
					var angle: float = segment*TAU/12
					var normal := Vector3(cos(angle),0,sin(angle))
					points.append(center+normal*radius)
					normals.append(normal)
			for n in [0,1,2,1,3,2]:
				st.set_color(bark.lightened(.08 if ring%3 == 0 else -.04))
				st.set_normal(normals[n])
				st.add_vertex(points[n])
	var center := Vector3(.5,8.4,0)
	for leaf in range(11):
		var angle := leaf*TAU/11
		var f := Vector3(cos(angle),0,sin(angle))
		var right := Vector3(-f.z,0,f.x)
		var color := Color("2f6840").lightened((leaf%3)*.055)
		for part in range(12):
			var t := part/12.0
			var u := (part+1)/12.0
			var a := center+f*t*4.7+Vector3.UP*(sin(t*PI)*1.6-t*1.8)
			var b := center+f*u*4.7+Vector3.UP*(sin(u*PI)*1.6-u*1.8)
			var points := [a-right*.12,a+right*.12,b-right*.075,b+right*.075]
			for n in [0,2,1,1,2,3,0,1,2,1,3,2]:
				st.set_color(color.lightened(.06))
				st.set_normal(Vector3.UP)
				st.add_vertex(points[n])
			if part == 0: continue
			for sign_x in [-1.0,1.0]:
				var tip: Vector3 = a+right*sign_x*sin(t*PI)*1.15-f*.48-Vector3.UP*.32
				var mid: Vector3 = a.lerp(tip,.48)
				var points_leaf := [a,mid+f*.16,tip,mid-f*.16]
				for n in [0,1,3,1,2,3,0,3,1,1,3,2]:
					st.set_color(color)
					st.set_normal(Vector3.UP)
					st.add_vertex(points_leaf[n])
	for i in range(3): Geometry.round_part(st,center+Vector3(cos(i*2.0)*.3,-.2,sin(i*2.0)*.3),Vector3.ONE*.4,Color("625037"))
	st.index()
	return st.commit()
