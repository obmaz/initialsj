extends Node3D
# 도로 양옆의 층상 절벽을 잇는 두꺼운 자연 암석 아치. 차선 위 유효 높이를 비운다.
var track: Node3D
var distances: Array[float] = [1140.0,2380.0]
var manifest: Array[Dictionary] = []
var falls: Array[Dictionary] = []

func _ready() -> void:
	for d in distances: make_arch(d)

func make_arch(d: float) -> void:
	var center: Vector3 = track.point(d)
	var right: Vector3 = (track.point(d,1)-center).normalized()
	var forward: Vector3 = (track.point(d+1)-track.point(d-1)).normalized()
	var radius: float = track.half_width(d)+track.rail_setback(d,1)+15
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pieces: Array[Node3D] = []
	var origins: Array[Vector3] = []
	var targets: Array[Vector3] = []
	# 앞뒤 면·윗면·안쪽 면을 닫아 충분한 두께와 깊이를 가진 단면을 만든다.
	for i in range(48):
		var vertices: Array[Vector3] = []
		for step in [i,i+1]:
			var angle: float = PI*step/48
			var erosion := 0.7*sin(angle*13)+0.35*sin(angle*29)
			for outer in [false,true]:
				var rx: float = radius+(6.5+erosion if outer else 0)
				var ry: float = 27+(7.5+erosion if outer else 0)
				for depth in [-1.0,1.0]:
					vertices.append(center+right*cos(angle)*rx+Vector3.UP*(sin(angle)*ry-3)+forward*depth*(6.5+0.6*sin(angle*11)))
		var crown := i >= 16 and i < 32
		var surface := SurfaceTool.new() if crown else st
		var origin := Vector3.ZERO
		if crown:
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for vertex in vertices: origin += vertex/8.0
		for index in [0,4,1,1,4,5,2,3,6,3,7,6,0,2,4,2,6,4,1,5,3,3,5,7]: surface.add_vertex(vertices[index]-origin)
		if crown:
			surface.index()
			surface.generate_normals()
			var piece := StaticBody3D.new()
			piece.collision_layer = 0
			piece.collision_mask = 4
			piece.position = origin
			var face := MeshInstance3D.new()
			face.mesh = surface.commit()
			face.material_override = rock_material()
			piece.add_child(face)
			var collision := CollisionShape3D.new()
			collision.shape = face.mesh.create_convex_shape()
			piece.add_child(collision)
			add_child(piece)
			pieces.append(piece)
			origins.append(origin)
			var at := i-16
			targets.append(track.point(d+(at%4-1.5)*3,(at%3-1)*1.0)+Vector3.UP*(1.5+floor(at/6.0)*1.2))
	st.index()
	st.generate_normals()
	var rock := MeshInstance3D.new()
	rock.name = "CanyonRockArch"
	rock.mesh = st.commit()
	rock.material_override = rock_material()
	add_child(rock)
	manifest.append({"distance":d,"inner_radius":radius,"crown_clearance":24.0,"depth":13.0,"mesh":rock,"crown":pieces})

	falls.append({"distance":d,"pieces":pieces,"origins":origins,"targets":targets,"elapsed":-1.0,"landed":false})

func rock_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sandstone.gdshader")
	mat.set_shader_parameter("rock_detail",preload("res://assets/environment/generated-rock-variants.png"))
	return mat

func reset_effect() -> void:
	for fall in falls:
		fall.elapsed = -1.0
		fall.landed = false
		for i in range(fall.pieces.size()):
			fall.pieces[i].position = fall.origins[i]
			fall.pieces[i].rotation = Vector3.ZERO
			fall.pieces[i].collision_layer = 0

func advance(delta: float, distance: float, lap: int) -> void:
	var d := fposmod(distance,track.length)
	for fall in falls:
		if fall.landed: continue
		if fall.elapsed < 0:
			if lap < 1 or d < fall.distance-260 or d > fall.distance+30: continue
			fall.elapsed = 0.0
		fall.elapsed += delta
		var landed := true
		for i in range(fall.pieces.size()):
			var t := clampf((fall.elapsed-.35-i*.035)/1.65,0,1)
			fall.pieces[i].position = fall.origins[i].lerp(fall.targets[i],t*t)
			fall.pieces[i].rotation.y = sin(i*2.7)*t*.12
			if t >= 1: fall.pieces[i].collision_layer = 2
			else: landed = false
		fall.landed = landed

func safe_lane(distance: float, requested: float) -> float:
	var d := fposmod(distance,track.length)
	for fall in falls:
		if fall.elapsed >= 0 and d > fall.distance-170 and d < fall.distance+35:
			return (-1.0 if requested < 0 else 1.0)*track.half_width(d)*.65
	return requested

func warning(distance: float) -> String:
	var d := fposmod(distance,track.length)
	for fall in falls:
		if fall.elapsed >= 0 and d > fall.distance-280 and d < fall.distance+35:
			return "ARCH COLLAPSE / USE SIDE LANES"
	return ""
