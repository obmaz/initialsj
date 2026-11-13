extends SceneTree
# 수관·줄기는 같은 GLB를 공유하고90m 구간별 MultiMesh로 나눠 과도한 원거리 렌더를 막는다.
const Section = preload("res://scripts/track/road_section.gd")
const Source = preload("res://models/shared/scene_source.gd")
const TREE_PACK := "res://models/props/cherry_blossom_tree/"
const Dependency = preload("res://tools/author_circuit_checkpoints.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var source := Source.instantiate_static(TREE_PACK + "model.tscn")
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
		var folder: String = "res://models/world/" + str(id) + "/"
		var text := "[gd_scene format=3]\n"
		for piece in pieces:
			text += (
				'[ext_resource type="Material" path="%s%s.tres" id="%s"]\n'
				% [TREE_PACK, str(piece.name).to_lower(), piece.name]
			)
		for group in groups:
			for piece in pieces:
				var buffer := PackedFloat32Array()
				for pose in groups[group]:
					var transform: Transform3D = pose * piece.global_transform
					for row in range(3):
						buffer.append_array(
							[
								transform.basis.x[row],
								transform.basis.y[row],
								transform.basis.z[row],
								transform.origin[row]
							]
						)
				var key := "%s_%d" % [piece.name, group]
				# 메시를 나중에 연결하는 MultiMesh는 ResourceSaver가 버퍼를 생략하므로 명시적으로 저장한다.
				text += (
					'[sub_resource type="MultiMesh" id="%s"]\ntransform_format = 1\ninstance_count = %d\nbuffer = %s\n'
					% [key, groups[group].size(), var_to_str(buffer)]
				)
		text += '[node name="CherryAvenue" type="Node3D"]\nmetadata/tree_count = %d\n' % count
		for group in groups:
			for piece in pieces:
				var key := "%s_%d" % [piece.name, group]
				text += (
					(
						'[node name="%s" type="MultiMeshInstance3D" parent="."]\n'
						+ "cast_shadow = 0\n"
						+ 'material_override = ExtResource("%s")\n'
						+ 'multimesh = SubResource("%s")\n'
						+ "visibility_range_end = 280.0\n"
						+ "visibility_range_end_margin = 25.0\n"
						+ 'metadata/mesh_ref = "%smodel.glb#%s"\n'
					)
					% [key, piece.name, key, TREE_PACK, piece.name]
				)
		FileAccess.open(folder + "seasonal_avenue.tscn", FileAccess.WRITE).store_string(text)
		for path in [
			folder + "seasonal_avenue.tscn",
			TREE_PACK + "model.tscn",
			TREE_PACK + "model.glb",
			TREE_PACK + "bark.tres",
			TREE_PACK + "blossoms.tres",
			TREE_PACK + "blossoms.png",
			TREE_PACK + "cherry_blossom.gdshader"
		]:
			Dependency.add_dependency(folder, path)
		print(id, " 벚꽃: ", count)
		road.free()
		await process_frame
	source.free()
	quit()
