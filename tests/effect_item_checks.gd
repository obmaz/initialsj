extends RefCounted
const Items = preload("res://scripts/vehicles/effect_items.gd")
const Store = preload("res://scripts/vehicles/customization_store.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
var failures := 0


func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)


func run(tree: SceneTree) -> int:
	for vehicle in range(4):
		check(Items.slots(vehicle) == [1, 2, 2, 3][vehicle], "모델 정의가 차량별 슬롯 수를 제한한다")
		var data := Store.sanitize(
			{"effects": ["open_top", "nitro_blur", "nitro_blur", "invalid", "mega_exhaust", "air_spin"]}, vehicle
		)
		check(data.effects.size() == Items.slots(vehicle), "중복·잘못된 ID를 제외하고 슬롯 상한까지 저장한다")
		check(("open_top" in data.effects) == (vehicle == 3), "오픈카는 지원 모델에만 장착한다")
	check(Store.sanitize({"paint": "abcdef"}, 0).effects.is_empty(), "기존 v1 선택은 이펙트 없는 외형으로 보존한다")
	var store := Store.new()
	store.path = "user://effect_item_test.cfg"
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 1)
	legacy.set_value("vehicles", "nimori", {"paint": "abcdef"})
	legacy.save(store.path)
	store.load_config()
	check(
		not store.read_only and store.selection(0).paint == "abcdef" and store.selection(0).effects.is_empty(),
		"실제 v1 파일을 기존 도장 보존 상태로 읽는다"
	)
	var selected := Store.defaults(3)
	selected.effects = ["open_top", "mega_exhaust", "air_spin"]
	check(store.save(3, selected) == OK, "효과 선택을 원자적으로 저장한다")
	store.load_config()
	check(store.selection(3).effects == selected.effects, "저장 후 다시 로드해도 장착을 보존한다")
	DirAccess.remove_absolute(store.path)
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.open_garage()
	race.select_vehicle(3)
	var original: Mesh = race.player.body.get_node("PaintShell").mesh
	Custom.apply(race.player, selected, 3)
	check(
		race.player.body.get_node("PaintShell").mesh != original and race.player.body.get_node("OpenCabin").visible,
		"오픈카는 지붕 없는 실제 GLB 메시와 실내를 적용한다"
	)
	var mesh: Mesh = race.player.body.get_node("PaintShell").mesh
	Custom.apply(race.player, selected, 3)
	check(race.player.body.get_node("PaintShell").mesh == mesh, "장착 반복 시 메시를 복제하지 않는다")
	Custom.apply(race.player, Store.defaults(3), 3)
	check(
		race.player.body.get_node("PaintShell").mesh == original and not race.player.body.get_node("OpenCabin").visible,
		"해제하면 원래 지붕·도장을 복원한다"
	)
	check(
		race.player.headlight.light_energy >= 7 and race.player.headlight.spot_range >= 160, "기존 단일 헤드라이트의 밝기·거리를 높인다"
	)
	race.restart()
	race.state = "racing"
	Custom.apply(race.player, selected, 3)
	var body: CharacterBody3D = race.world_race.player_body
	body.grounded = false
	var position: Vector3 = body.global_position
	var velocity: Vector3 = body.velocity
	race.air.trick = true
	race.air.height = 8
	race.air.velocity = 6
	race.equipped_effects.advance(race, .1)
	check(race.equipped_effects.spin > 0, "충분히 높은 실제 점프 상태에서 시각 회전을 시작한다")
	for frame in range(90):
		race.equipped_effects.advance(race, 1.0 / 60)
	check(race.equipped_effects.spin == 0 and race.equipped_effects.used_jump, "한 점프에서 한 번만360도 회전한다")
	check(body.global_position == position and body.velocity == velocity, "이펙트는 실제 위치·속도·방향에 힘을 가하지 않는다")
	race.player.equipped_effects.assign(["nitro_blur"])
	race.nitro_active = true
	race.equipped_effects.advance(race, .2)
	check(race.equipped_effects.blur > 0, "장착한 니트로 블러는 실활성 중 커진다")
	race.motion_reduced = true
	race.equipped_effects.advance(race, 1)
	check(race.equipped_effects.blur == 0 and race.equipped_effects.spin == 0, "동작 감소는 회전·강한 블러를 끈다")
	race.motion_reduced = true
	race.track_environment.weather = "rain"
	race.track_environment.time_of_day = "night"
	race.choose_mode("track", 0)
	race.restart()
	race.state = "racing"
	race.sound_enabled = true
	var storm: Node3D = race.thunderstorm
	check(storm.bolt == null, "동작 감소로 첫 진입할 때 번개는 비활성 상태다")
	race.state = "paused"
	race.motion_reduced = false
	storm.advance(0)
	check(storm.bolt != null and storm.flash == 0, "같은 경기의 일시정지에서 FULL로 바꾸면 번개 자원을 준비한다")
	race.state = "racing"
	check(storm.eligible() and storm.bolt != null, "후지 야간 우천에서 번개 자원을 미리 준비한다")
	storm.strike()
	storm.advance(.01)
	check(
		storm.flash > 0 and storm.light.visible and storm.bolt.visible and storm.thunder_delay > 1,
		"먼 번개·노면 조명 뒤 천둥을 지연한다"
	)
	storm.thunder_delay = .01
	storm.advance(.02)
	check(storm.audio.playing, "지연 시간이 끝나면 준비된 천둥 한 보이스를 재생한다")
	storm.strike()
	var delay: float = storm.thunder_delay
	race.state = "paused"
	storm.advance(1)
	check(
		storm.thunder_delay == delay and (not storm.audio.playing or storm.audio.stream_paused),
		"일시정지는 번개 시간·지연 천둥을 동결한다"
	)
	race.motion_reduced = true
	storm.advance(0)
	check(storm.flash == 0 and not storm.light.visible and storm.thunder_delay < 0, "일시정지 중 동작 감소를 켜도 플래시·대기 천둥을 즉시 끈다")
	race.motion_reduced = false
	race.state = "racing"
	storm.strike()
	race.state = "ready"
	storm.advance(0)
	check(not storm.light.visible and storm.thunder_delay < 0 and not storm.audio.playing, "메뉴 복귀는 플래시와 대기 음원을 취소한다")
	race.motion_reduced = true
	check(not storm.eligible(), "동작 감소에서는 번개를 사용하지 않는다")
	race.motion_reduced = false
	race.state = "ready"
	var shop := preload("res://scripts/ui/tuning/tuning_shop.gd").new()
	shop.race = race
	shop.vehicle_index = 3
	shop.saved_customization = Store.defaults(3)
	shop.draft_customization = selected.duplicate(true)
	race.add_child(shop)
	shop.set_process(false)
	shop.selected_tab = 4
	shop.rebuild_options()
	for child in shop.options_panel.get_children():
		if child is Button and child.get_meta("effect_id", "") == "mega_exhaust":
			child.pressed.emit()
	check(not shop.preview_car.boost_fx.mega, "실제 아이템 버튼이 해당 장착만 해제한다")
	shop.toggle_effect("mega_exhaust")
	shop.boost_preview_active = true
	shop._process(.2)
	check(not shop.preview_car.presentation.basis.is_equal_approx(Basis.IDENTITY), "실제 샵 시연이 시각 피벗을 회전시킨다")
	shop.toggle_effect("air_spin")
	shop._process(.016)
	check(shop.preview_car.presentation.basis.is_equal_approx(Basis.IDENTITY), "시연 중 효과 해제는 기울어진 차체를 복원한다")
	shop.toggle_effect("air_spin")
	shop._process(.2)
	shop.toggle_compare()
	shop._process(.016)
	check(shop.preview_car.presentation.basis.is_equal_approx(Basis.IDENTITY), "미장착 저장값과 비교하면 회전 시연을 복원한다")
	shop.free()
	race.free()
	await tree.process_frame
	print("차량별 효과 슬롯 / 저장·오픈카 복원 / 물리 독립 회전 / 야간 번개 수명: ", "PASS" if failures == 0 else "FAIL")
	return failures
