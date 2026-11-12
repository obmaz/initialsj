extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
const Assets = preload("res://scripts/rendering/world_assets.gd")
const Curvature = preload("res://scripts/track/circuit_curvature.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(_tree: SceneTree) -> int:
	for course in range(5):
		var road := Section.new()
		road.closed_loop = true
		road.course_id = course
		Assets.profile(road)
		var table := Curvature.new(road.curve, road.length)
		var maximum_error := 0.0
		for i in range(2400):
			var d := road.length * (i + .37) / 2400
			maximum_error = maxf(maximum_error, absf(table.sample_curvature(d) - road.curvature(d)))
		check(maximum_error < .00005, "트랙%d 곡률 캐시는 원래 수평 곡률을 보존해야 한다: %f" % [course + 1, maximum_error])
		for d in [-25.4, -.01, 0.0, .01, 27.8, road.length - .01]:
			check(
				is_equal_approx(table.sample_curvature(d), table.sample_curvature(d + road.length * 3)),
				"곡률 조회는 음수 거리와 여러 바퀴에서도 같은 값이어야 한다"
			)
		check(
			(
				table.sample_spacing_m <= Curvature.MAX_SAMPLE_SPACING_M
				and table.curvature_samples.size() <= ceili(road.length / Curvature.MAX_SAMPLE_SPACING_M) + 1
			),
			"곡률 캐시는 코스 길이에 비례한 고정 메모리만 사용한다"
		)
		road.free()
	print("닫힌 코스 곡률 오차 / 랩 경계·음수 거리 / 캐시 크기: ", "PASS" if failures == 0 else "FAIL")
	return failures
