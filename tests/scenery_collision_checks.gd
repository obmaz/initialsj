extends RefCounted
const Scenery = preload("res://scripts/physics/scenery_collision.gd")
const Collision = preload("res://scripts/physics/world_collision.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const Section = preload("res://scripts/track/road_section.gd")
const Car = preload("res://scripts/physics/world_car.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	Pool.acquire_owner()
	var section := Section.new()
	section.closed_loop = true
	section.course_id = 0
	tree.root.add_child(section)
	var collision := Collision.build(section)
	section.add_child(collision)
	await tree.physics_frame
	await tree.physics_frame
	var space := section.get_world_3d().direct_space_state
	var found := {}
	for node in Assets.nodes(section):
		var type := Scenery.kind(node)
		if type not in ["rock", "trunk", "solid"] or found.has(type):
			continue
		var frames := Scenery.transforms(node, section)
		if frames.is_empty():
			continue
		var geometry := Scenery.faces(Scenery.mesh_for(node), type)
		var bounds := AABB(geometry[0], Vector3.ZERO)
		for vertex in geometry:
			bounds = bounds.expand(vertex)
		var frame: Transform3D = section.global_transform * frames[0]
		var center := bounds.get_center()
		var from := frame * (center - Vector3(bounds.size.x * .6 + 2, 0, 0))
		var to := frame * (center + Vector3(bounds.size.x * .6 + 2, 0, 0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 32))
		check(not hit.is_empty(), "실제 후지 풍경에는 충돌체가 있어야 한다: " + type)
		# 고속 차량 한 틱의 스윕도 얇은 표면을 통과하지 않아야 한다.
		var sweep := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(.1, .1, .1)
		sweep.shape = shape
		sweep.collision_mask = 32
		sweep.transform.origin = from
		sweep.motion = to - from
		check(space.cast_motion(sweep)[0] < 1, "풍경 충돌은 스윕에서도 잡혀야 한다: " + type)
		found[type] = true
	check(found.has("rock") and found.has("trunk") and found.has("solid"), "바위·나무·구조물 실물 표본을 검사한다: " + str(found))
	var floor_samples := 0
	for node in Assets.nodes(section):
		if Scenery.kind(node) != "ground" or node == section.road_surface or node.name == "RoadBase":
			continue
		for frame in Scenery.transforms(node, section):
			var mesh := Scenery.mesh_for(node)
			var vertices := mesh.get_faces()
			if vertices.size() < 3:
				continue
			var at: Vector3 = section.global_transform * frame * ((vertices[0] + vertices[1] + vertices[2]) / 3)
			var floor_hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(at + Vector3.UP, at - Vector3.UP, 1)
			)
			check(not floor_hit.is_empty(), "도로 밖 실제 지형 삼각형 위에도 바닥이 존재한다")
			floor_samples += 1
			if floor_samples >= 3:
				break
		if floor_samples >= 3:
			break
	check(floor_samples > 0, "도로 밖 지형 표본을 검사한다")
	# MultiMesh 읽기값에 의존하지 않고 보존된 배치를 검사한다.
	var multi := MultiMeshInstance3D.new()
	multi.multimesh = MultiMesh.new()
	multi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multi.multimesh.mesh = Pool.unit_box()
	multi.multimesh.instance_count = 1
	multi.set_meta("world_ground", true)
	multi.set_meta("collision_transforms", [Transform3D(Basis.IDENTITY, Vector3(7000, 0, 0))])
	section.add_child(multi)
	var ground := PackedVector3Array()
	Scenery.collect(multi, section, ground, PackedVector3Array(), PackedVector3Array())
	check(ground.size() == 36 and ground[0].x > 6999, "MultiMesh 지형도 CPU 배치 위치에 충돌체를 만든다")
	var car := Car.new()
	check(car.collision_mask == 47 and (Car.PROTECTED_COLLISION_MASK & 32) != 0, "풍경 충돌은 복구 보호 중에도 유지한다")
	car.free()
	section.free()
	Pool.release_owner()
	print("도로 밖 풍경·지형 실제 레이/스윕 충돌 검사: ", "PASS" if failures == 0 else "FAIL")
	return failures
