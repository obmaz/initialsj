extends SceneTree
# 기존 GLB를 공유하여 코스 조립 씬과 의존성만 편집한다. 도로·원본 GLB는 변경하지 않는다.
const Section = preload("res://scripts/track/road_section.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")


func _initialize() -> void:
	call_deferred("run")


func pose(road: Node3D, distance: float, lane: float = 0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, road.heading(distance)), road.point(distance, lane))


func run() -> void:
	for id in DirAccess.get_directories_at("res://models/world"):
		if not id.begins_with("tour_"):
			continue
		var parts := id.split("_")
		var road := Section.new(Vector3(0, 6, 0), -PI / 2, int(parts[1]), int(parts[2]), int(parts[3]) - 1)
		var folder := Assets.folder(road)
		var scene_path := folder + "model.tscn"
		var text := FileAccess.get_file_as_string(scene_path)
		if text.contains('name="TourLandmarks"'):
			road.free()
			continue
		var packed: PackedScene = load(scene_path)
		var authored := packed.instantiate()
		var scenery_path: NodePath = authored.get_meta("scene_state").scenery[&"$node"]
		var parent_path := str(scenery_path)
		authored.free()
		var resources := ""
		var nodes := ""
		var dependencies: Array[String] = []
		if road.stage == 2 and road.route_node == 1:
			var name := "carnival_glass_gallery"
			resources += (
				'[ext_resource type="PackedScene" path="%smodel.tscn" id="gallery"]\n'
				% ("res://models/props/" + name + "/")
			)
			dependencies.append("res://models/props/" + name + "/model.glb")
			for distance in range(856, 1080, 8):
				nodes += (
					'[node name="GlassGallery%d" parent="%s/TourLandmarks" instance=ExtResource("gallery")]\ntransform = %s\n'
					% [distance, parent_path, var_to_str(pose(road, distance + 4))]
				)
		if road.stage == 3 and road.route_node == 1:
			var index := 0
			for landmark in [
				["sungnyemun_gate", 620.0, 0.0],
				["namsan_tower", 1350.0, -260.0],
				["golden_63_tower", 2280.0, 160.0],
				["seoul_sky_tower", 3440.0, 330.0]
			]:
				var name: String = landmark[0]
				resources += (
					'[ext_resource type="PackedScene" path="%smodel.tscn" id="seoul%d"]\n'
					% ["res://models/props/" + name + "/", index]
				)
				dependencies.append("res://models/props/" + name + "/model.glb")
				nodes += (
					'[node name="%s" parent="%s/TourLandmarks" instance=ExtResource("seoul%d")]\ntransform = %s\n'
					% [name, parent_path, index, var_to_str(pose(road, landmark[1], landmark[2]))]
				)
				index += 1
		var blocks: Array[Transform3D] = []
		for feature in road.features:
			if feature.kind != "skyway":
				continue
			for distance in range(
				int(feature.distance - feature.length / 2) + 4, int(feature.distance + feature.length / 2), 8
			):
				var height := preload("res://scripts/track/road_features.gd").skyway_height(feature, distance)
				if height < 1.2:
					continue
				var transform := pose(road, distance, feature.lane)
				transform.basis = transform.basis.scaled_local(Vector3(feature.width - .6, height - 1.0, 8.4))
				blocks.append(transform)
		if not blocks.is_empty():
			dependencies.append("res://models/props/skyway_abutment/model.glb")
			resources += '[ext_resource type="Material" path="res://models/props/skyway_abutment/material.tres" id="abutment_color"]\n'
			resources += (
				'[sub_resource type="MultiMesh" id="SkywayAbutments"]\ntransform_format = 1\ninstance_count = %d\n'
				% blocks.size()
			)
			var buffer := PackedFloat32Array()
			for transform in blocks:
				for row in range(3):
					buffer.append_array(
						[transform.basis.x[row], transform.basis.y[row], transform.basis.z[row], transform.origin[row]]
					)
			resources += "buffer = %s\n" % var_to_str(buffer)
			nodes += (
				'[node name="SkywayAbutments" type="MultiMeshInstance3D" parent="%s/TourLandmarks"]\nmaterial_override = ExtResource("abutment_color")\nmultimesh = SubResource("SkywayAbutments")\nmetadata/mesh_ref = "res://models/props/skyway_abutment/model.glb#Model/Visual"\nmetadata/world_barrier = true\nmetadata/collision_transforms = %s\n'
				% [parent_path, var_to_str(blocks)]
			)
		if not nodes.is_empty():
			# ext_resource는 sub_resource보다 먼저 선언한다.
			text = text.insert(text.find("[sub_resource"), resources)
			text += '\n[node name="TourLandmarks" type="Node3D" parent="%s"]\n' % parent_path + nodes
			FileAccess.open(scene_path, FileAccess.WRITE).store_string(text)
			var profile: Resource = load(folder + "profile.tres")
			var paths: Array[String] = profile.get_meta("dependencies")
			for path in dependencies:
				if not paths.has(path):
					paths.append(path)
			profile.set_meta("dependencies", paths)
			ResourceSaver.save(profile, folder + "profile.tres")
			print(id, " 랜드마크·유리 회랑·교대 배치")
		road.free()
	quit()
