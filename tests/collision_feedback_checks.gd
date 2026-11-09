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
	var d := 80.0
	var edge: float = race.track.half_width(d)+race.track.active.rail_setback(d,1)
	preload("res://tests/tour_world_checks.gd").new().set_car(race,d,edge-1.3,speed)
	var body: CharacterBody3D = race.world_race.player_body
	var up: Vector3 = race.world_race.road_up(d)
	var direction: Vector3 = (race.track.point(d,1)-race.track.point(d,-1)).normalized()
	body.reset_pose(body.feet_position(),direction,up)
	body.velocity = direction*speed
	for frame in range(30):
		race.step(1.0/60,0,false,false,false)
		if race.wall_hits > 0: break
	if speed > 0: check(race.wall_hits == 1,"장벽 검사는 실제 차체를 가드레일에 충돌시켜야 한다")
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
	check(race.collision_camera_offset(forward,right).length() <= 1.3,"Collision recoil must stay within a bounded camera displacement (hard hits punch the camera, but never leave the car)")
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
