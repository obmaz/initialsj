extends RefCounted
const Store = preload("res://scripts/vehicles/customization_store.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var store := Store.new()
	store.path = "res://build/reports/tuning-check.cfg"
	DirAccess.remove_absolute(store.path)
	for i in range(4):
		var car := Factory.create(i)
		tree.root.add_child(car)
		var defaults := Store.defaults(i)
		var data := defaults.duplicate(true)
		data.paint = "19ceca"
		data.livery = i % 3 + 1
		data.wheel = 1 + i % 2
		data.wing = 1 + i % 2
		var dimensions: Vector3 = Vector3(car.wheel_radius, car.wheel_half_track, car.wheel_half_base)
		var center: Vector3 = car.wheels[0].position
		Custom.apply(car, data, i)
		check(
			car.body.get_node_or_null("PaintShell") != null and car.body.get_node_or_null("TrimShell") != null,
			"차종별 전용 도장면과 비도장 트림이 존재한다"
		)
		var shell: MeshInstance3D = car.body.get_node("PaintShell")
		var packed: PackedScene = load("res://models/vehicles/" + car.model + "/model.glb")
		var raw := packed.instantiate()
		var legacy: MeshInstance3D = raw.find_child("BodyShell", true, false)
		var trim: MeshInstance3D = car.body.get_node("TrimShell")
		check(
			legacy.mesh.get_faces().size() == shell.mesh.get_faces().size() + trim.mesh.get_faces().size(),
			"표시용 도장·트림의 삼각형 합은 보존한 원본 차체와 같다"
		)
		raw.free()
		var original: Material = shell.material_override
		check(
			(
				original.get_shader_parameter("livery") == data.livery
				and original.get_shader_parameter("vehicle_column") == i
			),
			"리버리는 차종별 생성 이미지 셀을 선택한다"
		)
		check(
			(
				Vector3(car.wheel_radius, car.wheel_half_track, car.wheel_half_base) == dimensions
				and center == car.wheels[0].position
			),
			"외형 교체는 실제 휠 치수·접지 중심을 바꾸지 않는다"
		)
		var rim: MeshInstance3D = car.wheels[0].get_node("TuningRim")
		for wheel in car.wheels:
			check(wheel.get_node("TuningRim").mesh == rim.mesh, "네 교체 림은 동일 GLB 메시를 공유한다")
		var wing: MeshInstance3D = car.active_aero
		for j in range(25):
			data.paint = Color.from_hsv(j / 25.0, .6, .8).to_html(false)
			Custom.apply(car, data, i)
		check(
			(
				shell.material_override == original
				and car.active_aero == wing
				and car.wheels[0].get_node("TuningRim") == rim
			),
			"도장 변경은 재질·휠·윙을 다시 생성하지 않고 유니폼만 바꾼다"
		)
		for wheel in car.wheels:
			if wheel.has_node("TuningRim"):
				check(wheel.has_node("TuningRimInner"), "교체한 휠은 차량 양쪽 면에 모두 표시한다")
		car.set_protection(true)
		check(shell.material_override.get_shader_parameter("protection"), "리버리에도 리스폰 보호 표시가 적용된다")
		car.set_protection(false)
		check(shell.material_override == original, "보호가 끝나면 리버리 재질을 정확히 복원한다")
		check(store.save(i, data) == OK, "차종별 튜닝 설정을 원자적으로 저장한다")
		var loaded := Store.new()
		loaded.path = store.path
		loaded.load_config()
		check(loaded.selection(i) == data, "재실행 뒤 같은 도장·리버리·부품을 복원한다")
		var copy := loaded.selection(i)
		copy.wing = 3
		check(loaded.selection(i) == data, "미리보기 변경은 적용 전 저장값을 수정하지 않는다")
		data.wing = 3
		Custom.apply(car, data, i)
		check(car.active_aero == null, "윙 없음은 부스트 가동 연결을 안전하게 해제한다")
		Custom.apply(car, defaults, i)
		check(
			car.active_aero == car.get_meta("stock_aero") and car.wheels[0].get_node_or_null("TuningRim") == null,
			"순정 복원은 원래 윙·타이어 피벗을 되돌린다"
		)
		car.free()
		await tree.process_frame
	check(
		Store.sanitize({"paint": "bad color", "wheel": 99, "finish": -1}, 0) == Store.defaults(0),
		"손상된 설정·비호환 ID는 순정으로 제한한다"
	)
	var future := ConfigFile.new()
	future.set_value("meta", "version", 99)
	future.save(store.path)
	store.load_config()
	check(store.read_only and store.save(0, Store.defaults(0)) == ERR_UNAVAILABLE, "알 수 없는 미래 버전은 덮어쓰지 않는다")
	DirAccess.remove_absolute(store.path)
	print("차종별 리버리·휠·윙 / 성능 보존 / 색 변경 자원 재사용 / 보호 복원 / 저장·손상·미래 버전: ", "PASS" if failures == 0 else "FAIL")
	return failures
