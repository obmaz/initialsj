extends Node3D
# 차량이 통과한 뒤 오른쪽 상판이 뒤따라 무너진다. 파손은 레이스가 끝날 때까지 남는다.
const PIECES := 9
const PIECE_LENGTH := 12.0
var fall_times: Array[float] = []
var broken := false
var wreckage: Node3D
var section: Node3D
var span := Vector2(421,529)
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
	for i in range(PIECES):
		var chunk := Node3D.new()
		var d := span.x+(i+0.5)*PIECE_LENGTH
		chunk.position = section.point(d,section.surface_lane((lanes.x+lanes.y)*0.5,d))
		origins.append(chunk.position)
		chunks.append(chunk)
		fall_times.append(-1.0)
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
	var broken_used: Array[bool] = []
	broken_used.resize(PIECES)
	broken_used.fill(false)
	for i in range(PIECES):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		broken.append(st)
	var count := int(ceil((section.length-begin)/2))
	for i in range(count):
		var a: float = begin+(section.length-begin)*i/count
		var b: float = begin+(section.length-begin)*(i+1)/count
		var cuts: Array[float] = [a,b]
		for edge_index in range(PIECES+1):
			var edge: float = span.x+edge_index*PIECE_LENGTH
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
			var chunk := clampi(int((middle-span.x)/PIECE_LENGTH),0,PIECES-1)
			append_quad(broken[chunk],first,last,maxf(left,lanes.x),minf(right,lanes.y),height,origins[chunk])
			broken_used[chunk] = true
	fixed.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = fixed.commit()
	node.material_override = mat
	section.add_child(node)
	for i in range(PIECES):
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
	for i in range(PIECES):
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
		var d := span.x+(i+0.5)*PIECE_LENGTH
		var width: float = section.surface_lane(lanes.y,d)-section.surface_lane(lanes.x,d)
		var slab := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width,1.8,PIECE_LENGTH+.06)
		slab.mesh = mesh
		slab.basis = Basis(Vector3.UP,section.heading(d))
		slab.position.y = -1.05
		slab.material_override = concrete
		chunks[i].add_child(slab)
		var stripe := SurfaceTool.new()
		stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
		append_quad(stripe,span.x+i*PIECE_LENGTH,span.x+(i+1)*PIECE_LENGTH,4.4,4.6,0.028,origins[i])
		stripe.generate_normals()
		var line := MeshInstance3D.new()
		line.mesh = stripe.commit()
		line.material_override = section.paint(Color("f9f6df"))
		chunks[i].add_child(line)
	cracks = Node3D.new()
	add_child(cracks)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("252622")
	for row in range(37):
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
	cracks.visible = false
	make_wreckage(concrete)
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

func make_wreckage(concrete: Material) -> void:
	wreckage = Node3D.new()
	wreckage.name = "PersistentBrokenDeck"
	add_child(wreckage)
	var steel: Material = section.material(Color("534c42"),.45)
	var teeth: Array[Transform3D] = []
	var rods: Array[Transform3D] = []
	# 반복 파단면·철근은 두 배치로 렌더링하며 통과로 바깥에 둔다.
	for i in range(37):
		var d: float = span.x+i*3
		var edge: Vector3 = section.point(d,section.surface_lane(lanes.x,d))
		teeth.append(Transform3D(Basis.from_euler(Vector3(.12*(i%3),section.heading(d),.15*(i%2))).scaled_local(Vector3(.6+(i%3)*.2,1.3,2.7)),edge-Vector3.UP*.6))
		rods.append(Transform3D(Basis.from_euler(Vector3(.3,section.heading(d)+PI*.45,.1)).scaled_local(Vector3(.055,.055,1.7)),edge+Vector3.UP*.1))
	var tooth := PrismMesh.new()
	tooth.size = Vector3.ONE
	wreck_batch(tooth,concrete,teeth)
	var rod := BoxMesh.new()
	rod.size = Vector3.ONE
	wreck_batch(rod,steel,rods)
	for d in [span.x-12,span.y+12]:
		var sign := Label3D.new()
		sign.text = "BROKEN BRIDGE\nKEEP LEFT"
		sign.font = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
		sign.font_size = 72
		sign.pixel_size = .018
		sign.modulate = Color("ffcf55")
		sign.outline_size = 12
		sign.position = section.point(d,section.surface_lane(6,d))+Vector3.UP*3
		sign.rotation.y = section.heading(d)
		sign.no_depth_test = false
		wreckage.add_child(sign)
		var board := BoxMesh.new()
		board.size = Vector3(10,3,.18)
		wreck_batch(board,section.material(Color("211e17")),[Transform3D(sign.basis,sign.position-sign.basis.z*.1)])
		var post := BoxMesh.new()
		post.size = Vector3(.16,3,.16)
		var poles: Array[Transform3D] = []
		for side in [-1.0,1.0]: poles.append(Transform3D(sign.basis,sign.position+sign.basis.x*side*4-Vector3.UP*1.5))
		wreck_batch(post,steel,poles)
	wreckage.visible = false

func wreck_batch(mesh: Mesh, mat: Material, poses: Array[Transform3D]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()): multi.set_instance_transform(i,poses[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	wreckage.add_child(node)

func reset_effect() -> void:
	elapsed = -1
	broken = false
	for i in range(chunks.size()):
		fall_times[i] = -1
		chunks[i].transform = Transform3D(Basis.IDENTITY,origins[i])
		chunks[i].visible = true
		floors[i].collision_layer = 1
	cracks.visible = false
	wreckage.visible = false
	dust.emitting = false

func advance(delta: float, distance: float, reduced_motion: bool = false) -> void:
	var d := fposmod(distance,section.length)
	if elapsed < 0:
		if d < span.x-220 or d > span.y+50: return
		elapsed = 0
	elapsed += delta
	cracks.visible = not broken
	for i in range(cracks.get_child_count()): cracks.get_child(i).visible = elapsed > (i%9)*.12
	# 차체 뒷부분이 각 상판을 넘은 뒤 낙하한다. 다음 바퀴에도 낙하 상태를 유지한다.
	for i in range(PIECES):
		if fall_times[i] < 0:
			if distance < span.x+(i+1)*PIECE_LENGTH+7: continue
			fall_times[i] = 0
		fall_times[i] += delta
		var t := maxf(0,fall_times[i]-.22)
		if t <= 0: continue
		floors[i].collision_layer = 0
		if not broken:
			broken = true
			wreckage.visible = true
			if DisplayServer.get_name() != "headless" and not reduced_motion:
				dust.position = origins[i]+Vector3.UP*.5
				dust.restart()
				dust.emitting = true
		# 부서진 상판을 아래에 남겨 다음 바퀴에도 붕괴 흔적이 보인다.
		chunks[i].position = origins[i]+Vector3(0,-minf(14+i*.6,12*t*t),0)
		chunks[i].rotation = Vector3(minf(t,.9)*.28*(i%3-1),0,minf(t,1.2)*.45)
		chunks[i].visible = true
	cracks.visible = not broken

func warning(distance: float) -> String:
	var d := fposmod(distance,section.length)
	if d < span.x-260 or d > span.y+35: return ""
	return "BRIDGE DESTROYED / KEEP LEFT" if broken else "BRIDGE CRACKING / KEEP LEFT"
