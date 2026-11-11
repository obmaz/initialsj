extends RefCounted
const Metadata = preload("res://scripts/environment/tour_region_metadata.gd")
const Library = preload("res://scripts/track/route_library.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	for theme in Metadata.REGIONS:
		var region: Dictionary = Metadata.resolve(theme)
		check(
			(
				not region.concept.is_empty()
				and region.difficulty >= 1
				and region.difficulty <= 5
				and region.time_of_day in ["day", "night", "dawn", "dusk"]
			),
			"투어15지역 메타정보 필드"
		)
	var rains: Dictionary = {}
	for seed in [0, 54, 55, 99]:
		for route in range(16):
			var node := 0
			var previous := "clear"
			for stage in range(5):
				var region := Metadata.resolve(Library.theme(stage, node), previous, seed)
				check(not (previous == "rain" and region.weather == "rain"), "모든 분기에서 비 연속 진입 금지")
				if region.weather == "rain":
					rains[region.region] = true
				previous = region.weather
				if stage < 4:
					node += (route >> stage) & 1
	check(rains.has("ruins") and rains.has("canyon") and rains.size() == 2, "드문 오브젝트 지역2곳만 비 후보")
	var weather := preload("res://scripts/environment/tour_weather.gd").new()
	tree.root.add_child(weather)
	weather.set_process(false)
	for kind in ["sand", "snow", "rain", "clear"]:
		weather.configure(kind)
		check(weather.particles.amount <= 360 and not weather.particles.local_coords, "날씨 입자는 고정 예산·월드 좌표")
	weather.queue_free()
	await tree.process_frame
	print("투어15지역 메타정보 / 64개 여행의 비 연결 금지 / 모래·눈·비 입자 예산: ", "PASS" if failures == 0 else "FAIL")
	return failures
