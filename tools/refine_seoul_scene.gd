extends SceneTree
# 서울의 진입 변형3개에서 교통 구성·원경 배치만 편집한다. 노면·원본 GLB는 보존한다.
const Section = preload("res://scripts/track/road_section.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const LANDMARKS := {
	"sungnyemun_gate": Vector2(620, 0),
	"namsan_tower": Vector2(1350, -260),
	"golden_63_tower": Vector2(2280, 160),
	"seoul_sky_tower": Vector2(3440, 330)
}


func _initialize() -> void:
	call_deferred("run")


func rewrite_features(text: String, distances: Array[float]) -> String:
	var pattern := RegEx.create_from_string('\\{[^{}]*"kind": "truck"[^{}]*\\}')
	var found := pattern.search_all(text)
	found.reverse()
	for match in found:
		var block := match.get_string()
		var feature: Dictionary = str_to_var(block)
		var replace := false
		for distance in distances:
			if absf(feature.distance - distance) < .1:
				replace = true
		if replace:
			block = block.replace('"kind": "truck"', '"kind": "car"')
			block = RegEx.create_from_string('"length": [0-9.]+').sub(block, '"length": 4.5')
			block = RegEx.create_from_string('"width": [0-9.]+').sub(block, '"width": 2.05')
			text = text.substr(0, match.get_start()) + block + text.substr(match.get_end())
	return text


func run() -> void:
	for side in [-1, 0, 1]:
		var road := Section.new(Vector3(0, 6, 0), -PI / 2, 3, 1, side)
		var path := Assets.folder(road) + "model.tscn"
		# 분할된 씬은 배치가 들어 있는 작은 조립 파일을 직접 갱신한다.
		if DirAccess.dir_exists_absolute(Assets.folder(road) + "assembly"):
			for file in DirAccess.get_files_at(Assets.folder(road) + "assembly"):
				if not file.ends_with(".tscn"):
					continue
				var part_path := Assets.folder(road) + "assembly/" + file
				var part_text := FileAccess.get_file_as_string(part_path)
				FileAccess.open(part_path, FileAccess.WRITE).store_string(update_landmarks(part_text, road))
			road.free()
			continue
		var text := FileAccess.get_file_as_string(path)
		var script_id := (
			RegEx.create_from_string('path="res://scripts/vehicles/car.gd" id="([^"]+)"').search(text).get_string(1)
		)
		var scene: Node3D = load(path).instantiate()
		var replacements: Array[float] = []
		var remove_names: Array[String] = []
		var passenger_index := 0
		var additions := ""
		for child in scene.get_children():
			if not child.get_meta("parked_truck", false):
				continue
			var distance := road.curve.get_closest_offset(child.position)
			var below_skyway := false
			for feature in road.features:
				if feature.kind == "skyway" and absf(feature.distance - distance) < feature.length / 2:
					below_skyway = true
			if below_skyway:
				continue
			var closest := INF
			var replacement_distance := distance
			for feature in road.features:
				if feature.kind == "truck" and absf(feature.distance - distance) < closest:
					closest = absf(feature.distance - distance)
					replacement_distance = feature.distance
			replacements.append(replacement_distance)
			remove_names.append(str(child.name))
			additions += (
				'\n[node name="SeoulPassenger%d" type="Node3D" parent="."]\ntransform = %s\nscript = ExtResource("%s")\nmodel = "%s"\npaint = %s\ntraffic = true\nmetadata/parked_car = true\n'
				% [
					passenger_index,
					var_to_str(child.transform),
					script_id,
					["hatch", "wedge", "gt", "hatch"][passenger_index % 4],
					var_to_str(
						[Color("e5dcc9"), Color("647e92"), Color("a24d3d"), Color("c6cbd0")][passenger_index % 4]
					)
				]
			)
			passenger_index += 1
		var node_pattern := RegEx.create_from_string("(?m)^\\[node [^\\n]+\\]")
		var matches := node_pattern.search_all(text)
		var removals: Array[Vector2i] = []
		for i in range(matches.size()):
			var header := matches[i].get_string()
			var name := RegEx.create_from_string('name="([^"]+)"').search(header).get_string(1)
			var parent_match := RegEx.create_from_string('parent="([^"]+)"').search(header)
			var parent := parent_match.get_string(1) if parent_match != null else ""
			for removed in remove_names:
				if name == removed or parent == removed or parent.begins_with(removed + "/"):
					removals.append(
						Vector2i(
							matches[i].get_start(),
							matches[i + 1].get_start() if i + 1 < matches.size() else text.length()
						)
					)
		removals.reverse()
		for span in removals:
			text = text.substr(0, span.x) + text.substr(span.y)
		text = rewrite_features(text, replacements) + additions
		text = update_landmarks(text, road)
		FileAccess.open(path, FileAccess.WRITE).store_string(text)
		var profile_path := Assets.folder(road) + "profile.tres"
		var profile := FileAccess.get_file_as_string(profile_path)
		FileAccess.open(profile_path, FileAccess.WRITE).store_string(rewrite_features(profile, replacements))
		print(path, " 승용차 교체 ", passenger_index)
		scene.free()
		road.free()
	quit()


func update_landmarks(text: String, road: Node3D) -> String:
	for name in LANDMARKS:
		var pattern := RegEx.create_from_string('(?m)(^\\[node name="' + name + '"[^\\n]+\\]\\n)transform = [^\\n]+')
		var location: Vector2 = LANDMARKS[name]
		text = pattern.sub(
			text,
			(
				"$1transform = "
				+ var_to_str(
					Transform3D(Basis(Vector3.UP, road.heading(location.x)), road.point(location.x, location.y))
				)
			)
		)
	return text
