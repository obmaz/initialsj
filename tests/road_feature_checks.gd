extends RefCounted
const Features = preload("res://scripts/road_features.gd")
const State = preload("res://scripts/road_surface_state.gd")
const Section = preload("res://scripts/road_section.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func isolate(race: Node3D) -> void:
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
func run(tree: SceneTree) -> int:
	for stage in range(5):
		for node in range(stage+1):
			var section := Section.new(Vector3(0,6,0),-PI/2,stage,node)
			var patches := Features.layout(section)
			var short_pads: Array = patches.filter(func(f): return f.kind == "boost" and f.length <= 12)
			var ramps: Array = patches.filter(func(f): return f.kind == "ramp")
			check(patches.size() >= 12 and patches.size() <= 34 and short_pads.size() == 6,"Each Tour route needs three readable alternating pad pairs among spaced gimmicks")
			check(ramps.size() >= 1 and ramps.size() <= 3,"Every Tour route needs one to three optional jumps")
			check(patches.filter(func(f): return f.kind == "mud").size() == 3,"Every Tour route needs mud beside its pad pairs")
			check(patches.filter(func(f): return f.kind == "truck").size() >= 1,"Every Tour route needs a parked truck")
			check(patches.filter(func(f): return f.kind == "water").size() == 2,"Every Tour route needs two separate puddle choices")
			for patch in patches:
				if patch.kind == "crest": continue
				check(patch.distance-patch.length/2 > 300 and patch.distance+patch.length/2 < section.checkpoint_distance()-80,"Patches must leave entries and the full checkpoint approach clear")
				check(absf(patch.lane)+patch.width*0.55 < section.half_width(patch.distance)-0.5,"Every patch must leave a usable escape lane")
				var from := Vector2(patch.lane,patch.distance-60)
				var to := Vector2(patch.lane,patch.distance+60)
				check(Features.swept_hit(patch,from,to,patch.distance),"Fast sweeps must not skip patches")
				from.x = -signf(patch.lane)*section.half_width(patch.distance)*0.75
				to.x = from.x
				check(not Features.swept_hit(patch,from,to,patch.distance),"Opposite lanes must avoid the patch")
			section.free()
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	isolate(race)
	var section: Node3D = race.track.active
	var pad: Dictionary = section.features[0]
	var water: Dictionary = section.features[1]
	var state := State.new()
	var point := Vector2(pad.lane,pad.distance)
	check(state.contact(section,point-Vector2(0,30),point+Vector2(0,30),80).has("boost"),"Pads must activate on a high-speed crossing")
	state.contact(section,point,point,80)
	check(state.boosts_hit == 1,"Waiting on a pad must not repeatedly recharge it")
	state.reset()
	state.contact(section,point,point,80,true)
	check(state.pad_time == 0,"Brakes must suppress pad activation")
	state.contact(section,point,point,80,false,0.3)
	check(state.pad_time == 0,"Collision stun must suppress pad activation")
	state.contact(section,point,point,80)
	state.tick(0.1,true)
	check(state.pad_time == 0,"Braking must cancel a running boost")
	point = Vector2(water.lane,water.distance)
	state.contact(section,point,point,60)
	state.contact(section,point,point,60)
	check(state.puddles_hit == 1 and state.grip_factor < 0.6 and state.lateral_factor < 0.4,"Water must lower grip once per entry")
	state.contact(section,point+Vector2(0,40),point+Vector2(0,40),60)
	state.tick(2)
	check(state.wet_time == 0 and state.grip_factor == 1 and state.lateral_factor == 1,"Grip must recover after leaving water")
	state.contact(section,point,point,60)
	check(state.puddles_hit == 2,"Leaving and re-entering water must create a fresh splash")
	for index in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(index)
		isolate(race)
		race.distance = pad.distance-pad.length/2-2
		race.lane = pad.lane
		race.speed = race.vehicle.max_speed
		var fuel: float = race.nitro
		var charges: int = race.nitro_charges
		race.step(0.08,0,false,false,false)
		check(race.pad_active and race.speed > race.vehicle.max_speed+6,"Every car must receive a pad boost without holding gas")
		check(race.nitro >= fuel and race.nitro_charges == charges,"Pads must not spend the vehicle's own nitro")
		race.step(0.05,0,false,true,true)
		check(not race.pad_active and not race.boosting,"The brake must override automatic acceleration")
		isolate(race)
		race.distance = water.distance-water.length/2-2
		race.lane = water.lane
		race.speed = 55
		race.step(0.08,0,false,true,false)
		check(race.surface.puddles_hit == 1 and race.surface.wet_time > 0,"Player tire sweeps must actually activate the puddle")
	# Wet tires must retain lateral momentum when the driver unwinds the wheel.
	isolate(race)
	race.distance = 80
	race.speed = 50
	race.lane_velocity = 4
	race.step(0.05,0,false,true,false)
	var dry_velocity: float = absf(race.lane_velocity)
	isolate(race)
	race.distance = 80
	race.speed = 50
	race.lane_velocity = 4
	race.surface.wet_time = State.WET_DURATION
	race.step(0.05,0,false,true,false)
	check(absf(race.lane_velocity) > dry_velocity+0.5,"Wet tires must actually retain more lateral momentum")
	isolate(race)
	race.speed = 112
	var rival: Dictionary = race.rivals[0]
	rival.speed = 120.0
	rival.pace = 120.0
	rival.distance = race.distance-3
	rival.lane = race.lane
	race.resolve_contact(rival,{"normal":Vector2(0,1),"depth":0.2})
	check(race.speed >= 112,"Being hit from behind must not clamp a fast car to an obsolete cruise limit")
	for emitter in race.water_effect.pool: check(not emitter.emitting,"Ordinary driving must not emit water particles")
	race.choose_mode("track",1)
	section = race.track.active
	pad = section.features[0]
	point = Vector2(pad.lane,pad.distance)
	state.reset()
	state.contact(section,point,point,80)
	point.y += section.length
	state.contact(section,point,point,80)
	check(state.boosts_hit == 2,"The circuit pad must re-arm once on each new lap")
	isolate(race)
	rival = race.rivals[0]
	rival.active = true
	rival.distance = pad.distance-pad.length/2-2
	rival.lane = pad.lane
	rival.target_lane = pad.lane
	rival.decision = 1.0
	rival.speed = 35.0
	rival.pace = 70.0
	race.distance = 80
	race.brain.tick(race,0.1)
	check(rival.surface.boosts_hit == 1,"CPU cars must use the same physical pads")
	print("Road surface checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await tree.process_frame
	return failures
