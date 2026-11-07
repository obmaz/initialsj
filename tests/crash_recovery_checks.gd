extends RefCounted
const Recovery=preload("res://scripts/recovery_state.gd")
var failures:=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func reset(r:Node3D)->void:
 r.restart()
 r.state="racing"
 for rival in r.rivals:rival.active=false
func run(tree:SceneTree)->int:
 var detector=Recovery.new()
 detector.advance(0.1,Vector3.ZERO)
 detector.advance(3.9,Vector3(2,0,0))
 check(not detector.available,"Recovery must not appear before four seconds of little movement")
 detector.advance(0.11,Vector3(2,0,0))
 check(detector.available,"A car trapped within three metres must get a recovery action")
 detector.advance(0.1,Vector3(4,0,0))
 check(not detector.available and detector.stopped_time==0,"Meaningful forward or reverse movement must clear the stuck timer")
 detector.advance(4.1,Vector3(4,8,0))
 check(detector.available,"Vertical bouncing without horizontal escape must still offer recovery")
 var r=load("res://scenes/race.tscn").instantiate()
 tree.root.add_child(r)
 r.set_physics_process(false)
 r.save_records=false
 for mode in ["tour","track"]:
  r.choose_mode(mode,1)
  reset(r)
  r.distance=80
  r.lane=r.track.lane_limits(r.distance).y-0.1
  r.speed=80
  r.lane_velocity=18
  r.step(0.05,1,false,true,false)
  check(r.crash.active and r.air.active and r.lane_velocity<0,"A fast hard guardrail hit must rebound inward and launch a tumble")
  r.crash.advance(0.3)
  check(absf(r.crash.visual_roll)>0.2,"A launched crash must visibly roll the chassis")
  r.apply_crash_pose()
  var centre:Vector3=r.player.body.transform*Vector3(0,0.7,0)
  check(centre.distance_to(Vector3(0,r.player.ride_offset+0.7,0))<0.001,"The visual tumble must rotate around the chassis centre rather than its tyre contact point")
  reset(r)
  r.lane=r.track.lane_limits(r.distance).y-0.01
  r.speed=85
  r.lane_velocity=1
  r.step(0.02,1,false,true,false)
  check(r.crash.active and r.air.active,"Any rail hit above the launch speed must throw the car, even a shallow one")
  reset(r)
  r.lane=r.track.lane_limits(r.distance).y-0.01
  r.speed=35
  r.lane_velocity=12
  r.step(0.02,1,false,true,false)
  check(not r.crash.active,"A rail hit below the launch speed must only bounce")
  reset(r)
  r.speed=75
  var other:Dictionary=r.rivals[0]
  other.active=true
  other.distance=r.distance+3
  other.lane=r.lane
  other.speed=30
  r.resolve_contact(other,{"normal":Vector2(0,-1),"depth":0.3})
  check(r.speed<other.speed and not r.crash.active,"Ordinary car contact must rebound by exchanging relative momentum without an automatic flip")
  reset(r)
  for frame in range(42):r.step(0.1,0,false,false,false)
  check(r.recovery_available,"The actual stationary race must offer recovery")
  var elapsed:float=r.elapsed
  var time_left:float=r.time_left
  var laps:int=r.laps_completed
  var checkpoint:int=r.checkpoints
  r.air.consumed["used-ramp"]=true
  r.air.launches=5
  r.rivals[0].active=true
  r.rivals[0].distance=r.distance
  r.rivals[0].lane=0
  r.recover_car()
  check(not r.recovery_available and r.speed==0 and not r.crash.active,"Manual recovery must restore an upright stopped car and clear its button")
  check(absf(r.lane-r.rivals[0].lane)>2.6,"Recovery must select a road lane clear of the occupied car")
  check(r.elapsed==elapsed and r.time_left==time_left and r.laps_completed==laps and r.checkpoints==checkpoint,"Recovery must never award time or alter checkpoint/lap progress")
  check(r.air.consumed.has("used-ramp") and r.air.launches==5,"Recovery must preserve used ramp and jump statistics rather than rearming rewards")
 r.queue_free()
 await tree.process_frame
 print("Crash rebound / severe versus scrape / stuck window / manual safe recovery: ","PASS" if failures==0 else "FAIL")
 return failures
