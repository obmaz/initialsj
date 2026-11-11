extends RefCounted
const Props = preload("res://scripts/environment/regional_props_3d.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var textures := {}
	for course in range(5):
		race.warming_world = false
		race.choose_mode("track", course)
		check(race.atmosphere.sky == null, "메뉴에서 원경 GPU 자원을 미리 생성하지 않는다")
		race.warming_world = true
		race.sync_world_rendering()
		var sky: Sky = race.atmosphere.sky
		var material: ShaderMaterial = sky.sky_material
		var panorama: Texture2D = material.get_shader_parameter("panorama")
		check(panorama != null, "모든 트랙은 실제 하늘·원경 이미지를 연결한다")
		textures[panorama.resource_path] = true
		if course == 0:
			check(
				material.get_shader_parameter("back_a") != null and material.get_shader_parameter("back_b") != null,
				"후지는 나머지240도를 덮는 두 후면 패널도 유지한다"
			)
		else:
			check(
				panorama.get_width() >= 1700 and panorama.get_width() == panorama.get_height() * 2,
				"새 원경은 전체 구면2:1 비율을 보존한다"
			)
			check(material.shader.resource_path == "res://shaders/track_panorama.gdshader", "원경은 평면 카드 대신 위경도 하늘을 사용한다")
		# 한 바퀴의 위치·방위 변화에도 원경과 광원 방위가 카메라를 따라 회전하지 않는다.
		var light_rotation: Vector3 = race.sun_light.rotation
		var uniforms := material.shader.get_shader_uniform_list()
		var values: Array = []
		for uniform in uniforms:
			values.append(material.get_shader_parameter(uniform.name))
		for sample in range(16):
			var d: float = race.track.length * sample / 16
			race.distance = d
			race.camera.position = race.track.point(d) + Vector3.UP * 3
			race.camera.rotation = Vector3(-.08, race.track.heading(d), 0)
			race.update_atmosphere(.1)
			check(race.atmosphere.sky == sky, "코너·주회에 따라 하늘을 재생성하지 않는다")
			check(race.sun_light.rotation == light_rotation, "광원 방위도 주행 방향을 따라 돌지 않는다")
			for index in range(uniforms.size()):
				check(
					material.get_shader_parameter(uniforms[index].name) == values[index], "하늘의 월드 방위를 카메라와 함께 돌리지 않는다"
				)
		if course == 1:
			var placements: Array = race.track.scenery.get_node("InfieldAdvertisements").placements
			check(placements.size() == 42, "트랙2 광고판은14개의 정확히3배인42개여야 한다")
			var previous := -1.0
			for placement in placements:
				var d: float = placement.distance
				var p: Vector3 = placement.position
				var road: Vector3 = race.track.point(d)
				var clearance: float = (
					Vector2(p.x - road.x, p.z - road.z).length()
					- Props.radius("billboard")
					- race.track.half_width(d)
					- race.track.active.rail_setback(d, -1)
				)
				check(clearance >= 1.99 and (placement.pit_roof or clearance < 2.1), "패널 전체가 레일 밖에 놓여 차도를 가리지 않는다")
				if placement.pit_roof:
					check(
						placement.lane == -45 and p.y >= race.track.scenery.terrain_point(d, placement.lane).y + 7,
						"피트 쪽 광고는 차고 지붕 위에 올려 진출입 통로를 비운다"
					)
				if previous >= 0:
					check(
						(
							d - previous >= 49
							and (d - previous < 51 or d - previous > 600)
							and p.distance_to(race.track.scenery.terrain_point(previous, placement.lane)) > 20
						),
						"광고 간격을3분의1로 줄이되 서로 겹치지 않는다"
					)
				var front: Vector3 = Basis(Vector3.UP, placement.yaw).z
				var toward: Vector3 = (race.track.point(d - 40) - p).normalized()
				if d <= 1050:
					var audience: Vector3 = (race.track.point(d, 35) - p).normalized()
					check(front.dot(audience) > .7, "피트 쪽 광고 정면은 맞은편 관중석을 향한다")
				else:
					check(front.dot(toward) > .96, "인필드 광고는 접근하는 운전자에게 읽히는 각도를 향한다")
				check(absf(placement.lane) <= 45, "광고는 관중석 맞은편 피트 지붕이나 가까운 인필드에 둔다")
				previous = d
	check(textures.size() == 5, "다섯 트랙은 각자의 원경을 사용한다")
	race.queue_free()
	await tree.process_frame
	print("트랙 광고42개 / 레일·피트 여유 / 접근 각도 / 전 트랙360도 고정 원경: ", "PASS" if failures == 0 else "FAIL")
	return failures
