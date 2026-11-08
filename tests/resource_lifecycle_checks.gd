extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func settle(tree: SceneTree) -> void:
	for frame in range(4): await tree.process_frame
func sample() -> Dictionary:
	return {"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))}
func run(tree: SceneTree) -> int:
	await settle(tree)
	var baseline := sample()
	var viewport_was_disabled: bool = tree.root.disable_3d
	var rows := []
	for session in range(2):
		var r = load("res://scenes/race.tscn").instantiate()
		tree.root.add_child(r)
		r.set_physics_process(false)
		r.save_records = false
		r.sound_enabled = false
		for value in ["menu","courses","ready","settings"]:
			r.state = value
			check(tree.root.disable_3d and not r.track.visible and (not r.track.scenery.has_method("_process") or not r.track.scenery.is_processing()),"Opaque menu screens must stop the main 3D render and scenery processing")
		r.warming_world = true
		check(not tree.root.disable_3d and r.track.visible,"Covered prewarming must still render the actual world")
		r.warming_world = false
		for value in ["racing","countdown","paused","finished"]:
			r.state = value
			check(not tree.root.disable_3d and r.track.visible and (not r.track.scenery.has_method("_process") or r.track.scenery.is_processing()),"Race, pause and results must preserve the visible world")
		var warm := {}
		for cycle in range(3):
			for mode in [["track",0],["track",1],["tour",0]]:
				r.choose_mode(mode[0],mode[1])
				r.restart()
				r.open_menu()
				await settle(tree)
			var row := sample()
			if cycle == 0: warm = row
			check(row.nodes == warm.nodes and row.orphans == baseline.orphans,"Repeated mode rebuilds and restarts must not accumulate nodes or orphans")
			check(row.resources <= warm.resources+2,"After warming, repeated visits must keep scene resource counts bounded")
			rows.append({"session":session,"cycle":cycle,"sample":row})
		r.open_garage()
		for turn in range(2):
			for vehicle in range(r.Catalog.SPECS.size()):
				r.select_vehicle(vehicle)
				await settle(tree)
			r.select_vehicle(0)
			await settle(tree)
			check(sample().nodes == warm.nodes,"Repeated vehicle replacement must free the old model")
		var before_bursts := sample()
		for i in range(80): r.impacts.burst(Vector3.ZERO,Vector3.UP,false,0.8)
		await settle(tree)
		check(sample().nodes == before_bursts.nodes,"Repeated impacts must reuse their bounded particle pool")
		r.queue_free()
		await settle(tree)
		check(sample().nodes == baseline.nodes and sample().orphans == baseline.orphans,"Freeing the race must release every scene-owned node")
		check(tree.root.disable_3d == viewport_was_disabled,"Leaving the race must restore the previous viewport render state")
	FileAccess.open(Report.path("resource-lifecycle-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"baseline":baseline,"cycles":rows,"failures":failures},"\t"))
	print("Scene rebuild / vehicle replacement / pooled impacts / menu rendering / teardown: ","PASS" if failures == 0 else "FAIL")
	return failures
