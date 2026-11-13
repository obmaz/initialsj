extends SceneTree
# GLB 형상은 공유하고 배치·스폿 연결점·노면 조도 표만 코스별 씬에 저장한다.
const Section = preload("res://scripts/track/road_section.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const SPACING := [210.0, 48.0, 90.0, 125.0, 0.0]
const LEGACY := [
	"LampPoles",
	"LampHeads",
	"LampLightPools",
	"StadiumLightPoles",
	"StadiumLightBanks",
	"BillboardLampHousings",
	"BillboardLampLenses"
]


func _initialize() -> void:
	call_deferred("run")


func mm_text(id: String, poses: Array[Transform3D]) -> String:
	var buffer := PackedFloat32Array()
	for pose in poses:
		for row in range(3):
			buffer.append_array([pose.basis.x[row], pose.basis.y[row], pose.basis.z[row], pose.origin[row]])
	return (
		'[sub_resource type="MultiMesh" id="%s"]\ntransform_format = 1\ninstance_count = %d\nbuffer = %s\n'
		% [id, poses.size(), var_to_str(buffer)]
	)


func fixture_node(name: String, mesh_ref: String) -> String:
	return (
		(
			'[node name="%s" type="MultiMeshInstance3D" parent="."]\n'
			+ "cast_shadow = 0\n"
			+ 'material_override = SubResource("FixtureMaterial")\n'
			+ 'multimesh = SubResource("%s")\n'
			+ 'metadata/mesh_ref = "%s"\n'
		)
		% [name, name, mesh_ref]
	)


func light_pose(position: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at((target - position).normalized(), Vector3.UP), position)


func run() -> void:
	for course in range(5):
		var road := Section.new()
		road.closed_loop = true
		road.course_id = course
		Assets.profile(road)
		root.add_child(road)
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		var lamps: Array[Transform3D] = []
		var floods: Array[Transform3D] = []
		var street_anchors: Array[Transform3D] = []
		var ad_anchors: Array[Transform3D] = []
		var offsets := PackedFloat32Array([0])
		var colors := PackedColorArray([Color(0, .5, 0, 1)])
		var spacing: float = SPACING[course]
		if spacing > 0:
			var index := 0
			var d := 100.0
			while d < road.length - 35:
				if road.in_tunnel(d) or (course == 2 and d > 1250 and d < 1790):
					d += spacing
					index += 1
					continue
				var side := 1.0 if index % 2 == 0 else -1.0
				var lane: float = side * (road.half_width(d) + road.rail_setback(d, side) + 1.6)
				var scale := Vector3(1.5, 2, 1.5) if course == 1 else Vector3.ONE
				var pose := Transform3D(
					Basis(Vector3.UP, road.heading(d) + (PI if side < 0 else 0)).scaled_local(scale),
					road.scenery.terrain_point(d, lane) + Vector3.UP * .03
				)
				lamps.append(pose)
				street_anchors.append(light_pose(pose * Vector3(-2.6, 8.42, 0), road.point(d + 10, side * 2)))
				offsets.append_array(
					[maxf(0, (d - 31) / road.length), d / road.length, minf(1, (d + 31) / road.length)]
				)
				colors.append_array(
					[Color(0, .5 + .5 * side, 0, 1), Color(1, .5 + .5 * side, 0, 1), Color(0, .5 + .5 * side, 0, 1)]
				)
				d += spacing
				index += 1
		offsets.append(1)
		colors.append(Color(0, .5, 0, 1))
		var gradient := Gradient.new()
		gradient.offsets = offsets
		gradient.colors = colors
		var pools := GradientTexture1D.new()
		pools.width = 2048
		pools.gradient = gradient
		var folder := Assets.folder(road)
		ResourceSaver.save(pools, folder + "street_pools.tres")
		for node in Assets.nodes(road):
			if not node is GeometryInstance3D or not node.material_override is ShaderMaterial:
				continue
			var material: ShaderMaterial = node.material_override
			if (
				material.shader.resource_path.get_file() == "billboard_ad.gdshader"
				or material.shader.resource_path.get_file() == "speedway_wall_ad.gdshader"
			):
				if not node is MeshInstance3D:
					continue
				var bounds: AABB = node.mesh.get_aabb()
				var scale := clampf(bounds.size.y / 5.0, .28, 1.0)
				for sign_x in [-1, 1]:
					var local := bounds.get_center() + Vector3(sign_x * bounds.size.x * .32, bounds.size.y * .5, 0)
					var pose: Transform3D = (
						node.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), local)
					)
					floods.append(pose)
				ad_anchors.append(
					light_pose(
						node.global_transform * (bounds.get_center() + Vector3(0, bounds.size.y * .5 + .1, 1.2)),
						node.global_transform * bounds.get_center()
					)
				)
			elif (
				material.shader.resource_path.get_file() == "prop_advertisement.gdshader"
				and node is MultiMeshInstance3D
			):
				for index in range(node.multimesh.instance_count):
					var pose: Transform3D = node.global_transform * node.multimesh.get_instance_transform(index)
					ad_anchors.append(light_pose(pose * Vector3(0, 15.5, 1.5), pose * Vector3(0, 11.5, .95)))
		var text := (
			"[gd_scene format=3]\n"
			+ '[ext_resource type="Script" path="res://scripts/environment/course_lighting.gd" '
			+ 'id="controller"]\n'
			+ '[ext_resource type="Shader" path="res://shaders/fixture_lamp.gdshader" id="shader"]\n'
		)
		text += '[ext_resource type="Texture2D" path="%sstreet_pools.tres" id="pools"]\n' % folder
		text += '[sub_resource type="ShaderMaterial" id="FixtureMaterial"]\nshader = ExtResource("shader")\n'
		text += mm_text("RoadLamps", lamps) + mm_text("AdFloodlights", floods)
		text += (
			(
				'[node name="CourseLighting" type="Node3D"]\n'
				+ 'script = ExtResource("controller")\n'
				+ "street_spacing = %s\n"
				+ 'street_pools = ExtResource("pools")\n'
				+ "street_lights = %s\n"
				+ "billboard_lights = %s\n"
			)
			% [str(spacing), var_to_str(street_anchors), var_to_str(ad_anchors)]
		)
		text += fixture_node("RoadLamps", "res://models/props/road_lamp/model.glb#Model/Visual")
		text += fixture_node("AdFloodlights", "res://models/props/billboard_floodlight/model.glb#Model/Visual")
		FileAccess.open(folder + "night_lighting.tscn", FileAccess.WRITE).store_string(text)
		var path := folder + "model.tscn"
		var original := FileAccess.get_file_as_string(path)
		if not original.contains('id="course_lighting"'):
			var first_sub := original.find("[sub_resource")
			original = original.insert(
				first_sub,
				'[ext_resource type="PackedScene" path="%snight_lighting.tscn" id="course_lighting"]\n\n' % folder
			)
			original += '\n[node name="CourseLighting" parent="." instance=ExtResource("course_lighting")]\n'
		for name in LEGACY:
			var pattern := RegEx.create_from_string(
				'(?m)(^\\[node name="' + name + '"[^\\n]+\\]\\n)(?!visible = false)'
			)
			original = pattern.sub(original, "$1visible = false\n", true)
		FileAccess.open(path, FileAccess.WRITE).store_string(original)
		var profile: Resource = load(folder + "profile.tres")
		var paths: Array[String] = profile.get_meta("dependencies")
		for resource_path in [
			folder + "night_lighting.tscn",
			folder + "street_pools.tres",
			"res://models/props/road_lamp/model.glb",
			"res://models/props/billboard_floodlight/model.glb"
		]:
			if not paths.has(resource_path):
				paths.append(resource_path)
		profile.set_meta("dependencies", paths)
		ResourceSaver.save(profile, folder + "profile.tres")
		print(
			"TRACK_LIGHTS ",
			course + 1,
			" road=",
			lamps.size(),
			" ad_fixtures=",
			floods.size(),
			" ad_sources=",
			ad_anchors.size()
		)
		road.free()
		await process_frame
	quit()
