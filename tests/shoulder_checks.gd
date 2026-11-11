extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


# GLB 임포트의 정점 재정렬과 무관하게 실제 삼각형 경계·깊이를 확인한다.
func boundary_length(mesh: Mesh) -> float:
	var ids := {}
	var edges := {}
	var lengths := {}
	var faces := mesh.get_faces()
	for triangle in range(0, faces.size(), 3):
		for side in range(3):
			var a := faces[triangle + side].snapped(Vector3.ONE * .001)
			var b := faces[triangle + (side + 1) % 3].snapped(Vector3.ONE * .001)
			for point in [a, b]:
				if not ids.has(point):
					ids[point] = ids.size()
			var key := Vector2i(mini(ids[a], ids[b]), maxi(ids[a], ids[b]))
			edges[key] = edges.get(key, 0) + 1
			lengths[key] = a.distance_to(b)
	var result := 0.0
	for key in edges:
		if edges[key] == 1:
			result += lengths[key]
	return result


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var rows := []
	for choice in [["tour", 0], ["track", 0]]:
		race.choose_mode(choice[0], choice[1])
		var section: Node3D = race.track.active
		var rail: MeshInstance3D = section.get_node("ContinuousGuardrails")
		check(
			rail.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() > 3000,
			"Guardrails must be indexed continuous curved ribbons"
		)
		check(boundary_length(rail.mesh) < 35, "레일의 긴 뒤판·상하면은 닫히고 구간 끝의 짧은 경계만 남아야 한다")
		var vertices: PackedVector3Array = rail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var origin: Vector3 = section.point(0)
		var forward: Vector3 = (section.point(2) - origin).normalized()
		var lateral: Vector3 = (section.point(0, 1) - section.point(0)).normalized()
		var low := INF
		var high := -INF
		for point in vertices:
			var relative := point - origin
			if absf(relative.dot(forward)) < .2 and relative.dot(lateral) < 0:
				low = minf(low, relative.dot(lateral))
				high = maxf(high, relative.dot(lateral))
		check(high - low > .30, "레일은 종이 띠가 아닌30cm 이상의 입체 깊이를 가져야 한다")
		var case_mesh: Mesh = section.get_node("CurveSignCases").multimesh.mesh
		var size := case_mesh.get_aabb().size
		check(size.z >= .2 and size.x > 3 and size.y > 1.5, "화살표 인쇄면 뒤에는 두꺼운 케이스와 테두리가 있어야 한다")
		var widest := 0.0
		var at := 0.0
		var minimum_radius_margin := INF
		for i in range(1000):
			var d: float = section.length * i / 1000
			var outer: float = maxf(section.rail_setback(d, -1), section.rail_setback(d, 1))
			if section.rail_setback(d, 1) > widest:
				widest = section.rail_setback(d, 1)
				at = d
			var bend: float = absf(wrapf(section.heading(d + 1) - section.heading(d - 1), -PI, PI)) / 2
			if bend > 0.0001:
				minimum_radius_margin = minf(minimum_radius_margin, 1 / bend - section.half_width(d) - outer)
		check(minimum_radius_margin > 0.5, "Inner guardrails must not fold across themselves on sharp corners")
		check(widest > 6, "Tour and Fuji must have visibly wider roadside runoff areas")
		check(section.has_node("WorldCollision"), "투어와 트랙 모두 갓길과 장벽의 실제 충돌체가 있어야 한다")
		rows.append(
			{
				"mode": choice[0],
				"course": choice[1],
				"maximum_setback_m": widest,
				"minimum_inner_radius_margin_m": minimum_radius_margin,
				"controller": "world-space"
			}
		)
	FileAccess.open(Report.path("shoulder-metrics.json"), FileAccess.WRITE).store_string(
		JSON.stringify({"cases": rows, "failures": failures}, "\t") + "\n"
	)
	print("Curved guardrails / wider dirt shoulders / matching collisions: ", "PASS" if failures == 0 else "FAIL")
	race.queue_free()
	await tree.process_frame
	return failures
