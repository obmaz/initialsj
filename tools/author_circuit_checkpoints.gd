extends SceneTree
# 주행과 분리된 체크포인트 시각 씬을 GLB 공용 상자·번역 가능한 표지로 조립한다.
const Section = preload("res://scripts/track/road_section.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")


func _initialize() -> void:
	call_deferred("run")


static func add_dependency(folder: String, path: String) -> void:
	var profile := folder + "profile.tres"
	var lines := FileAccess.get_file_as_string(profile).split("\n")
	for i in range(lines.size()):
		if not lines[i].begins_with("metadata/dependencies = Array[String]("):
			continue
		var values: Array = JSON.parse_string(
			lines[i].trim_prefix("metadata/dependencies = Array[String](").trim_suffix(")")
		)
		if not values.has(path):
			values.append(path)
			lines[i] = "metadata/dependencies = Array[String](%s)" % JSON.stringify(values)
			FileAccess.open(profile, FileAccess.WRITE).store_string("\n".join(lines))
		return


func part(parent: Node3D, pose: Transform3D, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Frame%d" % parent.get_child_count()
	mesh.set_meta("mesh_ref", "res://models/shared/render_primitives/model.glb#unit_box")
	mesh.transform = pose.scaled_local(size)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.owner = parent


func run() -> void:
	for course in range(5):
		var road := Section.new()
		road.closed_loop = true
		road.course_id = course
		Assets.profile(road)
		root.add_child(road)
		var gate := Node3D.new()
		gate.name = "CircuitCheckpoint"
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("17b8c7")
		material.emission_enabled = true
		material.emission = Color("076e79")
		for distance in [0.0, road.length * .5]:
			var width: float = road.half_width(distance) + 1.6
			var base := Transform3D(Basis(Vector3.UP, road.heading(distance)), road.point(distance))
			for side in [-1.0, 1.0]:
				part(
					gate,
					Transform3D(base.basis, road.point(distance, width * side) + Vector3.UP * 3),
					Vector3(.45, 6, .45),
					material
				)
			part(gate, Transform3D(base.basis, base.origin + Vector3.UP * 6), Vector3(width * 2, .5, .6), material)
			var label := Label3D.new()
			label.name = "CheckpointLabel%d" % gate.get_child_count()
			label.text = "CHECKPOINT"
			label.position = base.origin + Vector3.UP * 6.1
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
			label.font_size = 180
			label.pixel_size = .006
			label.outline_size = 24
			gate.add_child(label)
			label.owner = gate
		var packed := PackedScene.new()
		packed.pack(gate)
		var path := Assets.folder(road) + "checkpoint.tscn"
		ResourceSaver.save(packed, path)
		add_dependency(Assets.folder(road), path)
		gate.free()
		road.free()
		await process_frame
	quit()
