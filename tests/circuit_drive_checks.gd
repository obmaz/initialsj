extends SceneTree
# Drive real inputs through the world controller; never advance road telemetry.
const Report = preload("res://tests/report.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var race = load("res://scenes/race.tscn").instantiate()
 root.add_child(race)
 race.set_physics_process(false)
 race.save_records = false
 race.choose_mode("track",0)
 await physics_frame
 await physics_frame
 var report := []
 var arguments := OS.get_cmdline_user_args()
 var vehicles: Array[int] = []
 vehicles.assign(range(preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()))
 if not arguments.is_empty(): vehicles = [clampi(int(arguments[0]),0,preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()-1)]
 for index in vehicles:
  race.open_garage()
  race.select_vehicle(index)
  race.restart()
  race.state = "racing"
  var peak := 0.0
  var peak_height := -INF
  var low_height := INF
  var last_lap := 0
  var target_lane := -2.5
  for frame in range(36000):
   var body: CharacterBody3D = race.world_race.player_body
   var forward: Vector3 = body.forward_direction()
   var right := Vector3(-forward.z,0,forward.x).normalized()
   if frame%15 == 0:
    var best := INF
    for candidate in [-3.5,0.0,3.5]:
     var cost: float = absf(candidate-target_lane)*0.15+race.Features.lane_cost(race.track.active,race.distance,candidate)
     for rival in race.rivals:
      if not rival.active: continue
      var gap: float = race.relative_gap(rival.distance,race.distance)
      if gap > -6 and gap < 45 and absf(candidate-rival.lane) < 2.8: cost += 50-gap
     if cost < best: best = cost; target_lane = candidate
   var look := clampf(race.speed*0.65,14,46)
   var to: Vector3 = race.track.point(race.distance+look,target_lane)-body.feet_position()
   var angle := atan2(to.dot(right),to.dot(forward))
   var wheel: float = (0.46+race.vehicle.handling*0.007)/(1+race.speed*0.035)*race.world_race.WorldCar.steering_scale(race.speed)
   var axis := clampf(atan(5.4*sin(angle)/look)/wheel,-1,1)
   var safe: float = race.vehicle.max_speed
   for ahead in [0.0,25.0,55.0,95.0,145.0]:
    var radius_speed: float = sqrt(race.vehicle.grip*0.72/maxf(absf(race.track.curvature(race.distance+ahead)),0.0001))
    safe = minf(safe,sqrt(radius_speed*radius_speed+2*25*ahead))
   for rival in race.rivals:
    if not rival.active: continue
    var gap: float = race.relative_gap(rival.distance,race.distance)
    if gap > 0 and gap < 40 and absf(rival.lane-race.lane) < 2.4:
     safe = minf(safe,sqrt(rival.speed*rival.speed+2*30*maxf(0,gap-8)))
   var brake: bool = race.speed > safe+0.5
   var nitro: bool = safe > race.vehicle.max_speed+5 and not brake
   await physics_frame
   race.step(1.0/60,axis,false,true,brake,nitro)
   peak = maxf(peak,race.speed)
   peak_height = maxf(peak_height,body.feet_position().y)
   low_height = minf(low_height,body.feet_position().y)
   if frame%1800 == 0: print(JSON.stringify({"vehicle":index,"frame":frame,"lap":race.laps_completed,"distance":race.distance,"lane":race.lane,"speed":race.speed}))
   if frame > 300 and frame%300 == 0 and race.speed < 1:
    var contacts := []
    for hit in body.last_contacts: contacts.append({"collider":hit.collider.name,"normal":str(hit.normal),"speed":hit.speed})
    print(JSON.stringify({"stopped_vehicle":index,"frame":frame,"feet":str(body.feet_position()),"heading":str(forward),"contacts":contacts}))
   if race.laps_completed != last_lap: last_lap = race.laps_completed; print("Completed lap ",last_lap," vehicle ",index)
   if race.state == "finished": break
   if frame%600 == 0: await process_frame
  var entry := {"vehicle":race.vehicle.id,"state":race.state,"laps":race.laps_completed,"seconds":snappedf(race.elapsed,0.01),"position":race.race_position(),"peak_kmh":snappedf(peak*3.6,0.1),"walls":race.wall_hits,"contacts":race.traffic_hits,"elevation_span_m":peak_height-low_height,"distance_m":race.distance}
  print(JSON.stringify(entry))
  report.append(entry)
  if race.state != "finished" or race.laps_completed != 3 or peak_height-low_height < 50:
   push_error("Each vehicle must complete the real 3D Fuji course with its elevation and ordered lap gates")
   failures += 1
  await process_frame
 var filename := "circuit-metrics.json" if arguments.is_empty() else "circuit-vehicle-%d-metrics.json" % vehicles[0]
 FileAccess.open(Report.path(filename),FileAccess.WRITE).store_string(JSON.stringify({"vehicles":report,"failures":failures},"\t")+"\n")
 race.queue_free()
 await process_frame
 quit(1 if failures else 0)
