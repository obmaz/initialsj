extends RefCounted
const Power = preload("res://scripts/physics/drive_power.gd")
const Probe = preload("res://tests/corner_feel_checks.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var helper := Probe.new()
	var race := helper.make_race(tree)
	race.choose_mode("track", 0)
	var floor := helper.physical_floor(tree)
	await tree.physics_frame
	await tree.physics_frame
	var rows := []
	for vehicle in range(4):
		race.open_garage()
		race.select_vehicle(vehicle)
		var entry: float = race.vehicle.boost_speed
		var held: Dictionary = await helper.world_trial(tree, race, 0, true, false, false, false, entry)
		var released: Dictionary = await helper.world_trial(tree, race, 0, false, false, false, false, entry)
		var braking: Dictionary = await helper.world_trial(tree, race, 0, true, true, false, false, entry)
		check(
			held.exit_mps >= released.exit_mps - .05 and held.exit_mps < entry, "부스트 종료 후 가속 유지는 자연 감속보다 강한 제동을 만들지 않는다"
		)
		check(braking.exit_mps < held.exit_mps - 5, "관성을 보존해도 실제 브레이크는 충분히 감속한다")
		check(held.wall_hits == 0 and held.offroad == 0 and not held.airborne, "관성 비교는 접지한 평지에서 수행한다")
		rows.append({"vehicle": race.vehicle.id, "held": held, "released": released, "braking": braking})
	var speed := 100.0
	for tick in range(3600):
		speed = Power.target(speed, 72, 16, 1.0 / 60, true)
	check(is_equal_approx(speed, 72), "초과 속도를 무한 유지하거나 원래 상한 아래로 떨어뜨리지 않는다")
	check(Power.target(90, 50, 20, .5, true, 1) < Power.target(90, 50, 20, .5, true), "이탈 노면의 항력은 부스트 지름길을 억제한다")
	FileAccess.open("res://build/reports/momentum-metrics.json", FileAccess.WRITE).store_string(
		JSON.stringify(rows, "  ")
	)
	race.free()
	floor.free()
	await tree.process_frame
	print("부스트 종료 관성 / 가속·해제·제동4차종 / 초과 속도 수렴·이탈 항력: ", "PASS" if failures == 0 else "FAIL")
	return failures
