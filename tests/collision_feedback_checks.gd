extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func ready_race(race: Node3D) -> void:
	race.restart()
	race.state = "racing"
	for r in race.rivals: r.active = false
func wall_hit(race: Node3D, speed: float) -> float:
	ready_race(race)
	race.speed = speed
	race.lane = 100
	race.step(1.0/60,0,false,false,false)
	check(race.wall_hits == 1,"Every wall fixture must exercise a real wall contact")
	return race.impact
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	check(wall_hit(race,0) == 0,"A parked car touching the rail must not trigger crash shake or crash audio")
	var gentle := wall_hit(race,12)
	var fast := wall_hit(race,70)
	check(fast > gentle+0.5,"High-speed scrapes must give stronger feedback than slow touches")
	var sides := []
	for side in [-1.0,1.0]:
		ready_race(race)
		race.camera_time = 0
		race.speed = 50
		race.register_impact(0.8,Vector2(side,0))
		race.update_camera(1.0/60)
		sides.append(race.camera.position-race.player.position)
	check(sides[0].distance_to(sides[1]) > 0.6,"The actual camera must recoil differently for opposite side contacts")
	var remembered: Vector2 = race.impact_normal
	race.register_impact(1,-remembered)
	check(race.impact_normal == remembered and race.impact_recoil == 0.8,"Repeated overlap during cooldown must not restart feedback or change its direction")
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	check(race.collision_camera_offset(forward,right).length() <= 0.5,"Collision recoil must stay within a small bounded camera displacement")
	race.impact_age = 0.43
	check(race.collision_camera_offset(forward,right).is_zero_approx(),"The brief recoil must settle instead of becoming a sustained shake")
	race.impact_age = 0
	race.motion_reduced = true
	check(race.collision_camera_offset(forward,right).is_zero_approx(),"Reduced motion must disable directional recoil")
	race.motion_reduced = false
	race.state = "paused"
	check(race.collision_camera_offset(forward,right).is_zero_approx(),"Pause and menus must not move the camera with collision feedback")
	var effect: Node3D = race.impacts
	effect.reset()
	check(effect.pool.size() == 4 and effect.chips.size() == 4,"Collision emitters must be preallocated to a fixed small pool")
	effect.burst(Vector3.ZERO,Vector3.LEFT,false,0)
	check(effect.cursor == 0,"Zero-strength contacts must not consume a particle emitter")
	effect.burst(Vector3.ZERO,Vector3.LEFT,false,0.2)
	var light_count: int = effect.pool[0].amount
	check(not effect.chips[0].visible,"Gentle contact must not scatter metal chips")
	effect.burst(Vector3.ZERO,Vector3.LEFT,false,0.9)
	check(effect.pool[1].amount > light_count and effect.pool[1].amount <= 36 and effect.chips[1].amount <= 8,"Hard impact particles must scale with severity and stay bounded")
	check(effect.chips[1].visible,"A meaningful hard impact must have small three-dimensional chips")
	effect.burst(Vector3.ZERO,Vector3.LEFT,true,1)
	check(effect.pool[2].amount <= 12 and not effect.chips[2].visible,"Reduced motion must use fewer sparks and omit chips")
	for emitter in effect.pool+effect.chips:
		check(emitter.one_shot and emitter.lifetime <= 0.46 and emitter.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Collision particles must expire quickly and never cast shadows")
	ready_race(race)
	for emitter in effect.pool+effect.chips:
		check(not emitter.visible and not emitter.emitting,"Restart must remove residual sparks from the previous run")
	check(race.impact == 0 and race.impact_recoil == 0,"Restart must clear collision camera state")
	race.queue_free()
	await tree.process_frame
	print("Collision severity / directional camera / cooldown / reduced motion / particle pool checks: ","PASS" if failures == 0 else "FAIL")
	return failures
