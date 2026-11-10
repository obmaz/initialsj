extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var rows := []
	for choice in [["tour",0],["track",0]]:
		race.choose_mode(choice[0],choice[1])
		var section: Node3D = race.track.active
		var rail: MeshInstance3D = section.get_node("ContinuousGuardrails")
		check(rail.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() > 3000,"Guardrails must be indexed continuous curved ribbons")
		var vertices: PackedVector3Array = rail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(vertices[0].distance_to(vertices[7]) < .001,"레일 단면은 뒤판과 상하 면이 닫혀 있어야 한다")
		check(vertices[0].distance_to(vertices[6]) > .30,"레일은 종이 띠가 아닌30cm 이상의 입체 깊이를 가져야 한다")
		var case_mesh: BoxMesh = section.get_node("CurveSignCases").multimesh.mesh
		check(case_mesh.size.z >= .2 and case_mesh.size.x > 3 and case_mesh.size.y > 1.5,"화살표 인쇄면 뒤에는 두꺼운 케이스와 테두리가 있어야 한다")
		var widest := 0.0
		var at := 0.0
		var minimum_radius_margin := INF
		for i in range(1000):
			var d: float = section.length*i/1000
			var outer: float = maxf(section.rail_setback(d,-1),section.rail_setback(d,1))
			if section.rail_setback(d,1) > widest: widest = section.rail_setback(d,1); at = d
			var bend: float = absf(wrapf(section.heading(d+1)-section.heading(d-1),-PI,PI))/2
			if bend > 0.0001: minimum_radius_margin = minf(minimum_radius_margin,1/bend-section.half_width(d)-outer)
		check(minimum_radius_margin > 0.5,"Inner guardrails must not fold across themselves on sharp corners")
		check(widest > 6,"Tour and Fuji must have visibly wider roadside runoff areas")
		check(section.has_node("FujiWorldCollision"),"투어와 트랙 모두 갓길과 장벽의 실제 충돌체가 있어야 한다")
		rows.append({"mode":choice[0],"course":choice[1],"maximum_setback_m":widest,"minimum_inner_radius_margin_m":minimum_radius_margin,"controller":"world-space"})
	FileAccess.open(Report.path("shoulder-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures},"\t")+"\n")
	print("Curved guardrails / wider dirt shoulders / matching collisions: ","PASS" if failures == 0 else "FAIL")
	race.queue_free()
	await tree.process_frame
	return failures
