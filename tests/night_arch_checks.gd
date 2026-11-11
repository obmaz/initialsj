extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",2)
	for vehicle in range(4):
		race.open_garage()
		race.select_vehicle(vehicle)
		race.restart()
		race._physics_process(1.0/60)
		check(race.player.headlight.visible and race.player.headlight.spot_range >= 90,"야간에는 모든 차량의 전조등이 전방 노면을 비춰야 한다")
		check(race.player.headlamp_lenses.size() == 2,"모든 차종의 좌우 전조등 렌즈가 살아 있어야 한다")
		for lens in race.player.headlamp_lenses: check(is_instance_valid(lens) and lens.visible,"차체 메시 병합 뒤에도 전조등을 켤 수 있어야 한다")
		for rival in race.rivals:
			if not rival.active: continue
			check(not rival.car.headlight.visible,"상대 차량은 렌즈만 켜서 동적 조명 수를 제한해야 한다")
			for lens in rival.car.headlamp_lenses: check(lens.visible,"야간 상대 차량의 전조등도 켜져야 한다")
	race.choose_mode("track",3)
	race.restart()
	race._physics_process(1.0/60)
	check(not race.player.headlight.visible,"낮의 터널 밖에서는 전조등을 꺼야 한다")
	var scenery: Node3D = race.track.scenery
	var arches: Node3D = scenery.rock_arches
	check(arches.manifest.size() == 2,"해안 협곡 위를 가로지르는 암석 아치 두 곳이 있어야 한다")
	for arch in arches.manifest:
		var road: Node3D = race.track.active
		var center: Vector3 = road.point(arch.distance)
		var right: Vector3 = (road.point(arch.distance,1)-center).normalized()
		var opening: float = road.half_width(arch.distance)+road.rail_setback(arch.distance,1)
		var overhead := 0
		var vertices: PackedVector3Array = arch.mesh.mesh.get_faces()
		for piece in arch.crown:
			for vertex in piece.get_child(0).mesh.get_faces(): vertices.append(piece.transform*vertex)
		for vertex in vertices:
			if absf((vertex-center).dot(right)) <= opening:
				overhead += 1
				check(vertex.y-center.y > 12,"아치 안쪽은 모든 차선과 점프 여유 높이를 비워야 한다")
		check(overhead > 30 and arch.depth >= 12,"암석 아치는 차도 위로 실제 연결된 두꺼운 메시여야 한다")
	var riviera_ads: int = scenery.landmarks.billboard_manifest.size()
	race.choose_mode("track",4)
	var ads: Node3D = race.track.scenery.landmarks
	check(ads.billboard_manifest.size() > riviera_ads*3 and ads.ad_spacing == 60,"협곡 광고 구역은 트랙4보다 세 배 이상 많은 간판을 촘촘히 배치해야 한다")
	var Library = preload("res://scripts/environment/advertisement_library.gd")
	for index in range(Library.count()):
		var mat: Material = ads.advertisement_material(index)
		var info: Dictionary = Library.selection(index)
		check(mat is ShaderMaterial and mat.get_shader_parameter("ad_atlas") == info.atlas,"광고판은 해당 광고의 실제 생성형 원본을 사용해야 한다")
		check(mat.get_shader_parameter("ad_tile") == info.tile and mat.get_shader_parameter("ad_grid") == info.grid,"각 광고판에는 광고 한 장의 영역만 적용해야 한다")
	race.queue_free()
	await tree.process_frame
	print("야간 전조등 / 암석 아치 여유 높이 / 생성형 광고 구역: ","PASS" if failures == 0 else "FAIL")
	return failures
