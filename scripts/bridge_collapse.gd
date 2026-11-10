extends Node3D
# 오른쪽 차선의 실제 상판 세 조각이 떨어진다. 왼쪽 통과로와 다리 주 구조는 유지한다.
var section: Node3D
var span := Vector2(421,439)
var lanes := Vector2(2.8,8.2)
var elapsed := -1.0
var chunks: Array[Node3D] = []
var origins: Array[Vector3] = []
var floors: Array[StaticBody3D] = []
var floor_faces: Array[PackedVector3Array] = []
var cracks: Node3D
var dust: CPUParticles3D

func configure(road: Node3D) -> void:
	section = road
	for i in range(3):
		var chunk := Node3D.new()
		var d := span.x+(i+0.5)*(span.y-span.x)/3
		chunk.position = section.point(d,section.surface_lane((lanes.x+lanes.y)*0.5,d))
		origins.append(chunk.position)
		chunks.append(chunk)
		floor_faces.append(PackedVector3Array())
		add_child(chunk)

func contains(d: float, reference: float) -> bool:
	return d >= span.x and d <= span.y and reference > lanes.x and reference < lanes.y

func inside_span(d: float) -> bool:
	return d >= span.x and d <= span.y

func append_quad(st: SurfaceTool, a: float, b: float, left: float, right: float, height: float, origin: Vector3 = Vector3.ZERO) -> void:
	var points := [section.point(a,section.surface_lane(left,a)),section.point(a,section.surface_lane(right,a)),section.point(b,section.surface_lane(left,b)),section.point(b,section.surface_lane(right,b))]
	var uv := [Vector2(left/6,a/6),Vector2(right/6,a/6),Vector2(left/6,b/6),Vector2(right/6,b/6)]
	for index in [0,2,1,1,2,3]:
		st.set_uv(uv[index])
		st.add_vertex(points[index]+Vector3.UP*(height+section.surface_lift)-origin)

func make_strip(left: float, right: float, height: float, mat: Material, begin: float) -> MeshInstance3D:
	var fixed := SurfaceTool.new()
	fixed.begin(Mesh.PRIMITIVE_TRIANGLES)
	var broken: Array[SurfaceTool] = []
	var broken_used := [false,false,false]
	for i in range(3):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		broken.append(st)
	var count := int(ceil((section.length-begin)/2))
	for i in range(count):
		var a: float = begin+(section.length-begin)*i/count
		var b: float = begin+(section.length-begin)*(i+1)/count
		var cuts: Array[float] = [a,b]
		for edge in [span.x,span.x+6,span.x+12,span.y]:
			if edge > a and edge < b: cuts.append(edge)
		cuts.sort()
		for j in range(cuts.size()-1):
			var first := cuts[j]
			var last := cuts[j+1]
			var middle := (first+last)*0.5
			if not inside_span(middle) or right <= lanes.x or left >= lanes.y:
				append_quad(fixed,first,last,left,right,height)
				continue
			if left < lanes.x: append_quad(fixed,first,last,left,lanes.x,height)
			if right > lanes.y: append_quad(fixed,first,last,lanes.y,right,height)
			var chunk := clampi(int((middle-span.x)/6),0,2)
			append_quad(broken[chunk],first,last,maxf(left,lanes.x),minf(right,lanes.y),height,origins[chunk])
			broken_used[chunk] = true
	fixed.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = fixed.commit()
	node.material_override = mat
	section.add_child(node)
	for i in range(3):
		if not broken_used[i]: continue
		broken[i].generate_normals()
		var piece := MeshInstance3D.new()
		piece.mesh = broken[i].commit()
		piece.material_override = mat
		chunks[i].add_child(piece)
		if is_zero_approx(height): floor_faces[i] = piece.mesh.get_faces()
	return node

func finish_geometry() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("77786f")
	concrete.roughness = 0.96
	for i in range(3):
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 4
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(floor_faces[i])
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		chunks[i].add_child(body)
		floors.append(body)
		var d := span.x+(i+0.5)*6
		var width: float = section.surface_lane(lanes.y,d)-section.surface_lane(lanes.x,d)
		var slab := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width,1.8,6.06)
		slab.mesh = mesh
		slab.basis = Basis(Vector3.UP,section.heading(d))
		slab.position.y = -1.05
		slab.material_override = concrete
		chunks[i].add_child(slab)
		var stripe := SurfaceTool.new()
		stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
		append_quad(stripe,span.x+i*6,span.x+(i+1)*6,4.4,4.6,0.028,origins[i])
		stripe.generate_normals()
		var line := MeshInstance3D.new()
		line.mesh = stripe.commit()
		line.material_override = section.paint(Color("f9f6df"))
		chunks[i].add_child(line)
	cracks = Node3D.new()
	add_child(cracks)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("252622")
	for row in range(7):
		var d: float = span.x+row*3
		var fracture := SurfaceTool.new()
		fracture.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in range(9):
			var left: float = lanes.x+(lanes.y-lanes.x)*part/9
			var right: float = lanes.x+(lanes.y-lanes.x)*(part+1)/9
			append_quad(fracture,d+sin(part*2.3)*0.32,d+sin(part*2.3)*0.32+0.11,left,right,0.035)
		fracture.generate_normals()
		var mark := MeshInstance3D.new()
		mark.mesh = fracture.commit()
		mark.material_override = dark
		cracks.add_child(mark)
	dust = CPUParticles3D.new()
	dust.position = section.point((span.x+span.y)*0.5,section.surface_lane(5.5,span.x))
	dust.amount = 28
	dust.lifetime = 1.5
	dust.one_shot = true
	dust.emitting = false
	dust.direction = Vector3.UP
	dust.spread = 75
	dust.initial_velocity_min = 3
	dust.initial_velocity_max = 8
	dust.gravity = Vector3(0,-5,0)
	dust.scale_amount_min = 0.3
	dust.scale_amount_max = 1.2
	var debris := SphereMesh.new()
	debris.radius = 0.25
	debris.height = 0.5
	debris.radial_segments = 6
	debris.rings = 3
	dust.mesh = debris
	dust.material_override = concrete
	add_child(dust)

func reset_effect() -> void:
	elapsed = -1
	for i in range(chunks.size()):
		chunks[i].transform = Transform3D(Basis.IDENTITY,origins[i])
		chunks[i].visible = true
		floors[i].collision_layer = 1
	cracks.visible = true
	dust.emitting = false

func advance(delta: float, distance: float, reduced_motion: bool = false) -> void:
	var d := fposmod(distance,section.length)
	if elapsed < 0:
		if d < span.x-150 or d > span.y+30: return
		elapsed = 0
	elapsed += delta
	for i in range(3):
		var t := maxf(0,elapsed-0.65-i*0.08)
		if t <= 0: continue
		floors[i].collision_layer = 0
		chunks[i].position = origins[i]+Vector3(0,-12*t*t,0)
		chunks[i].rotation = Vector3(t*0.28*(i-1),0,t*0.45)
		chunks[i].visible = t < 2.6
	if elapsed > 0.65 and cracks.visible:
		cracks.visible = false
		if DisplayServer.get_name() != "headless" and not reduced_motion:
			dust.restart()
			dust.emitting = true

func warning(distance: float) -> String:
	var d := fposmod(distance,section.length)
	return "BRIDGE DAMAGE / KEEP LEFT" if d > span.x-260 and d < span.y+35 else ""
