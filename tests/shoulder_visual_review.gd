extends SceneTree
const Report = preload("res://tests/report.gd")
func _initialize() -> void: call_deferred("run")
func shot(race: Node3D, name: String) -> void:
	race.place_cars()
	race.update_camera(1)
	race.update_atmosphere(1)
	race.player.reset_physics_interpolation()
	race.camera.reset_physics_interpolation()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Report.path(name+".png"))
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.choose_mode("tour")
	race.state = "racing"
	for r in race.rivals: r.active = false
	race.distance = race.track.length*0.24
	race.lane = 0
	race.speed = 60
	await shot(race,"shoulder-tour-wide")
	race.lane = race.track.half_width(race.distance)+2.2
	race.offroad_amount = 1
	race.speed = 42
	race.shoulder_dust.particles.speed_scale = 0.2
	race.shoulder_dust.burst(race.track.point(race.distance-2,race.lane),true)
	await shot(race,"shoulder-tour-dirt")
	root.size = Vector2i(896,414)
	await shot(race,"shoulder-mobile-dirt")
	root.size = Vector2i(1280,720)
	race.choose_mode("track",0)
	race.state = "racing"
	for r in race.rivals: r.active = false
	race.distance = race.track.length*0.11
	race.lane = 0
	race.speed = 60
	await shot(race,"shoulder-fuji-wide")
	var tightest := 0.0
	var hairpin := 0.0
	for i in range(1200):
		var d: float = race.track.length*i/1200
		var bend: float = absf(race.track.curvature(d))
		if bend > tightest: tightest = bend; hairpin = d
	race.distance = hairpin-30
	race.lane = -2
	race.speed = 42
	await shot(race,"guardrail-fuji-curve")
	race.camera.position = race.track.point(hairpin,9)+Vector3.UP*3
	race.camera.look_at(race.track.point(hairpin+25,9)+Vector3.UP*0.8)
	race.camera.fov = 52
	race.camera.reset_physics_interpolation()
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Report.path("guardrail-detail.png"))
	race.queue_free()
	for frame in range(4): await process_frame
	quit()
