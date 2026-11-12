extends SceneTree
# 수관·줄기는 같은 GLB를 공유하고90m 구간별 MultiMesh로 나눠 과도한 원거리 렌더를 막는다.
const Section = preload("res://scripts/track/road_section.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const Source = preload("res://models/shared/scene_source.gd")
const Pack := "res://models/props/cherry_blossom_tree/"
const Dependency = preload("res://tools/author_circuit_checkpoints.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var source := Source.instantiate_static(Pack + "model.tscn")
	root.add_child(source)
	source.visible = false
	var pieces := Source.collect_meshes(source)
	for id in ["track_0", "tour_3_2_0", "tour_3_2_1", "tour_3_2_2"]:
		var parts: PackedStringArray = str(id).split("_")
		var road: Node3D = (
			Section.new() if parts[0] == "track" else Section.new(Vector3(0, 6, 0), -PI / 2, 3, 2, int(parts[3]) - 1)
		)
		if parts[0] == "track":
			road.closed_loop = true
			road.course_id = 0
		root.add_child(road)
		var groups := {}
		var count := 0
		for distance in range(360, mini(1481, int(road.length) - 100), 18):
			if road.in_tunnel(distance):
				continue
			for side in [-1.0, 1.0]:
				var lane: float = side * (road.half_width(distance) + road.rail_setback(distance, side) + 7)
				var at := float(distance)
				var ground: Vector3 = road.scenery.terrain_point(at, lane)
				if ground.y < road.point(at).y - 5:
					at += 9
					lane = road.half_width(at) + road.rail_setback(at, 1) + 19
					ground = road.scenery.terrain_point(at, lane)
				var pose := Transform3D(
					Basis(Vector3.UP, at * .037).scaled(Vector3.ONE * (.86 + .14 * pow(sin(at * .071), 2))), ground
				)
				var group := int(distance / 90)
				if not groups.has(group):
					groups[group] = []
				groups[group].append(pose)
				count += 1
		var avenue := Node3D.new()
		avenue.name = "CherryAvenue"
		avenue.set_meta("tree_count", count)
		for group in groups:
			for piece in pieces:
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.instance_count = groups[group].size()
				for i in range(multi.instance_count):
					multi.set_instance_transform(i, groups[group][i] * piece.global_transform)
				var node := MultiMeshInstance3D.new()
				node.name = "%s_%d" % [piece.name, group]
				node.multimesh = multi
				node.material_override = piece.material_override
				node.set_meta("mesh_ref", Pack + "model.glb#" + str(piece.name))
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.visibility_range_end = 280
				node.visibility_range_end_margin = 25
				avenue.add_child(node)
				node.owner = avenue
		var packed := PackedScene.new()
		packed.pack(avenue)
		var folder: String = "res://models/world/" + str(id) + "/"
		ResourceSaver.save(packed, folder + "seasonal_avenue.tscn")
		for path in [
			folder + "seasonal_avenue.tscn",
			Pack + "model.tscn",
			Pack + "model.glb",
			Pack + "bark.tres",
			Pack + "blossoms.tres",
			Pack + "blossoms.png",
			Pack + "cherry_blossom.gdshader"
		]:
			Dependency.add_dependency(folder, path)
		print(id, " 벚꽃: ", count)
		avenue.free()
		road.free()
		await process_frame
	source.free()
	quit()
