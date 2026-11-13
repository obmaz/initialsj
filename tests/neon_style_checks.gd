extends RefCounted
const Style = preload("res://scripts/rendering/neon_style.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	check(Style.REGIONS.size() == 15, "투어 15지역이 명시적인 스타일 색을 소유한다")
	check(Style.CIRCUITS.size() == 5, "트랙 5개가 독립적인 스타일 색을 소유한다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for course in range(5):
		race.choose_mode("track", course)
		for period in ["day", "dusk", "night"]:
			race.track_environment.time_of_day = period
			race.track_environment.activate(race)
			var energy: float = race.rim_light.light_energy
			var sun: float = race.sun_light.light_energy
			check(race.rim_light.light_color == Style.accent("track", course, ""), "실제 트랙 보조광이 스타일을 쓴다")
			check(race.rim_light.light_energy == energy and race.sun_light.light_energy == sun, "주야간 광량을 바꾸지 않는다")
			var material: ShaderMaterial = race.track.active.road_surface.material_override
			var color := Style.accent("track", course, "")
			var expected := Vector3(color.r, color.g, color.b) * .045
			check(material.get_shader_parameter("stylized_rim_tint").is_equal_approx(expected), "실제 노면의 스타일 값이 맞다")
	race.choose_mode("tour")
	race.lighting.update(4)
	check(race.rim_light.light_color == Style.accent("tour", 0, race.track.scenery.theme), "투어에도 공통 스타일 경로를 쓴다")
	var previous: ShaderMaterial = race.track.active.road_surface.material_override
	var previous_tint: Variant = previous.get_shader_parameter("stylized_rim_tint")
	race.track.reset(1, 0)
	race.lighting.update(4)
	check(race.rim_light.light_color == Style.accent("tour", 0, "jungle"), "실제 지역 전환이 새 보조광 색을 적용한다")
	check(race.track.active.road_surface.material_override != previous, "다른 구간의 재질은 분리되어 있다")
	check(previous.get_shader_parameter("stylized_rim_tint") == previous_tint, "구간 교체가 앞 구간 재질을 바꾸지 않는다")
	for road in [race.track.active] + race.track.previews:
		var region: String = race.Library.theme(road.stage, road.route_node)
		var color := Style.accent("tour", 0, region)
		var expected := Vector3(color.r, color.g, color.b) * .045
		for surface in [road.road_surface, road.entry_surface]:
			if surface == null:
				continue
			var material: ShaderMaterial = surface.material_override
			if material.shader == preload("res://shaders/asphalt.gdshader"):
				check(
					material.get_shader_parameter("stylized_rim_tint").is_equal_approx(expected),
					"준비된 분기와 진입 노면도 지역 스타일을 쓴다"
				)
	race.free()
	print("5트랙·15지역 스타일 / 실제 노면 연결 / 주야간 광량 보존: ", "PASS" if failures == 0 else "FAIL")
	return failures
