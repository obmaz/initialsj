extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
const Collision = preload("res://scripts/physics/world_collision.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const Warmup = preload("res://scripts/rendering/material_warmup.gd")
const Retirement = preload("res://scripts/rendering/scene_retirement.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func compare_shapes(road: Node3D) -> void:
	var saved := Collision.build(road)
	var built := Collision.build(road, false)
	for label in ["RoadSurfaceBody", "BarrierBody"]:
		var a: ConcavePolygonShape3D = saved.get_node(label).get_child(0).shape
		var b: ConcavePolygonShape3D = built.get_node(label).get_child(0).shape
		var actual := saved.transform * a.get_faces()
		var expected := b.get_faces()
		check(
			actual.size() == expected.size() and a.backface_collision == b.backface_collision,
			"저장 충돌은 모든 삼각형·양면 규칙을 보존한다"
		)
		var error := 0.0
		for i in range(mini(actual.size(), expected.size())):
			error = maxf(error, actual[i].distance_to(expected[i]))
		check(
			error < .01,
			"회전·위치가 다른 투어 진입에서도 정적 충돌은 기존 형상과1cm 이내로 일치한다: %s/%s" % [road.name, label] + " error=" + str(error)
		)
		check(saved.get_node(label).collision_layer == built.get_node(label).collision_layer, "노면·장벽 충돌층을 유지한다")
	check(saved.has_meta("collision_data"), "활성 충돌 노드가 공유 자료의 수명을 소유한다")
	saved.free()
	built.free()


func run(tree: SceneTree) -> int:
	Pool.acquire_owner()
	for spec in [Vector3i(0, 0, 0), Vector3i(1, 0, -1), Vector3i(3, 1, 1)]:
		var road: Node3D = Section.new(Vector3(7300, 80, -2100), .71, spec.x, spec.y, spec.z)
		tree.root.add_child(road)
		compare_shapes(road)
		var one := Warmup.new()
		var sliced := Warmup.new()
		one.collect(road)
		sliced.collection.assign(road.get_children())
		sliced.collection.reverse()
		var expired := Node.new()
		sliced.collection.append(expired)
		expired.free()
		var calls := 0
		while not sliced.collect_some(0):
			calls += 1
		check(calls > 20 and sliced.collection.is_empty(), "다음 구간의 재질 수집도 여러 프레임으로 나누며 완료 후 관측 참조를 비운다")
		check(one.keys.size() == sliced.keys.size(), "분할 수집은 동기 수집의 재질·인스턴싱 변형을 빠뜨리지 않는다")
		for key in one.keys:
			check(sliced.keys.has(key), "분할 준비는 같은 셰이더·재질 조합을 수집한다")
		one.free()
		sliced.free()
		road.free()
		await tree.process_frame
	var course: Node3D = Section.new()
	course.closed_loop = true
	course.course_id = 1
	tree.root.add_child(course)
	compare_shapes(course)
	var scheduler := preload("res://scripts/track/track.gd").new()
	course.staged = true
	course.visible = false
	scheduler.stage_world_collision(course)
	var saved := course.get_node("WorldCollision")
	check(saved.get_child_count() == 0 and not course.visible, "저장 충돌을 붙이기 전에는 다음 구간을 공개하지 않는다")
	course.build_some(0)
	check(saved.get_child_count() == 1 and not course.visible, "첫 물리 준비는 노면 하나만 연결한다")
	course.build_some(0)
	check(saved.get_child_count() == 2 and not course.visible, "장벽 첫 연결은 노면과 다른 단계에서 처리한다")
	while course.build_pending():
		course.build_some(0)
	check(course.visible, "모든 충돌·재질 준비가 끝나야 구간을 공개한다")
	scheduler.free()
	course.free()
	await tree.process_frame
	# 헤드리스에서도 해제 순서·즉시 충돌 제거를 실제 노드로 확인한다.
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var source := Node3D.new()
	holder.add_child(source)
	var collider := StaticBody3D.new()
	add_body_fixture(source, collider)
	for i in range(40):
		var leaf := Node3D.new()
		leaf.name = "Leaf%d" % i
		source.add_child(leaf)
	var worker := Retirement.new()
	holder.add_child(worker)
	worker.set_process(false)
	worker.schedule(source)
	check(
		not source.visible and source.process_mode == Node.PROCESS_MODE_DISABLED, "지난 구간은 자원 해제를 기다리는 동안 보이거나 처리되지 않는다"
	)
	check(
		(
			collider.collision_layer == 0
			and collider.collision_mask == 0
			and not collider.is_in_group("tour_road_traffic")
		),
		"지난 차량의 충돌·추월 관측 그룹을 즉시 제거한다"
	)
	var remaining := worker.pending.size()
	# 완료 직후 queue_free되는 준비 작업처럼 관측 목록에만 남은 노드는 건너뛴다.
	source.get_child(source.get_child_count() - 1).free()
	worker.drain(0)
	check(worker.pending.size() == remaining - 1 and is_instance_valid(source), "한 번의 해제 예산이0이면 자식 하나만 정리한다")
	while not worker.pending.is_empty():
		check(worker.drain(1000000) <= Retirement.NODE_LIMIT, "여유가 있어도 한 프레임 노드 해제 수를 제한한다")
	check(not is_instance_valid(source), "자식부터 해제한 뒤 구간 루트까지 남기지 않는다")
	holder.free()
	Pool.release_owner()
	await tree.process_frame
	print("저장 충돌 동일 형상·회전 / 재질 분할 준비 / 즉시 충돌 차단·분산 해제: ", "PASS" if failures == 0 else "FAIL")
	return failures


func add_body_fixture(parent: Node, collider: StaticBody3D) -> void:
	parent.add_child(collider)
	collider.collision_layer = 3
	collider.add_to_group("tour_road_traffic")
