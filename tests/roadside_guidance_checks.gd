extends RefCounted
const Guidance = preload("res://scripts/environment/roadside_guidance.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func camera_trace(station: Node3D) -> void:
	var d: float = station.capture_distance
	station.reset()
	station.advance(.1, d - 3, 50, 0, true)
	station.advance(.1, d + 3, 60, 0, true)
	check(station.pending_speed == 198 and station.displayed_speed == -1, "측정선 통과 시 보간한 실제 속도만 저장하고 전광판은 지연 표시한다")
	check(station.flash.visible and station.capture_count == 1, "촬영 플래시는 한 번만 점등한다")
	station.advance(1, d + 50, 40, 0, true)
	check(station.displayed_speed == 198 and station.number.text == "198", "후속 전광판은 현재 속도가 아닌 측정 당시198km/h를 표시한다")
	station.advance(.1, d - 2, 60, 0, true)
	station.advance(.1, d + 2, 60, 0, true)
	check(station.capture_count == 1, "동일 주회 역주행·재통과로 기록을 중복 갱신하지 않는다")
	station.advance(.1, d - 3, 60, 0, true, 1)
	station.advance(.1, d + 3, 60, 0, true, 1)
	check(station.capture_count == 2 and station.pending_speed == 216, "다음 주회는 다시 촬영한다")
	for kind in range(4):
		station.reset()
		station.advance(.1, d - (80 if kind == 0 else 3), 60, 0, true)
		station.advance(.1, d + 3, 60, 100 if kind == 1 else 0, kind not in [2, 3])
		station.advance(1, d + 10, 60, 0, true)
		check(station.capture_count == 0 and station.displayed_speed == -1, "텔레포트·도로 밖·공중·보호 통과는 촬영하지 않는다")
	station.reset()
	station.advance(.1, d + 3, 60, 0, true)
	station.advance(.1, d - 3, 60, 0, true)
	check(station.capture_count == 0, "역방향 통과는 촬영하지 않는다")
	station.reset()
	check(station.number.text == "---" and not station.flash.visible, "재시작은 측정값·지연·플래시를 초기화한다")


func inspect_marks(road: Node3D, guide: Node3D) -> void:
	for marker in guide.markings:
		check(is_zero_approx(marker.lane), "노면 화살표는 좌우 중복 없이 도로 중앙 한 줄에 표시한다")
		check(guide.clear_marking(marker.distance, marker.lane), "노면 안내는 부스터·점프·고가도로·트럭과 겹치지 않는다")
		var before: float = marker.corner - marker.distance
		if road.closed_loop:
			before = fposmod(before, road.length)
		check(before >= 59 and before <= 151, "노면 화살표는 급커브60~150m 전에 표시한다")
		check(marker.angle in [45, 60, 75], "실제 코너 회전량에 따라 세 강도를 사용한다")
		var pose: Transform3D = guide.surface_pose(marker.distance, marker.lane, marker.side)
		var bounds: AABB = Props.model("bend_arrow_" + str(marker.angle)).get_aabb()
		var across: Vector3 = (road.point(marker.distance, 1) - road.point(marker.distance, -1)).normalized()
		for i in range(8):
			var point: Vector3 = pose * bounds.get_endpoint(i)
			check(
				absf((point - road.point(marker.distance)).dot(across)) < road.half_width(marker.distance),
				"화살표 전체는 좁은 도로 가장자리 안쪽에 남는다"
			)
		check(absf(pose.basis.y.normalized().dot(Vector3.UP)) > .65, "안내 표식은 경사·뱅킹된 실제 노면에 붙인다")


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for course in range(5):
		race.choose_mode("track", course)
		var road: Node3D = race.track.active
		var guide: Node3D = road.get_node("RoadsideGuidance")
		check(not guide.markings.is_empty(), "모든 서킷의 실제 급커브 전에 노면 안내를 설치한다")
		inspect_marks(road, guide)
		check((guide.station != null) == (course == 1), "서킷 속도 측정은 트랙2에만 설치한다")
		if course == 1:
			check(guide.station.display_distance > guide.station.capture_distance + 150, "전광판은 카메라보다 충분히 뒤에 배치한다")
			check(
				not road.in_tunnel(guide.camera_distance) and not road.on_bridge(guide.camera_distance),
				"카메라는 터널·다리 밖 구간에 배치한다"
			)
			camera_trace(guide.station)
			# 실제 차체를 측정선 앞으로 보내 공통 주행 루프의 연결도 확인한다.
			race.restart(false)
			race.state = "racing"
			for rival in race.rivals:
				rival.active = false
			race.world_race.teleport(0, guide.camera_distance - 18, 0)
			race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * 55
			race.speed = 55
			for frame in range(100):
				race.step(1.0 / 60, 0, false, false, false)
			check(guide.station.capture_count == 1 and guide.station.displayed_speed > 120, "실제 물리 주행이 카메라와 전광판을 갱신한다")
			race.restart(false)
			check(guide.station.capture_count == 0, "경기 재시작이 계측기를 초기화한다")
		if course == 0:
			check(guide.vessel != null and guide.vessel.position.y == 0, "후지 호수 수선에 범선을 배치한다")
			var hull: MeshInstance3D = guide.vessel.get_node("Model/Visual")
			check(
				hull.material_override is StandardMaterial3D and hull.material_override.vertex_color_use_as_albedo,
				"범선 재질은 GLB의 선체·갑판·돛 정점색을 실제로 사용한다"
			)
			var nearest: float = road.curve.get_closest_offset(guide.vessel.position)
			check(guide.vessel.position.distance_to(road.point(nearest)) > 75, "대형 선체가 반대편 도로와도 겹치지 않는다")
		if course == 2:
			check(road.curve_markers.multimesh.mesh == Props.model("digital_chevrons"), "야간 코스에는 LED 표시면을 사용한다")
			race.motion_reduced = true
			Guidance.sync_visuals(race)
			check(guide.digital_material.get_shader_parameter("animate") == false, "동작 감소 옵션은 LED 흐름을 멈춘다")
			race.motion_reduced = false
	for stage in [1, 3]:
		for route in range(stage + 1):
			race.choose_mode("tour")
			race.track.reset(stage, route)
			var guide: Node3D = race.track.active.get_node("RoadsideGuidance")
			check(guide.station != null, "투어2·4번째 줄의 모든 분기에 계측기를 설치한다")
			inspect_marks(race.track.active, guide)
			if stage == 3 and route == 3:
				check(guide.digital_material != null, "네온 투어의 방향 안내도 LED로 표시한다")
			else:
				check(guide.digital_material == null, "주간 표지판은 기존 반사 인쇄면을 유지한다")
	# 새 소품이 비동기 구간의 사전 읽기 목록에 포함되는지 검사한다.
	for preview in race.track.previews:
		for path in Guidance.dependencies(preview):
			check(preview.asset_paths.has(path), "안내 소품도 구간 진입 전에 미리 읽는다")
	race.queue_free()
	await tree.process_frame
	print("속도 스냅샷·지연 표시·주회·복구 제외 / 야간 LED / 급커브 노면 안내 / GLB 범선: ", "PASS" if failures == 0 else "FAIL")
	return failures
