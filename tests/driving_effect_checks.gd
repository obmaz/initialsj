extends RefCounted
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
const Trails = preload("res://scripts/effects/tire_trails.gd")
const Resources = preload("res://scripts/rendering/render_resources.gd")
const Architecture = preload("res://scripts/environment/urban_architecture.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	Resources.acquire_owner()
	for index in range(4):
		var car := Factory.create(index)
		tree.root.add_child(car)
		var effect: Node3D = car.boost_fx
		var nodes := car.find_children("*", "", true, false).size()
		check(
			car.active_aero != null and car.active_aero.mesh.get_surface_count() == 1,
			"모든 선택 차량은 병합에서 보존된 단일 표면 가동 스포일러를 가져야 한다"
		)
		for frame in range(30):
			car.animate(0, false, true, 1.0 / 60, 0)
		var short: float = car.nitro_flames[0].scale.y
		var paused: float = effect.held
		car.animate(0, false, true, 0, 0)
		check(effect.held == paused, "일시정지 중 부스트 시간을 진행시키면 안 된다")
		for frame in range(210):
			car.animate(0, false, true, 1.0 / 60, 0)
		check(effect.heat > .95, "부스트 열량은 유지 시간에 따라 누적된다")
		check(car.active_aero.position.y < car.aero_rest.origin.y - car.aero_drop * .9, "지속 부스트 중 스포일러는 차체 쪽으로 내려가야 한다")
		if index != 1:
			check(car.nitro_flames[0].scale.y > short * 1.2, "연속형은 배기구에 붙은 화염·빔이 길어진다")
		else:
			car.reset_driving_effects()
			car.animate(0, false, true, .1, 0)
			var peak: float = car.nitro_flames[0].scale.y
			for frame in range(60):
				car.animate(0, false, true, 1.0 / 60, 0)
			check(peak > car.nitro_flames[0].scale.y * 2, "단발형은 발동 순간 대형 화염이 터지고 안정된다")
		var flame: MeshInstance3D = car.nitro_flames[0]
		var mouth: Vector3 = flame.position - flame.basis.y * .6
		var rest: Transform3D = effect.rests[0]
		check(mouth.distance_to(rest.origin - rest.basis.y * .6) < .001, "불꽃이 자라도 배기구 접점은 차량에 고정되어야 한다")
		check(effect.find_children("*", "CPUParticles3D", true, false).is_empty(), "니트로는 뒤에 남는 발사체형 입자를 방출하지 않는다")
		car.reduced_motion = true
		car.effects_quality = 2
		car.animate(0, false, true, .1, 0)
		for frame in range(100):
			car.animate(0, false, false, 1.0 / 60, 0)
		check(
			not flame.visible and car.active_aero.position.distance_to(car.aero_rest.origin) < .002,
			"부스트 해제 뒤 불꽃과 공력 부품이 원상 복귀해야 한다"
		)
		check(car.find_children("*", "", true, false).size() == nodes, "반복 부스트가 노드 수를 늘리면 안 된다")
		car.reset_driving_effects()
		for particles in car.smoke:
			check(not particles.emitting, "입자 재시작 API가 다시 켠 방출도 복구 마지막에 확실히 꺼야 한다")
		check(
			effect.heat == 0 and effect.held == 0 and car.active_aero.transform == car.aero_rest,
			"재시작·리스폰은 부스트와 스포일러를 즉시 복원해야 한다"
		)
		car.queue_free()
		await tree.process_frame
	var trails := Trails.new()
	tree.root.add_child(trails)
	var normal := Vector3(0, 1, .25).normalized()
	trails.segment(Vector3.ZERO, Vector3(0, -.5, 2), normal, 4, .9)
	var mark := Trails.mark_transform(Vector3.ZERO, Vector3(0, -.5, 2), normal)
	check(mark.basis.y.normalized().dot(normal) > .999, "타이어 자국은 월드 수평면이 아니라 경사진 노면에 붙어야 한다")
	for i in range(Trails.CAPACITY * 2):
		trails.segment(Vector3(i, 0, 0), Vector3(i + 1, 0, 0), Vector3.UP, 5, 1)
	check(
		trails.instances.instance_count == Trails.CAPACITY and trails.get_child_count() == 1,
		"긴 드리프트도 하나의 고정 순환 풀 안에서만 자국을 갱신해야 한다"
	)
	trails.reset()
	check(
		trails.cursor == 0 and trails.previous.is_empty() and trails.previous_normals.is_empty(),
		"재시작은 이전 구간의 타이어 자국을 남기지 않아야 한다"
	)
	trails.free()
	var mass := Node3D.new()
	tree.root.add_child(mass)
	var poses: Array[Transform3D] = []
	for detail in Architecture.mass_parts(Vector3(32, 60, 24)):
		check(detail.size.x >= .4 and detail.size.z >= .4, "도시 빌딩 모서리·파라펫은 실제 40cm 이상의 부피를 가져야 한다")
		poses.append(Transform3D(Basis.IDENTITY.scaled(detail.size), detail.position))
	Architecture.add_mass(mass, poses)
	check(mass.get_child_count() > 0 and mass.get_child_count() <= 4, "빌딩 장식은 개별 노드 대신 공간별 공유 메시로 묶여야 한다")
	for node in mass.get_children():
		check(node.multimesh.mesh == Resources.unit_box(), "장식 박스는 UV가 있는 공통 단위 메시를 재사용해야 한다")
	mass.free()
	Resources.release_owner()
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 1)
	race.state = "racing"
	var Props = preload("res://scripts/environment/regional_props_3d.gd")
	for kind in ["sandstone", "basalt"]:
		var material: ShaderMaterial = Props.material_for(kind)
		check(
			material.get_shader_parameter("rock_detail") is Texture2D, "길가 바위 소품도 생성형 암석 이미지를 실제 재질에 연결해야 한다: " + kind
		)
	await tree.physics_frame
	race.drifting = true
	for d in [3300.0, 3302.0]:
		race.world_race.teleport(0, d, 1)
		race.world_race.player_body.grounded = true
		race.speed = 45
		race.world_race.place_cars()
		race.tire_trails.update(race)
	check(race.tire_trails.cursor >= 2, "실제 뱅크 도로에서 후륜 광선 접점 두 곳에 자국을 남겨야 한다")
	var cursor: int = race.tire_trails.cursor
	race.world_race.player_body.grounded = false
	race.tire_trails.update(race)
	check(
		race.tire_trails.cursor == cursor and race.tire_trails.previous.is_empty(), "공중에서는 자국을 멈추고 이전 접점과의 연결도 끊어야 한다"
	)
	race.motion_reduced = false
	race.boosting = true
	race.player.boost_fx.heat = 0
	race.world_race.update_camera(2)
	var cold_fov: float = race.camera.fov
	race.player.boost_fx.heat = 1
	race.world_race.update_camera(2)
	check(race.camera.fov > cold_fov + 2, "지속 부스트의 카메라 시야 변화도 유지 시간에 반응해야 한다")
	race.motion_reduced = true
	race.world_race.update_camera(2)
	check(absf(race.camera.fov - 68) < .1, "동작 줄이기는 추가 부스트 시야 변화를 없애야 한다")
	race.restart()
	check(race.player.boost_fx.heat == 0 and race.tire_trails.cursor == 0, "실제 경기 재시작은 배기 열과 타이어 자국을 함께 지워야 한다")
	race.queue_free()
	await tree.process_frame
	print("지속 부스트·배기구 고정 / 가동 스포일러 / 파티클 예산·수명 / 경사 타이어 자국 / 건물 입체 장식: ", "PASS" if failures == 0 else "FAIL")
	return failures
