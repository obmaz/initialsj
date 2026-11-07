extends RefCounted
const Report = preload("res://tests/report.gd")
const Contact = preload("res://scripts/car_contact.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var rows := []
	for choice in [["tour",0],["track",0]]:
		race.choose_mode(choice[0],choice[1])
		var section: Node3D = race.track.active
		var rail: MeshInstance3D = section.get_node("ContinuousGuardrails")
		check(rail.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() > 3000,"Guardrails must be indexed continuous curved ribbons")
		var widest := 0.0
		var at := 0.0
		var minimum_radius_margin := INF
		for i in range(1000):
			var d: float = section.length*i/1000
			var outer: float = maxf(section.rail_setback(d,-1),section.rail_setback(d,1))
			if section.rail_setback(d,1) > widest: widest = section.rail_setback(d,1); at = d
			var bend: float = absf(wrapf(section.heading(d+1)-section.heading(d-1),-PI,PI))/2
			if bend > 0.0001: minimum_radius_margin = minf(minimum_radius_margin,1/bend-section.half_width(d)-outer)
			var limits: Vector2 = race.track.lane_limits(d)
			if choice[0] == "track" or d > 180:
				check(absf(limits.y+Contact.HALF_WIDTH+0.2-section.half_width(d)-section.rail_setback(d,1)) < 0.01,"Driving bounds must match the real rail offset")
		check(minimum_radius_margin > 0.5,"Inner guardrails must not fold across themselves on sharp corners")
		check(widest > 6,"Tour and Fuji must have visibly wider roadside runoff areas")
		if choice[0] == "track":
			check(section.has_node("FujiWorldCollision"),"Fuji shoulders and barriers must participate in the real collision world")
			rows.append({"mode":choice[0],"course":choice[1],"maximum_setback_m":widest,"minimum_inner_radius_margin_m":minimum_radius_margin,"controller":"world-space"})
			continue
		# Surface gimmicks (mud, trucks) would pollute the asphalt/dirt speed comparison.
		section.features = [] as Array[Dictionary]
		for index in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
			race.open_garage()
			race.select_vehicle(index)
			race.restart()
			race.state = "racing"
			for r in race.rivals: r.active = false
			race.distance = at
			race.speed = 65
			for frame in range(120): race.step(1.0/60,0,false,true,false)
			var asphalt: float = race.speed
			race.restart()
			race.state = "racing"
			for r in race.rivals: r.active = false
			race.distance = at
			race.lane = section.half_width(at)+2.2
			race.speed = 65
			for frame in range(120):
				# Counter only the road's normal centrifugal force, preserving a fixed shoulder lane.
				var curve: float = race.track.curvature(race.distance)
				var demand: float = absf(curve)*race.speed*race.speed
				var grip: float = race.vehicle.grip*lerpf(1,0.72,race.offroad_amount)
				var excess := maxf(0,demand-grip)
				var authority := clampf(1-excess/(grip*2),0.38,1)
				var axis: float = clampf(-signf(curve)*(demand*0.055+excess*1.6)/(race.vehicle.steer_speed*authority),-1,1)
				race.step(1.0/60,axis,false,true,false)
			check(race.wall_hits == 0 and race.offroad_amount > 0.6,"Entering dirt must slow the car without a guardrail collision")
			check(race.speed < asphalt*0.78,"Dirt runoff must be materially slower than asphalt for every vehicle")
			var dirt: float = race.speed
			race.lane = 0
			for frame in range(120): race.step(1.0/60,0,false,true,false)
			check(race.offroad_amount < 0.01 and race.speed > dirt+15,"Returning to asphalt must restore acceleration")
			rows.append({"mode":choice[0],"course":choice[1],"car":index,"asphalt_kmh":asphalt*3.6,"dirt_kmh":dirt*3.6,"walls":race.wall_hits})
		race.distance = at
		race.lane = race.track.lane_limits(at).y+0.6
		race.speed = 50
		race.wall_hits = 0
		race.step(1.0/60,0,false,true,false)
		check(race.wall_hits == 1 and race.impact > 0,"The outer guardrail must still register a real collision")
		rows.append({"mode":choice[0],"course":choice[1],"maximum_setback_m":widest,"minimum_inner_radius_margin_m":minimum_radius_margin})
	FileAccess.open(Report.path("shoulder-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures},"\t")+"\n")
	print("Curved guardrails / wider dirt shoulders / matching collisions: ","PASS" if failures == 0 else "FAIL")
	race.queue_free()
	await tree.process_frame
	return failures
