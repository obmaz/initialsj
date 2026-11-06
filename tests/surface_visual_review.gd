extends SceneTree
const Report = preload("res://tests/report.gd")
# Native captures use the actual meshes, camera, HUD and pooled water particles.
func _initialize() -> void: call_deferred("run")
func capture(name: String, race: Node3D) -> void:
	race.place_cars()
	race.update_camera(1)
	race.player.animate(0,false,race.pad_active,0.1,0,false,0)
	race.speed_effect.material.set_shader_parameter("strength",clampf((race.speed-35)/53,0,1))
	race.hud.queue_redraw()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Report.path(name+".png"))
func run() -> void:
	Engine.time_scale = 0.1
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.choose_mode("tour")
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	var pad: Dictionary = race.track.active.features[0]
	race.distance = pad.distance-25
	race.lane = pad.lane
	race.speed = 65
	await capture("road-boost-pad",race)
	race.distance = pad.distance-5
	race.step(0.08,0,false,true,false)
	await capture("road-pad-active",race)
	race.surface.reset()
	var water: Dictionary = race.track.active.features[1]
	race.distance = water.distance-25
	race.lane = water.lane
	race.speed = 65
	await capture("road-puddle",race)
	race.distance = water.distance-6
	race.step(0.1,0,false,true,false)
	await create_timer(0.16).timeout
	await capture("road-water-splash",race)
	race.queue_free()
	for i in range(4): await process_frame
	quit()
