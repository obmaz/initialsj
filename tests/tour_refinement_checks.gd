extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	Pool.acquire_owner()
	for side in [-1, 0, 1]:
		var pyramid = Section.new(Vector3(0, 6, 0), -PI / 2, 2, 0, side)
		tree.root.add_child(pyramid)
		var mesh: Mesh = pyramid.scenery.batches[0].multimesh.mesh
		check(mesh.get_faces().size() == 18, "피라미드는 사각 밑면 두 면과 네 경사면이어야 한다")
		pyramid.free()
		for pair in [[1, 1], [3, 1]]:
			var road = Section.new(Vector3(0, 6, 0), -PI / 2, pair[0], pair[1], side)
			tree.root.add_child(road)
			check(
				(
					road.has_node("UrbanUnderpass")
					and road.in_tunnel((road.tour_underpass.x + road.tour_underpass.y) * .5)
				),
				"모든 진입 방향에서 도시·서울 지하차도와 터널 판정을 연결한다"
			)
			check(road.get_node("UrbanUnderpass").mesh.get_faces().size() > 1000, "옹벽·상부 보도·횡단도로는 입체 GLB로 렌더한다")
			road.free()
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for mode in ["tour", "track"]:
		race.choose_mode(mode, 1)
		race.restart()
		race.state = "racing"
		for r in race.rivals:
			r.active = false
		var d = 80.
		var edge = race.track.half_width(d) + race.track.active.rail_setback(d, 1)
		var f = (race.track.point(d + 2) - race.track.point(d - 2)).normalized()
		var right = (race.track.point(d, 1) - race.track.point(d)).normalized()
		var body = race.world_race.player_body
		race.world_race.teleport(0, d, edge - 1.15)
		body.reset_pose(race.track.point(d, edge - 1.15), (f + right * .5).normalized(), race.world_race.road_up(d))
		body.velocity = body.forward_direction() * 45
		race.speed = 45
		await tree.physics_frame
		var peak = 0.
		for frame in range(120):
			await tree.physics_frame
			race.step(1. / 60, 0, false, true, false)
			peak = maxf(peak, race.distance - d)
		check(peak > 35 and race.speed > 12, "레일에 비스듬히 붙은 차도 진행 방향으로 빠져나와 정지 없이 전진한다: " + mode)
	race.free()
	await tree.process_frame
	if Pool.release_owner():
		preload("res://scripts/environment/regional_props_3d.gd").clear_cache()
		preload("res://scripts/environment/tour_vegetation.gd").clear_cache()
		preload("res://scripts/environment/advertisement_library.gd").clear_cache()
	print("사각 피라미드 / 투어 입체 지하차도 / 레일 끼임 전진 복귀: ", "PASS" if failures == 0 else "FAIL")
	return failures
