extends RefCounted
const Pool = preload("res://scripts/rendering/render_resources.gd")
const Ads = preload("res://scripts/environment/advertisement_library.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func settle(tree: SceneTree) -> void:
	for frame in range(4):
		await tree.process_frame


func run(tree: SceneTree) -> int:
	check(Pool.owners == 0, "독립 검사 시작 시 이전 게임 씬의 소유권이 남으면 안 된다")
	Ads.clear_cache()
	Props.clear_cache()
	var warmup := preload("res://scripts/rendering/material_warmup.gd").new()
	var mesh_a := Pool.unit_box()
	var mesh_b := mesh_a.duplicate() as ArrayMesh
	var common_material := StandardMaterial3D.new()
	warmup.add_mesh(mesh_a, common_material, [], false, false, false)
	warmup.add_mesh(mesh_b, common_material, [], false, false, false)
	warmup.add_mesh(mesh_a, common_material, [], false, false, false)
	check(warmup.jobs.size() == 2, "같은 재질의 다른 메시도 GPU 미리 준비에 포함하며 같은 메시 중복은 제거한다")
	warmup.free()
	var first := Ads.material(0)
	check(
		(
			Ads.atlases.size() == 1
			and Ads.materials.filter(func(m): return m != null).size() == 1
			and Ads.prop_prints.is_empty()
		),
		"광고 한 장을 요청할 때 다른 아틀라스·인쇄 재질을 미리 할당하면 안 된다"
	)
	check(
		(
			Ads.material(48) == first
			and Ads.prop_material(0).get_shader_parameter("ad_atlas") == first.get_shader_parameter("ad_atlas")
		),
		"같은 광고는 재질과 아틀라스를 공유해야 한다"
	)
	for index in range(-48, 144):
		Ads.material(index)
		Ads.prop_material(index)
	check(
		Ads.atlases.size() == 8 and Ads.materials.size() == 48 and Ads.prop_prints.size() == 48,
		"광고 캐시는 반복 선택과 음수 번호에도 고정된 목록 크기 안에 머물러야 한다"
	)
	var plain := Props.material_for("lake_pine_1")
	check(
		(
			plain.get_shader_parameter("building_fronts") == null
			and plain.get_shader_parameter("rural_fronts") == null
			and plain.get_shader_parameter("container_skins") == null
		),
		"외벽을 쓰지 않는 나무 재질은 대형 외벽 이미지를 붙들면 안 된다"
	)
	check(
		Props.material_for("convenience_store").get_shader_parameter("building_fronts") is Texture2D,
		"건물에 필요한 전용 정면 이미지는 유지해야 한다"
	)
	check(Props.material_for("containers").get_shader_parameter("skins") is Texture2D, "컨테이너의 전용 인쇄 이미지는 유지해야 한다")
	var viewport_was_disabled: bool = tree.root.disable_3d
	var a = load("res://scenes/race.tscn").instantiate()
	var b = load("res://scenes/race.tscn").instantiate()
	for race in [a, b]:
		tree.root.add_child(race)
		race.set_physics_process(false)
		race.save_records = false
		race.sound_enabled = false
		check(race.atmosphere.sky == null, "메뉴에서는 아직 쓰지 않을 하늘의 GPU 리소스를 생성하면 안 된다")
	check(Pool.owners == 2, "동시에 살아 있는 씬은 각자 렌더 리소스의 소유권을 가져야 한다")
	# 메뉴 배경은 메뉴에서만 GPU에 있고 주행 중에는 참조를 놓아야 한다.
	var home: WeakRef = weakref(a.hud.menus.art(a.hud.menus.HOME_BG))
	check(
		home.get_ref() is Texture2D and a.hud.menus.art(a.hud.menus.COURSE_PREVIEWS[0]) is Texture2D,
		"메뉴 화면은 배경과 코스 미리보기를 읽을 수 있어야 한다"
	)
	b.hud.menus.menu_art.clear()
	a.state = "racing"
	a.hud.menus.sync_menu_art()
	check(a.hud.menus.menu_art.is_empty() and home.get_ref() == null, "주행 중에는 메뉴 배경 텍스처를 메모리에 남기면 안 된다")
	a.state = "menu"
	a.hud.menus.sync_menu_art()
	check(
		a.hud.menus.art(a.hud.menus.HOME_BG) is Texture2D and a.hud.menus.art(a.hud.menus.GARAGE_BG) is Texture2D,
		"메뉴로 돌아오면 배경을 다시 읽어야 한다"
	)
	var cars: Array[Node3D] = []
	for paint in [Color.RED, Color.BLUE]:
		var car := preload("res://scripts/vehicles/car.gd").new()
		car.traffic = true
		car.model = "gt"
		car.paint = paint
		a.add_child(car)
		cars.append(car)
	check(
		(
			cars[0].body.get_node("BodyShell").mesh == cars[1].body.get_node("BodyShell").mesh
			and cars[0].wheels[0].mesh == cars[1].wheels[0].mesh
		),
		"교통 차량은 생성 메시와 바퀴를 공유해야 한다"
	)
	check(cars[0].brake_lights[0] != cars[1].brake_lights[0], "교통 차량의 브레이크 발광 상태는 인스턴스마다 독립적으로 보존한다")
	for car in cars:
		check(car.headlight != null and car.headlamp_lenses.size() == 2, "캐시에서 만든 차량도 전조등·렌즈 참조를 복원해야 한다")
		check(
			car.body.get_node("BodyShell").material_override.get_shader_parameter("traffic_paint").is_equal_approx(
				Vector4(car.paint.r, car.paint.g, car.paint.b, car.paint.a)
			),
			"공유 메시를 쓰더라도 각 교통 차량의 도장색을 보존한다"
		)
		car.queue_free()
	var quad := Pool.quad(Vector2(20, 8.75))
	check(Pool.quad(Vector2(20, 8.75)) == quad and Pool.quad(Vector2.ONE) != quad, "같은 크기의 쿼드만 공유하고 다른 크기는 구분해야 한다")
	var box := Pool.unit_box()
	var data := box.surface_get_arrays(0)
	var face_bounds := {}
	for i in range(data[Mesh.ARRAY_VERTEX].size()):
		var normal: Vector3 = data[Mesh.ARRAY_NORMAL][i]
		var uv: Vector2 = data[Mesh.ARRAY_TEX_UV][i]
		check(uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1, "공유 상자의 UV는 각 면 안에 있어야 한다")
		if not face_bounds.has(normal):
			face_bounds[normal] = Rect2(uv, Vector2.ZERO)
		face_bounds[normal] = face_bounds[normal].expand(uv)
	check(
		box.get_aabb().size.is_equal_approx(Vector3.ONE) and face_bounds.size() == 6, "공유 상자는 실제 단위 크기와 여섯 면을 보존해야 한다"
	)
	for bounds in face_bounds.values():
		check(bounds.size.is_equal_approx(Vector2.ONE), "박스의 각 면은 전체 0~1 UV를 사용해야 한다")
	b.choose_mode("track", 4)
	check(b.atmosphere.sky == null, "가려진 코스 선택에서는 하늘 할당을 다음 렌더까지 미뤄야 한다")
	b.warming_world = true
	check(b.atmosphere.sky != null, "전환 화면 뒤 실제 프리워밍을 시작하면 선택 코스의 하늘을 생성해야 한다")
	b.warming_world = false
	var landmarks: Node3D = b.track.scenery.landmarks
	for batch in landmarks.batches:
		if batch.material_override is ShaderMaterial:
			var uses_uv: bool = batch.material_override.get_shader_parameter("uv_projection") == true
			check(uses_uv == (batch.multimesh.mesh == box), "상자만 미터 비례 UV를 사용하고 곡면 구조물은 삼면 투영을 유지해야 한다")
	a.queue_free()
	await settle(tree)
	check(
		(
			Pool.owners == 1
			and Pool.unit_box() == box
			and Pool.quad(Vector2(20, 8.75)) == quad
			and not Ads.atlases.is_empty()
		),
		"한 씬의 종료가 다른 활성 씬의 공유 리소스를 비우면 안 된다"
	)
	var unused_model: WeakRef = weakref(Props.model("rural_chalet"))
	var unused_material: WeakRef = weakref(Props.material_for("rural_chalet"))
	b.choose_mode("track", 1)
	await settle(tree)
	check(
		unused_model.get_ref() == null and unused_material.get_ref() == null,
		"코스 전환 후 다음 코스에서 쓰지 않는 건물 메시·외벽 재질을 붙들면 안 된다"
	)
	tree.root.remove_child(b)
	check(Pool.owners == 0 and Pool.quads.is_empty(), "씬이 트리에서 나가면 노드를 보관하더라도 캐시 소유권을 해제해야 한다")
	tree.root.add_child(b)
	check(Pool.owners == 1, "동일 노드 재진입은 _ready 재호출 없이도 캐시 소유권을 다시 가져야 한다")
	b.queue_free()
	await settle(tree)
	check(
		(
			Pool.owners == 0
			and Pool.quads.is_empty()
			and Pool.box_mesh == null
			and Pool.traffic_models.is_empty()
			and Pool.shared_world_scenes.is_empty()
			and Pool.shared_world_materials.is_empty()
		),
		"마지막 씬이 끝나면 공유 메시의 강한 참조를 해제해야 한다"
	)
	check(
		(
			Ads.materials.is_empty()
			and Ads.prop_prints.is_empty()
			and Ads.atlases.is_empty()
			and Props.mesh_cache.is_empty()
			and Props.shared_materials.is_empty()
		),
		"마지막 씬이 끝나면 광고·건물 메시·외벽 재질 캐시도 비워야 한다"
	)
	tree.root.disable_3d = viewport_was_disabled
	print("렌더 리소스 지연 생성·공유 / 박스 UV / 복수 씬 수명 / 캐시 해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
