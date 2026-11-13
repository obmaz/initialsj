extends RefCounted
const CollisionData = preload("res://scripts/physics/world_collision_data.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const Scenery = preload("res://scripts/physics/scenery_collision.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")


# 모든 코스와 투어 구간이 공유하는 실제 충돌체 빌더.
# 노면은 보이는 도로·갓길과 같은 삼각형을 사용하며, 장벽은 별도 충돌층에 둔다.
static func body(label: String, faces: PackedVector3Array, layer: int) -> StaticBody3D:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape_body(label, shape, layer)


static func shape_body(label: String, shape: ConcavePolygonShape3D, layer: int) -> StaticBody3D:
	var node := StaticBody3D.new()
	node.name = label
	node.collision_layer = layer
	node.collision_mask = 4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	node.add_child(collision)
	return node


static func append_mesh(out: PackedVector3Array, mesh: Mesh, transform: Transform3D) -> void:
	# 배열 전체를 엔진에서 한 번에 변환한다(정점마다 스크립트를 거치지 않는다).
	out.append_array(transform * mesh.get_faces())


static func frame(section: Node3D, d: float) -> Basis:
	var forward: Vector3 = (section.point(d + 1) - section.point(d - 1)).normalized()
	var right: Vector3 = (section.point(d, 1) - section.point(d, -1)).normalized()
	var up := right.cross(forward).normalized()
	return Basis(forward.cross(up).normalized(), up, -forward).orthonormalized()


static func build(section: Node3D, use_saved: bool = true) -> Node3D:
	var path := Assets.folder(section) + "collision.res"
	if use_saved and ResourceLoader.exists(path):
		var root := saved_root(section)
		add_saved_body(root, 0)
		add_saved_body(root, 1)
		add_saved_body(root, 2)
		convert_traffic(section)
		return root
	var state := begin(section)
	while not walls(section, state, section.length):
		pass
	return finish(state)


static func saved_root(section: Node3D) -> Node3D:
	var path := Assets.folder(section) + "collision.res"
	var data := Pool.fetch(path) as CollisionData
	assert(data != null, "정적 충돌 자료 형식이 올바르지 않습니다: " + path)
	var root := Node3D.new()
	root.name = "WorldCollision"
	root.transform = Assets.placement(section)
	root.set_meta("ground_triangles", data.ground_triangles)
	root.set_meta("barrier_triangles", data.barrier_triangles)
	root.set_meta("solid_triangles", data.solid_triangles)
	root.set_meta("collision_data", data)
	return root


static func add_saved_body(root: Node3D, part: int) -> void:
	var data: CollisionData = root.get_meta("collision_data")
	# 첫 물리 연결도 노면·장벽·풍경 세 프레임으로 나눈다.
	match part:
		0:
			root.add_child(shape_body("RoadSurfaceBody", data.ground, 1))
		1:
			root.add_child(shape_body("BarrierBody", data.barriers, 2))
		2:
			if data.solids != null:
				root.add_child(shape_body("SceneryBody", data.solids, 32))


# 주행 중에 만드는 구간은 begin → walls(여러 번) → finish를 단계로 나눠 부른다.
static func begin(section: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "WorldCollision"
	var ground := PackedVector3Array()
	var barriers := PackedVector3Array()
	var solids := PackedVector3Array()
	# 실제 지형 삼각형만 읽는다. 물·하늘에는 바닥을 추가하지 않는다.
	Scenery.collect(section, section, ground, barriers, solids)
	convert_traffic(section)
	var template := Pool.unit_box()
	# 단위 상자의 삼각형은 한 번만 꺼내 모든 장벽 조각이 재사용한다.
	return {
		"root": root,
		"ground": ground,
		"walls": barriers,
		"solids": solids,
		"unit": template.get_faces(),
		"distance": 0.0
	}


static func convert_traffic(section: Node3D) -> void:
	for child in section.get_children():
		if (
			(child.get_meta("parked_truck", false) or child.get_meta("parked_car", false))
			and not child.get_meta("traffic_converted", false)
		):
			if child is CharacterBody3D:
				continue
			make_traffic(section, child)


# 장벽 상자를 span 미터만큼 이어 붙인다. 끝까지 만들었으면 true.
static func walls(section: Node3D, state: Dictionary, span: float) -> bool:
	var barriers: PackedVector3Array = state.walls
	var unit: PackedVector3Array = state.unit
	# Straight stretches use 8 m boxes (every car sweeps against the wall mesh each frame, so fewer
	# triangles are cheaper). On bends a long straight box would leave the curved rail by
	# (L/2)^2/(2R), so tight bends keep 4 m boxes and the tightest 2 m ones.
	var d: float = state.distance
	var stop := minf(section.length, d + span)
	while d < stop:
		var bend: float = absf(wrapf(section.heading(d + 10) - section.heading(d - 10), -PI, PI)) / 20.0
		var step := 8.0 if bend < 0.004 else (4.0 if bend < 0.012 else 2.0)
		step = minf(step, section.length - d)
		var middle := d + step * 0.5
		var basis := frame(section, middle)
		for side in [-1.0, 1.0]:
			if not section.closed_loop and middle < 115 + section.entry_buffer_length and side == -section.entry_side:
				continue
			var lane: float = side * (section.half_width(middle) + section.rail_setback(middle, side))
			var wall_basis := basis
			var size := Vector3(.30, 1.45, step + .35)
			var center: Vector3 = section.point(middle, lane) + basis.y * .65
			if section.closed_loop and section.course_id == 1 and (side > 0 or section.speedway_pit_wall(middle)):
				var forward := -basis.z
				forward.y = 0
				wall_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
				# 상단 철망도 충돌을 막는다. 콘크리트와 같은 횡단면을 사용한다.
				var height := 5.6 if side > 0 else 1.5
				size = Vector3(.60, height, step + .35)
				center = section.point(middle, lane) + Vector3.UP * height * .5
			barriers.append_array(Transform3D(wall_basis.scaled_local(size), center) * unit)
		d += step
	state.walls = barriers
	state.distance = d
	return d >= section.length


static func finish(state: Dictionary) -> Node3D:
	var root: Node3D = state.root
	var ground: PackedVector3Array = state.ground
	var barriers: PackedVector3Array = state.walls
	# 노면 충돌체는 단계로 나눠 만드는 쪽이 미리 만들어 둘 수 있다.
	root.add_child(state.get("ground_body", null) if state.has("ground_body") else body("RoadSurfaceBody", ground, 1))
	root.add_child(body("BarrierBody", barriers, 2))
	if not state.solids.is_empty():
		root.add_child(body("SceneryBody", state.solids, 32))
	root.set_meta("solid_triangles", state.solids.size() / 3)
	root.set_meta("ground_triangles", ground.size() / 3)
	root.set_meta("barrier_triangles", barriers.size() / 3)
	return root


# 기존 GLB 외형에 교통 차체를 연결한다. 승용차와 트럭은 크기·순항 속도만 다르다.
static func make_traffic(section: Node3D, visual: Node3D) -> void:
	visual.set_meta("traffic_converted", true)
	var motor := preload("res://scripts/race/tour_traffic.gd").new()
	var passenger: bool = visual.get_meta("parked_car", false)
	motor.name = "PassengerTrafficBody" if passenger else "TruckTrafficBody"
	motor.set_meta("parked_car" if passenger else "parked_truck", true)
	motor.road = section
	motor.visual = visual
	motor.cruise_speed = 18 if passenger else 12
	motor.distance = section.curve.get_closest_offset(visual.global_position)
	var right: Vector3 = (section.point(motor.distance, 1) - section.point(motor.distance)).normalized()
	motor.lane = (visual.global_position - section.point(motor.distance)).dot(right)
	motor.contact_shape.shape.size = Vector3(2.05, 1.5, 4.5) if passenger else Vector3(2.7, 3.5, 11.0)
	motor.contact_shape.position.y = 0.0 if passenger else 1.1
	var nearest := INF
	for feature in section.features:
		if feature.kind == ("car" if passenger else "truck") and absf(float(feature.distance) - motor.distance) < 30:
			var score := absf(float(feature.distance) - motor.distance) + absf(float(feature.lane) - motor.lane) * 8
			if score < nearest:
				nearest = score
				motor.feature_record = feature
	section.add_child(motor)
	motor.configure(preload("res://scripts/vehicles/vehicle_catalog.gd").spec(0))
	motor.reset_pose(visual.global_position, -visual.global_basis.z, visual.global_basis.y)
	preload("res://scripts/vehicles/tour_traffic_appearance.gd").attach(motor)
