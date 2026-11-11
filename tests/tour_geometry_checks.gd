extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
const Features = preload("res://scripts/track/road_features.gd")
const Air = preload("res://tests/flight_envelope_model.gd")
const Library = preload("res://scripts/track/route_library.gd")
const Report = preload("res://tests/report.gd")
var failures := 0
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(message)
func run(_tree: SceneTree) -> int:
	var rows: Array[Dictionary] = []
	for stage in range(5):
		for node in range(stage+1):
			var origin := Vector3(20,11,-30)
			var section := Section.new(origin,-0.4,stage,node)
			section.features = Features.layout(section)
			var low := INF
			var high := -INF
			var grade := 0.0
			var crests := 0
			var before := 0.0
			for i in range(1200):
				var d: float = section.length*i/1200
				var y: float = section.point(d).y
				var rise: float = (section.point(d+3).y-section.point(d-3).y)/6
				low = minf(low,y)
				high = maxf(high,y)
				grade = maxf(grade,absf(rise))
				if before > 0 and rise <= 0 and y > origin.y+10: crests += 1
				before = rise
			check(high-low >= 34.9 and high-low <= 85.0,"Every Tour theme must have substantial bounded ridge elevation")
			check(crests >= 2,"Tour roads must climb and descend two separate ridges")
			check(grade > 0.04 and grade < 0.42,"Tour grades must stay below the steepest drop")
			for d in [0.0,80.0,160.0,section.checkpoint_distance()-50,section.length-80,section.length]:
				check(absf(section.point(d).y-origin.y) < 0.001,"Section entries and checkpoint approaches must remain level at their original junction height")
			if stage < 4:
				for side in [-1,1]:
					var next := Section.new(section.point(section.length),section.heading(section.length),stage+1,node+(1 if side > 0 else 0),side)
					for lane in [-6.0,0.0,6.0]:
						check(section.point(section.length,lane).distance_to(next.point(0,lane)) < 0.02,"Both bank-free Tour branches must meet the previous road without a height or lane seam")
					next.free()
			var tunnel := Library.tunnel_span(stage,node)
			var ramps: Array = section.features.filter(func(f): return f.kind == "ramp")
			for patch in section.features:
				if patch.kind == "water" and tunnel.y > tunnel.x:
					check(patch.distance+patch.length*0.5 < tunnel.x-40 or patch.distance-patch.length*0.5 > tunnel.y+40,"Puddles must not surprise the driver inside a tunnel or at its portal")
				for ramp in ramps:
					if patch == ramp or patch.kind == "boost" and (absf(patch.distance-ramp.distance+62) < 0.01 or absf(patch.distance-ramp.distance+78) < 0.01): continue
					check(patch.distance+patch.length*0.5 < ramp.distance-65 or patch.distance-patch.length*0.5 > ramp.distance+(200 if ramp.get("big",false) else 140),"Every jump needs an unobstructed landing corridor")
			var longest_jump := 0.0
			for ramp in ramps:
				if tunnel.y > tunnel.x:
					check(ramp.distance+180 < tunnel.x-40 or ramp.distance-120 > tunnel.y+80,"A ramp flight must clear both tunnel portals")
				for speed in [65.0,110.0]:
					var air := Air.new()
					var d: float = ramp.distance-ramp.length
					var launched := false
					var landed := false
					var peak := 0.0
					for frame in range(240):
						var events: Array = air.advance(section,Vector2(ramp.lane,d),Vector2(ramp.lane,d+speed/60),speed,1.0/60)
						d += speed/60
						launched = launched or events.has("launch")
						peak = maxf(peak,air.height)
						if events.has("land"): landed = true; break
					check(launched and landed and peak > 0.9 and peak < (8.0 if ramp.get("big",false) else 4.0),"Every Tour ramp must produce a visible short jump and land at both normal and boosted speed")
					var flight: float = d-ramp.distance-ramp.length*0.5
					longest_jump = maxf(longest_jump,flight)
					check(flight < (190 if ramp.get("big",false) else 140),"Boosted ramp landings must fit entirely inside the reserved clear road")
			rows.append({"stage":stage,"node":node,"theme":Library.theme(stage,node),"length_m":section.length,"elevation_m":high-low,"maximum_grade":grade,"crests":crests,"features":section.features.size(),"ramps":ramps.size(),"longest_landing_m":longest_jump})
			section.free()
	FileAccess.open(Report.path("tour-geometry-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"routes":rows},"\t")+"\n")
	print("Tour two-ridge geometry / junctions / gimmick spacing / all-route jump landings: ","PASS" if failures == 0 else "FAIL")
	return failures
