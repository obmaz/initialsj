extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
const Background = preload("res://scripts/environment/tour_goal_background.gd")


class RaceStub:
	extends Node
	var mode := "tour"
	var track: Node
	var atmosphere := Environment.new()


class TrackStub:
	extends Node
	var active: Node3D


var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var pool = preload("res://scripts/rendering/render_resources.gd")
	pool.acquire_owner()
	var road := Section.new()
	road.stage = 2
	road.route_node = 1
	tree.root.add_child(road)
	var park: Node3D
	for node in road.scenery.get_children():
		if node.get_script() == preload("res://scripts/environment/tour_amusement.gd"):
			park = node
	check(
		park != null and park.coaster_samples == 160 and park.get_child_count() >= 10,
		"공원은 고저차 트랙·바이킹·상업 시설이 실제 메시여야 한다"
	)
	var kiosks: Node3D = road.scenery.get_node("AmusementKiosks")
	check(kiosks.placements.size() == 12 and kiosks.kinds == ["amusement_kiosk"], "공원의12개 매점은 전용 외장 모델을 사용해야 한다")
	for batch in kiosks.batches:
		check(
			(
				batch.material_override.get_shader_parameter("building_fronts") is Texture2D
				and batch.material_override.get_shader_parameter("building_sides") is Texture2D
			),
			"공원 매점의 정면·측면 생성형 이미지가 실제 렌더 재질에 연결되어야 한다"
		)
	var before: float = park.swing.rotation.z
	park._process(.5)
	check(not is_equal_approx(before, park.swing.rotation.z), "바이킹 선체가 실제 회전축에서 움직여야 한다")
	var vegetation: Node = road.scenery.get_node("TourNativeVegetation")
	check(vegetation.variant_counts.size() == 7 and vegetation.tree_count > 60, "공원에 복사한 식생7종을 모두 배치해야 한다")
	road.queue_free()
	await tree.process_frame
	var race := RaceStub.new()
	race.track = TrackStub.new()
	race.add_child(race.track)
	race.atmosphere.sky = Sky.new()
	tree.root.add_child(race)
	var background := Background.new()
	background.race = race
	race.add_child(background)
	background.set_process(false)
	for id in range(5):
		road = Section.new()
		road.stage = 4
		road.route_node = id
		tree.root.add_child(road)
		race.track.active = road
		background._process(0)
		var forward: Vector3 = (road.point(road.length - 25) - road.point(road.length - 60)).normalized()
		var material: ShaderMaterial = race.atmosphere.sky.sky_material
		check(
			(
				material.get_shader_parameter("panorama").resource_path == Background.IMAGES[id]
				and is_equal_approx(material.get_shader_parameter("heading"), atan2(forward.x, forward.z))
			),
			"최종5지역의 별도 파노라마와 실제 진입 접선 정렬"
		)
		road.queue_free()
		await tree.process_frame
	race.queue_free()
	await tree.process_frame
	if pool.release_owner():
		preload("res://scripts/environment/regional_props_3d.gd").clear_cache()
		preload("res://scripts/environment/advertisement_library.gd").clear_cache()
	print("투어 식생7종 / 롤러코스터·바이킹 / 최종5지역 진입 방향 파노라마: ", "PASS" if failures == 0 else "FAIL")
	return failures
