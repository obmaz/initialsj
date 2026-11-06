extends SceneTree
var rows := []
func _initialize() -> void: call_deferred("run")
func capture(race: Node3D, name: String) -> void:
 race.place_cars()
 race.update_atmosphere(5)
 race.update_camera(1)
 race.player.reset_physics_interpolation()
 race.camera.reset_physics_interpolation()
 race.hud.queue_redraw()
 for frame in range(5): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/"+name+".png")
 rows.append({"scene":name,"draw_calls":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"viewport":str(root.size)})
func run() -> void:
 var race = load("res://scenes/race.tscn").instantiate()
 root.add_child(race)
 race.set_physics_process(false)
 race.save_records = false
 race.sound_enabled = false
 for shot in [["tour",0,0,500.0,"regional-3d-palm-coast"],["tour",1,1,800.0,"regional-3d-city"],["track",0,0,470.0,"regional-3d-fuji"]]:
  race.choose_mode(shot[0],0)
  if shot[0] == "tour": race.track.reset(shot[1],shot[2])
  race.state = "racing"
  race.distance = shot[3]
  race.speed = 65
  race.lane = -2
  race.camera_intro = 0
  for rival in race.rivals: rival.active = false
  await capture(race,shot[4])
 FileAccess.open("res://docs/scenery-3d-render-metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"environment":"Godot 4.7.2 native Compatibility / Mesa llvmpipe / frozen 1280x720 views","note":"Draw submissions, not an Android/browser FPS measurement","views":rows},"\t")+"\n")
 race.queue_free()
 for frame in range(3): await process_frame
 quit()
