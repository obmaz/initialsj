extends RefCounted
const Report = preload("res://tests/report.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const Ads = preload("res://scripts/environment/advertisement_library.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func settle(tree: SceneTree) -> void:
	for frame in range(4):
		await tree.process_frame


func sample() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC))
	}


func run(tree: SceneTree) -> int:
	await settle(tree)
	var baseline := sample()
	var viewport_was_disabled: bool = tree.root.disable_3d
	var saved_ad_seed: int = Ads.rng.seed
	var saved_ad_state: int = Ads.rng.state
	var rows := []
	for session in range(2):
		var r = load("res://scenes/race.tscn").instantiate()
		tree.root.add_child(r)
		r.set_physics_process(false)
		r.save_records = false
		r.sound_enabled = false
		for value in ["menu", "courses", "ready", "settings"]:
			r.state = value
			check(
				(
					tree.root.disable_3d
					and not r.track.visible
					and (not r.track.scenery.has_method("_process") or not r.track.scenery.is_processing())
				),
				"Opaque menu screens must stop the main 3D render and scenery processing"
			)
		r.warming_world = true
		check(not tree.root.disable_3d and r.track.visible, "Covered prewarming must still render the actual world")
		r.warming_world = false
		for value in ["racing", "countdown", "paused", "finished"]:
			r.state = value
			check(
				(
					not tree.root.disable_3d
					and r.track.visible
					and (not r.track.scenery.has_method("_process") or r.track.scenery.is_processing())
				),
				"Race, pause and results must preserve the visible world"
			)
		var warm := {}
		for cycle in range(3):
			for mode in [["track", 0], ["track", 1], ["track", 2], ["track", 3], ["track", 4], ["tour", 0]]:
				# 지연 생성 광고의 무작위 선택 차이를 메모리 누적으로 오인하지 않는다.
				Ads.rng.seed = 1000 + int(mode[1]) + (100 if mode[0] == "tour" else 0)
				r.choose_mode(mode[0], mode[1])
				if mode == ["track", 3]:
					for fall in r.track.scenery.rock_arches.falls:
						r.track.scenery.rock_arches.advance(4, fall.distance - 150, 1)
				if mode == ["track", 4]:
					var hazard: Node3D = r.track.active.rockfall
					hazard.reset_effect(71)
					hazard.plan_lap(1)
					hazard.plan_lap(2)
					for plan in hazard.plans + hazard.scenic_plans:
						plan.elapsed = 0.0
						hazard.start_fall(plan)
					hazard.advance(4, 0, 2)
					check(
						hazard.plans.size() == 3 and hazard.scenic_plans.size() == 30, "최대 세 주회분의 도로·장식 낙석을 실제로 생성해야 한다"
					)
					await settle(tree)
				r.restart()
				r.open_menu()
				await settle(tree)
			var row := sample()
			if cycle == 0:
				warm = row
			check(
				row.nodes == warm.nodes and row.orphans == baseline.orphans,
				"Repeated mode rebuilds and restarts must not accumulate nodes or orphans"
			)
			check(
				row.resources <= warm.resources + 2,
				"After warming, repeated visits must keep scene resource counts bounded"
			)
			rows.append({"session": session, "cycle": cycle, "sample": row})
		r.open_garage()
		for turn in range(2):
			for vehicle in range(r.Catalog.SPECS.size()):
				r.select_vehicle(vehicle)
				await settle(tree)
			r.select_vehicle(0)
			await settle(tree)
			check(sample().nodes == warm.nodes, "Repeated vehicle replacement must free the old model")
		var before_bursts := sample()
		for i in range(80):
			r.impacts.burst(Vector3.ZERO, Vector3.UP, false, 0.8)
		await settle(tree)
		check(sample().nodes == before_bursts.nodes, "Repeated impacts must reuse their bounded particle pool")
		r.queue_free()
		await settle(tree)
		check(
			sample().nodes == baseline.nodes and sample().orphans == baseline.orphans,
			"Freeing the race must release every scene-owned node"
		)
		check(
			Pool.owners == 0 and Pool.quads.is_empty() and Pool.box_mesh == null,
			"전체 코스·낙석·붕괴·차량 교체 후에도 공유 메시 참조를 남기면 안 된다"
		)
		check(
			tree.root.disable_3d == viewport_was_disabled,
			"Leaving the race must restore the previous viewport render state"
		)
	Ads.rng.seed = saved_ad_seed
	Ads.rng.state = saved_ad_state
	FileAccess.open(Report.path("resource-lifecycle-metrics.json"), FileAccess.WRITE).store_string(
		JSON.stringify({"baseline": baseline, "cycles": rows, "failures": failures}, "\t")
	)
	print("모든 코스·붕괴·최대 낙석 재생성 / 차량 교체 / 파티클 풀 / 메뉴 렌더링 / 씬 해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
