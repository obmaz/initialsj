extends RefCounted
# Tour game-feel devices: mud, parked trucks, steep drops, sudden narrowing and tall jumps.
const Features = preload("res://scripts/road_features.gd")
const State = preload("res://scripts/road_surface_state.gd")
const Section = preload("res://scripts/road_section.gd")
const Air = preload("res://scripts/air_state.gd")
const Library = preload("res://scripts/route_library.gd")
const Crash = preload("res://scripts/crash_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func first_of(section: Node3D, kind: String) -> Dictionary:
	for f in section.features:
		if f.kind == kind: return f
	return {}

func run(tree: SceneTree) -> int:
	check(Library.CHECKPOINT_RUNUP <= 220.0,"The straight between the checkpoint and the fork must be short")
	check(Crash.launch_up(100.0) >= 18.0 and Crash.launch_up(100.0) <= 20.0 and Crash.launch_up(100.0) > Crash.launch_up(60.0)*1.3,"Faster rail hits must throw the car much higher")
	var tall_total := 0
	for stage in range(5):
		for node in range(stage+1):
			var section := Section.new(Vector3(0,6,0),-PI/2,stage,node)
			var label := "S%d N%d" % [stage,node]
			var features: Array[Dictionary] = Features.layout(section)
			section.features = features
			var steep: Array[float] = section.steep_starts()
			check(steep.size() >= 1,"%s needs a steep climb and drop" % label)
			for start in steep:
				var up := 0.0
				var down := 0.0
				for i in range(int(start),int(start)+200,4):
					var grade: float = (section.point(i+4).y-section.point(i).y)/4
					up = maxf(up,grade)
					down = minf(down,grade)
				check(up > 0.06 and down < -0.16,"%s steep stretch must climb hard and drop harder (%.2f / %.2f)" % [label,up,down])
			var crests: Array = features.filter(func(f): return f.kind == "crest")
			check(crests.size() == steep.size(),"%s needs a crest launch for every steep drop" % label)
			for span in section.pinch_spans():
				var inside: float = section.half_width((span.x+span.y)*0.5)
				var before: float = section.half_width(span.x-120)
				check(inside < 5.2 and before >= inside-0.01,"%s must narrow clearly inside a pinch (%.1f vs %.1f)" % [label,inside,before])
			check(features.filter(func(f): return f.kind == "mud").size() >= 3,"%s needs mud beside its pad pairs" % label)
			var trucks: Array = features.filter(func(f): return f.kind == "truck")
			check(trucks.size() >= 1,"%s needs a parked truck" % label)
			for truck in trucks:
				check(absf(truck.lane)+float(truck.width)*0.5 < section.half_width(truck.distance)-0.5 and section.half_width(truck.distance)+absf(truck.lane)-float(truck.width)*0.5 > 6.0,"%s truck must sit on the road and leave an open lane" % label)
				check(Features.hazard_ahead(section,truck.distance-80) != "","%s must warn about the truck ahead" % label)
			tall_total += features.filter(func(f): return f.kind == "ramp" and f.get("big",false)).size()
			section.free()
	check(tall_total >= 6,"Most later Tour routes need a tall jump (found %d)" % tall_total)
	# Region character: skyways over parked trucks, truck gates and the Jeju stone guardians.
	var Regional = load("res://scripts/regional_props_3d.gd")
	check(Regional.FAMILIES.jeju.has("hareubang") and Regional.model("hareubang").get_aabb().size.y > 3.0,"Jeju roadsides need stone guardians tall enough to read from the road")
	check(Regional.model("dol_wall").get_faces().size() > 0 and Regional.model("tangerine").get_faces().size() > 0,"Jeju walls and tangerine trees must build")
	var skyway_routes := 0
	var gate_routes := 0
	for stage in range(5):
		for node in range(stage+1):
			var route := Section.new(Vector3(0,6,0),-PI/2,stage,node)
			var layout: Array[Dictionary] = Features.layout(route)
			var theme: String = Library.theme(stage,node)
			var wants: Dictionary = Features.THEME_FEEL.get(theme,{})
			check(wants.has("label"),"%s needs a named driving style" % theme)
			for deck in layout.filter(func(f): return f.kind == "skyway"):
				skyway_routes += 1
				var below: Array = layout.filter(func(f): return f.kind == "truck" and absf(f.lane-deck.lane) < 1.0 and absf(f.distance-deck.distance) < deck.length*0.5-Features.SKYWAY_RAMP)
				check(below.size() >= 2,"%s skyway must pass over parked trucks" % theme)
			var trucks: Array = layout.filter(func(f): return f.kind == "truck")
			for a_truck in trucks:
				for b_truck in trucks:
					if a_truck.distance == b_truck.distance and a_truck.lane < 0 and b_truck.lane > 0:
						gate_routes += 1
						var gap: float = (b_truck.lane-b_truck.width*0.5)-(a_truck.lane+a_truck.width*0.5)
						check(gap > 3.3 and gap < 4.5,"%s truck gate must leave a car-and-a-half gap (%.1f m)" % [theme,gap])
			route.free()
	check(skyway_routes >= 3 and gate_routes >= 4,"Several routes need skyways (%d) and truck gates (%d)" % [skyway_routes,gate_routes])
	# Driving the skyway: up the ramp onto the deck, a car under the deck stays on the road,
	# and steering off the deck drops the car back onto the road.
	var city := Section.new(Vector3(0,6,0),-PI/2,1,1)
	city.features = Features.layout(city)
	var deck: Dictionary = first_of(city,"skyway")
	check(not deck.is_empty(),"The city route needs a skyway")
	if not deck.is_empty():
		var air := Air.new()
		var d: float = deck.distance-deck.length*0.5-10
		var peak := 0.0
		while d < deck.distance:
			air.advance(city,Vector2(deck.lane,d),Vector2(deck.lane,d+1),40,1.0/40)
			d += 1
			peak = maxf(peak,air.height)
		check(peak > Features.SKYWAY_HEIGHT-0.2 and not air.active,"Driving up the ramp must carry the car onto the deck")
		var events: Array = air.advance(city,Vector2(deck.lane,d),Vector2(deck.lane+4.0,d+1),40,1.0/40)
		check(events.has("drop") and air.active,"Steering off the deck must drop the car")
		var landed := false
		for frame in range(120):
			d += 1
			if air.advance(city,Vector2(deck.lane+4.0,d),Vector2(deck.lane+4.0,d+1),40,1.0/40).has("settle"): landed = true; break
		check(landed and air.height < 0.01,"The dropped car must land on the road below")
		var under := Air.new()
		under.advance(city,Vector2(deck.lane+5,deck.distance-1),Vector2(deck.lane,deck.distance),40,1.0/40)
		check(under.height < 0.01 and under.skyway == "","A car driving under the deck must stay on the road")
	city.free()
	# A tall ramp throws the car higher than an ordinary one at the same speed.
	var section := Section.new(Vector3(0,6,0),-PI/2,2,1)
	var ordinary := {"kind":"ramp","id":"o","distance":300.0,"lane":0.0,"length":18.0,"width":3.8,"height":0.9}
	var tall := {"kind":"ramp","id":"t","distance":300.0,"lane":0.0,"length":26.0,"width":4.6,"height":2.8,"big":true}
	check(Air.launch_velocity(section,tall,310.0,0.0,80.0) > Air.launch_velocity(section,ordinary,309.0,0.0,80.0)+3.0,"A tall jump must launch much higher")
	section.free()
	# Mud slows the car inside the patch and for a moment after, once per entry.
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("tour")
	await tree.physics_frame
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	var active: Node3D = race.track.active
	var mud := first_of(active,"mud")
	var state := State.new()
	var point := Vector2(mud.lane,mud.distance)
	check(state.contact(active,point-Vector2(0,20),point+Vector2(0,20),60).has("mud") and state.mud_time > 0,"Crossing mud must report a mud event")
	check(not state.contact(active,point,point,60).has("mud"),"Waiting in mud must not repeat its entry event")
	preload("res://tests/tour_world_checks.gd").new().set_car(race,mud.distance-8,mud.lane,60)
	for frame in range(40): race.step(1.0/60,0,false,true,false)
	check(race.speed < 50,"A car driving through mud must lose clear speed (%.1f)" % race.speed)
	# A parked truck is a wall: heavy speed loss and a push to the open side.
	var truck := first_of(active,"truck")
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	preload("res://tests/tour_world_checks.gd").new().set_car(race,truck.distance-14,truck.lane,55)
	race.bump_cooldown = 0
	for frame in range(20): race.step(1.0/60,0,false,true,false)
	check(race.speed < 38 and race.traffic_hits >= 1,"Hitting a parked truck must cost most of the speed (%.1f)" % race.speed)
	check(not race.world_race.player_body.last_contacts.is_empty() or race.crash.active,"주차 트럭은 실제 차체 접촉이나 충돌 비행을 일으켜야 한다")
	race.queue_free()
	await tree.process_frame
	print("Tour mud / trucks / steep drops / narrow roads / tall jumps / short fork approach: ","PASS" if failures == 0 else "FAIL")
	return failures
