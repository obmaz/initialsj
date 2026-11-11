extends RefCounted
const Recovery = preload("res://scripts/race/recovery_state.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func reset(r: Node3D) -> void:
	r.restart()
	r.state = "racing"
	for rival in r.rivals:
		rival.active = false


func run(tree: SceneTree) -> int:
	var detector = Recovery.new()
	detector.advance(0.1, Vector3.ZERO)
	detector.advance(3.9, Vector3(2, 0, 0))
	check(not detector.available, "Recovery must not appear before four seconds of little movement")
	detector.advance(0.11, Vector3(2, 0, 0))
	check(detector.available, "A car trapped within three metres must get a recovery action")
	detector.advance(0.1, Vector3(4, 0, 0))
	check(
		not detector.available and detector.stopped_time == 0,
		"Meaningful forward or reverse movement must clear the stuck timer"
	)
	detector.advance(4.1, Vector3(4, 8, 0))
	check(detector.available, "Vertical bouncing without horizontal escape must still offer recovery")
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	r.set_physics_process(false)
	r.save_records = false
	# 투어도 같은 3D 차체를 사용한다. 실제 충돌 비행은 world_crash_checks에서 함께 검사한다.
	for mode in ["tour"]:
		r.choose_mode(mode, 1)
		reset(r)
		for frame in range(42):
			r.step(0.1, 0, false, false, false)
		check(r.recovery_available, "The actual stationary race must offer recovery")
		var elapsed: float = r.elapsed
		var time_left: float = r.time_left
		var laps: int = r.laps_completed
		var checkpoint: int = r.checkpoints
		r.air.landings = 4
		r.air.launches = 5
		r.rivals[0].active = true
		r.world_race.teleport(1, r.distance, 0)
		await tree.physics_frame
		r.recover_car()
		check(
			not r.recovery_available and r.speed == 0 and not r.crash.active,
			"Manual recovery must restore an upright stopped car and clear its button"
		)
		check(absf(r.lane - r.rivals[0].lane) > 2.6, "Recovery must select a road lane clear of the occupied car")
		check(
			(
				r.elapsed == elapsed
				and r.time_left == time_left
				and r.laps_completed == laps
				and r.checkpoints == checkpoint
			),
			"Recovery must never award time or alter checkpoint/lap progress"
		)
		check(r.air.landings == 4 and r.air.launches == 5, "Recovery must preserve actual jump and landing statistics")
	r.queue_free()
	await tree.process_frame
	print(
		"Crash rebound / severe versus scrape / stuck window / manual safe recovery: ",
		"PASS" if failures == 0 else "FAIL"
	)
	return failures
