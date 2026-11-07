extends RefCounted
const Surface=preload("res://scripts/road_surface_state.gd")
var failures:=0
func check(ok:bool,message:String)->void:
 if not ok: failures+=1;push_error(message)
func run(tree:SceneTree)->int:
 var race=load("res://scenes/race.tscn").instantiate()
 tree.root.add_child(race)
 race.set_physics_process(false)
 race.save_records=false
 race.choose_mode("track",1)
 var section:Node3D=race.track.active
 var lanes:Array=section.features.filter(func(f):return f.kind=="boost_lane")
 var pads:Array=section.features.filter(func(f):return f.kind=="boost" and f.length<=12)
 check(lanes.size()==2 and pads.size()==12,"Speedway needs two continuous lanes and two six-pad slaloms")
 var s=Surface.new()
 for lane in lanes:
  var p:=Vector2(lane.lane,lane.distance)
  s.reset()
  s.contact(section,p,p,80)
  check(s.lane_active and s.pad_time==0 and s.boosts_hit==0,"A lane must provide occupancy boost without timed credit or repeatable entry rewards")
  s.contact(section,p,p+Vector2(lane.width,0),80)
  check(not s.lane_active and s.pad_time==0,"Moving off the side must immediately remove lane boost")
  s.contact(section,p,p+Vector2(0,lane.length),80)
  check(not s.lane_active,"Crossing the complete lane in a long frame must not grant lingering boost")
  s.update_lane(section,p,80,true)
  check(not s.lane_active,"Braking must override the lane")
  s.update_lane(section,p,80,false,0,false)
  check(not s.lane_active,"Flying over a lane must not activate it")
  s.contact(section,p+Vector2(0,section.length),p+Vector2(0,section.length),80)
  check(s.lane_active,"Occupancy must work on later laps")
 for pad in pads:
  s.reset()
  var p:=Vector2(pad.lane,pad.distance)
  s.contact(section,p-Vector2(0,20),p+Vector2(0,20),100)
  check(s.boosts_hit==1 and s.pad_time<=0.5,"Short slalom pads must activate on a fast sweep and give a brief burst")
  s.reset()
  s.contact(section,Vector2(0,pad.distance-20),Vector2(0,pad.distance+20),100)
  check(s.boosts_hit==0,"The centre line must miss the alternating pads")
 for car in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
  race.open_garage()
  race.select_vehicle(car)
  race.restart()
  race.state="racing"
  for rival in race.rivals:rival.active=false
  var lane:Dictionary=lanes[0]
  race.distance=lane.distance
  race.lane=lane.lane
  race.speed=race.vehicle.max_speed
  for frame in range(12):race.step(1.0/60,0,false,true,false)
  check(race.pad_active and race.surface.lane_active and race.speed>race.vehicle.max_speed,"Every vehicle must accelerate through the actual race step on a lane")
  race.lane=0
  race.step(1.0/60,0,false,true,false)
  check(not race.surface.lane_active and not race.pad_active,"The actual controller must remove lane acceleration on lateral exit")
  race.distance=lane.distance
  race.lane=lane.lane
  race.air.active=true
  race.air.world_y=race.track.point(race.distance,race.lane).y+3
  race.air.height=3
  race.air.velocity=0
  race.step(1.0/60,0,false,true,false)
  check(not race.surface.lane_active,"The actual airborne controller must clear lane occupancy")
  race.restart()
  race.state="racing"
  for rival in race.rivals:rival.active=false
  var chain:Array=pads.filter(func(f):return f.distance>=2490)
  race.distance=chain[0].distance-35
  race.lane=chain[0].lane
  race.speed=race.vehicle.max_speed
  for frame in range(600):
   var next:=mini(race.surface.boosts_hit,chain.size()-1)
   var axis:=clampf((float(chain[next].lane)-race.lane)*0.6-race.lane_velocity*0.12,-1,1)
   race.step(1.0/60,axis,false,true,false)
   if race.distance>chain[-1].distance+20:break
  check(race.surface.boosts_hit==6 and race.wall_hits==0,"%s: six alternating pads must remain steerable without lane teleports (hits=%d, walls=%d)" % [race.vehicle.id,race.surface.boosts_hit,race.wall_hits])
 race.queue_free()
 await tree.process_frame
 print("Short slalom pads / boost-lane occupancy / brakes / airborne / all vehicles: ","PASS" if failures==0 else "FAIL")
 return failures
