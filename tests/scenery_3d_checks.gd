extends RefCounted
const Report = preload("res://tests/report.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Library = preload("res://scripts/track/route_library.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var rows := []
	var all_kinds := {}
	for theme in Props.FAMILIES:
		var placements: Array[Dictionary] = []
		for i in range(3):
			placements.append({"position": Vector3(i * 15, 0, 0), "variant": i})
		var models := Props.new()
		models.configure(theme, placements)
		tree.root.add_child(models)
		check(models.world_bounds.size() == 3, "Every regional object must expose a real world-space volume")
		check(models.kinds.size() >= 2, "Every region needs more than one foreground silhouette")
		for kind in models.kinds:
			all_kinds[kind] = true
			var mesh := Props.model(kind)
			var bounds := mesh.get_aabb()
			check(
				bounds.size.x > 1 and bounds.size.z > 0.35 and bounds.size.y > 1,
				"Foreground meshes must have depth instead of being flat billboards: " + kind
			)
			var arrays := mesh.surface_get_arrays(0)
			check(
				arrays[Mesh.ARRAY_INDEX].size() / 3 < 3200,
				"Individual models must remain within the mobile triangle budget: " + kind
			)
		for batch in models.batches:
			check(not batch.multimesh.mesh is QuadMesh, "Foreground props must not use camera-facing quads")
			check(batch.multimesh.instance_count <= 12, "Spatial groups must have bounded instance counts")
		rows.append({"theme": theme, "silhouettes": models.kinds.duplicate(), "batch_count": models.batches.size()})
		models.queue_free()
		await tree.process_frame
	check(all_kinds.size() >= 18, "The full tour must have a varied regional mesh library")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for choice in [[0, 0], [1, 1], [2, 2], [3, 1], [4, 2], [4, 3]]:
		race.track.reset(choice[0], choice[1])
		var section: Node3D = race.track.active
		var foreground: Node3D = section.scenery.roadside_art
		check(
			foreground.positions.size() + section.scenery.get_node("TourNativeVegetation").tree_count > 20,
			"대표 지역은 길가 오브젝트와 입체 식생으로 충분히 채워져야 한다"
		)
		for placement in foreground.models.placements:
			if preload("res://scripts/environment/settlement_layout.gd").inhabited(placement.kind):
				check(
					preload("res://scripts/environment/settlement_layout.gd").allows(
						section, placement.distance, Props.radius(placement.kind) * placement.scale
					),
					"투어 생활 건물은 위험 지형 밖의 마을 구획에만 놓아야 한다"
				)
		for i in range(foreground.positions.size()):
			var p: Vector3 = foreground.positions[i]
			var nearest: float = section.curve.get_closest_offset(p)
			var center: Vector3 = section.point(nearest)
			var clearance: float = (
				Vector2(p.x - center.x, p.z - center.z).length()
				- foreground.widths[i] * 0.5
				- section.half_width(nearest)
			)
			check(
				(
					clearance
					> (
						section.rail_setback(
							nearest, signf((p - center).dot((section.point(nearest, 1) - center).normalized()))
						)
						+ 1.0
					)
				),
				"A foreground object's entire bounding radius must stay beyond the safety rail"
			)
		if section.scenery.theme in ["city", "seoul"]:
			var styles := {}
			for building in section.scenery.building_manifest:
				styles[building.style] = true
			check(styles.size() >= 10, "도시에는 실척과 외형이 다른 빌딩10종 이상이 실제로 배치되어야 한다")
			check(
				(
					section.scenery.distant_art.has_node("DistantBuildings3D_0")
					and section.scenery.distant_art.sprite_batch == null
				),
				"City skyline must use solid 3D buildings rather than a skyline billboard"
			)
		await tree.process_frame
	race.choose_mode("track", 0)
	check(race.track.scenery.has_node("FujiForest3D"), "Fuji needs a solid 3D forest")
	check(race.track.scenery.landmarks.models.kinds.size() >= 3, "Fuji landmarks need distinct solid structures")
	var forest: Node3D = race.track.scenery.get_node("FujiForest3D")
	var pines: Array = forest.kinds.filter(func(k: String) -> bool: return k.contains("pine"))
	check(
		forest.placements.size() > 70 and forest.kinds.has("sakura") and pines.size() >= 2,
		"Fuji must mix pines and cherry trees"
	)
	var lake_kinds: Array = forest.kinds.filter(func(k: String) -> bool: return k.begins_with("lake_"))
	check(
		(
			lake_kinds.size() >= 8
			and forest.kinds.any(func(k: String) -> bool: return k.begins_with("lake_willow"))
			and forest.kinds.any(func(k: String) -> bool: return k.begins_with("lake_rock"))
			and forest.kinds.any(func(k: String) -> bool: return k.begins_with("lake_bush"))
		),
		"Fuji needs the CC0 pines, willows, bushes and rocks along the road"
	)
	check(
		(
			FileAccess.file_exists("res://assets/environment/props/QUATERNIUS-LICENSE.txt")
			and FileAccess.get_file_as_string("res://assets/environment/props/QUATERNIUS-LICENSE.txt").contains("CC0")
		),
		"Third-party prop models must keep their CC0 licence file"
	)
	var densest := 0
	for batch in forest.batches:
		densest = maxi(densest, batch.multimesh.instance_count)
	check(densest <= 12 and forest.placements.size() < 520, "The Fuji prop count must stay bounded for phones")
	for kind in Props.RURAL_KINDS:
		var arrays: Array = Props.model(kind).surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_INDEX].size() / 3 < 3200, "시골 건물도 개체별 메시 예산을 유지해야 한다")
	var fuji_count: int = forest.placements.size()
	race.choose_mode("track", 3)
	var boulevard: Node3D = race.track.scenery.get_node("RivieraBoulevard")
	var rural_types := {}
	var rural_count := 0
	var settlements := {}
	for placement in boulevard.placements:
		if placement.kind in Props.RURAL_KINDS:
			rural_types[placement.kind] = true
			rural_count += 1
			settlements[0 if placement.distance < 950 else (1 if placement.distance < 2200 else 2)] = true
			check(
				preload("res://scripts/environment/settlement_layout.gd").allows(
					race.track.active, placement.distance, Props.radius(placement.kind) * placement.scale
				),
				"해안 집의 전체 크기가 안전한 마을 구획 안에 있어야 한다"
			)
		var radius: float = Props.radius(placement.kind) * float(placement.scale)
		var p: Vector3 = placement.position
		var nearest: float = race.track.active.curve.get_closest_offset(p)
		var center: Vector3 = race.track.point(nearest)
		check(
			Vector2(p.x - center.x, p.z - center.z).length() - radius >= race.track.half_width(nearest) + 1.5,
			"확대한 해안 매장·야자수의 전체 경계가 차도 밖에 있어야 한다"
		)
	check(settlements.size() == 3, "해안은 빈 구간으로 나뉜 세 마을을 가져야 한다")
	check(
		rural_types.size() == 10 and rural_count >= 30 and rural_count < 100, "해안에는 연속 주택가 대신10종의 시골 건물이 여러 마을로 모여야 한다"
	)
	FileAccess.open(Report.path("scenery-3d-metrics.json"), FileAccess.WRITE).store_string(
		(
			JSON.stringify(
				{
					"regions": rows,
					"unique_model_kinds": all_kinds.size(),
					"fuji_tree_count": fuji_count,
					"failures": failures
				},
				"\t"
			)
			+ "\n"
		)
	)
	race.queue_free()
	await tree.process_frame
	print("Regional 3D geometry / silhouettes / clearance / mobile budgets: ", "PASS" if failures == 0 else "FAIL")
	return failures
