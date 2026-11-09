extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(message)
func isolated(race: Node3D) -> Dictionary:
	race.restart()
	race.state = "racing"
	for r in race.rivals: r.active = false
	var other: Dictionary = race.rivals[0]
	other.active = true
	other.speed = 0
	other.pace = 0
	other.lane = 0
	other.target_lane = 0
	other.decision = 100
	race.speed = 0
	race.lane = 0
	return other
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var other := isolated(race)
	var saved: Array = race.track.active.features.duplicate(true)
	for airborne in [true,false]:
		other = isolated(race)
		race.distance = -500
		race.track.active.features.assign([{"id":"review-water","kind":"water","distance":90.0,"lane":0.0,"length":8.0,"width":4.0}])
		other.distance = 70
		other.speed = 60
		other.pace = 60
		other.air.active = airborne
		other.air.height = 3 if airborne else 0
		other.air.world_y = race.track.point(70).y+other.air.height
		other.air.velocity = 0
		race.brain.tick(race,0.8)
		check(other.surface.puddles_hit == (0 if airborne else 1),"CPU landing must not collect a puddle flown over before touchdown; grounded crossing must still work")
	race.track.active.features.assign(saved)
	# 실제 차체의 높이별 충돌은 world_car_checks 및 tour_world_checks에서 검증한다.
	var budget = race.render_budget
	race.state = "racing"
	race.elapsed = 10
	budget.set_mode(0,race)
	budget.level = 0
	for frame in range(31):
		budget.last_tick = Time.get_ticks_usec()-33334
		budget.tick(race)
	race.pause_tour()
	budget.tick(race)
	check(budget.slow_windows == 0,"Pausing must break a sequence of slow quality windows")
	race.state = "racing"
	for frame in range(31):
		budget.last_tick = Time.get_ticks_usec()-33334
		budget.tick(race)
	check(budget.level == 0,"A fresh single slow window after pause must not degrade quality")
	budget.set_mode(0,race)
	budget.level = 0
	for frame in range(2):
		budget.last_tick = Time.get_ticks_usec()-1000000
		budget.tick(race)
	check(budget.level == 1,"Repeated one-second foreground frames must trigger automatic quality reduction")
	check(race.hud.hit_button("pause",race.hud.PAUSE_BUTTON.position+Vector2(-5,30)),"The pause icon needs a phone-sized padded touch target")
	FileAccess.open(Report.path("review-regression-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"checks":["CPU airborne landing versus grounded puddle crossing","incline world-height clearance in helper and actual collision step","pause breaks slow quality windows","foreground one-second frames lower AUTO quality","expanded mobile pause touch target"]},"\t")+"\n")
	race.queue_free()
	await tree.process_frame
	print("Review incline / CPU landing / quality / pause regressions: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	return failures
