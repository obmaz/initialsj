extends RefCounted
const PAD_SHADER = preload("res://shaders/boost_pad.gdshader")
const WATER_SHADER = preload("res://shaders/road_puddle.gdshader")
const Library = preload("res://scripts/route_library.gd")

# Each region leans on different devices so every route has its own feel. Extra counts are added
# to the shared base layout; a device that does not fit is simply left out.
#   jumps: extra ramps, chains: extra pad pairs, lane: a boost lane, water / mud: extra patches,
#   trucks: extra single trucks, gates: pairs of trucks to thread between, skyway: a narrow
#   elevated deck over parked trucks that drops you back onto the road if you steer off it.
const THEME_FEEL := {
	"hawaii":{"label":"COAST CRUISE"},
	"desert":{"label":"DUNE JUMPS","jumps":2},
	"city":{"label":"SKYWAY CITY","skyway":1,"gates":1,"lane":1},
	"pyramid":{"label":"DESERT JUMPS","jumps":2,"gates":1},
	"amusement":{"label":"BOOST PARK","chains":2,"lane":1},
	"jeju":{"label":"STONE AND MUD","water":2,"mud":2},
	"ruins":{"label":"BROKEN ROAD","jumps":1,"mud":2},
	"seoul":{"label":"EXPRESSWAY","skyway":1,"gates":1,"trucks":1},
	"fuji":{"label":"PAD RUN","chains":2,"lane":1},
	"neon":{"label":"NEON BOOST","chains":2,"lane":1,"skyway":1},
	"canyon":{"label":"CANYON JUMPS","jumps":2},
	"harbor":{"label":"CONTAINER YARD","gates":2,"trucks":2,"skyway":1},
	"bamboo":{"label":"MUDDY PASS","mud":2,"water":1},
	"snow":{"label":"ICE ROAD","water":3},
	"volcano":{"label":"LAVA JUMPS","jumps":2,"gates":1}
}
const SKYWAY_LENGTH := 240.0
const SKYWAY_RAMP := 50.0
const SKYWAY_HEIGHT := 6.0

static func feel(section: Node3D) -> Dictionary:
	return THEME_FEEL.get(Library.theme(section.stage,section.route_node),{})

static func tour_slot(section: Node3D, desired: float, extent: float, kind: String, occupied: Array[Vector2], ahead: float = 0.0) -> float:
	var first := 320+extent*0.5+(110 if kind == "ramp" else 0)
	var last: float = section.length-Library.CHECKPOINT_RUNUP-100-extent*0.5-(160 if kind == "ramp" else 0)
	var tunnel := Library.tunnel_span(section.stage,section.route_node)
	var best := INF
	var chosen := -1.0
	var count := maxi(1,ceili((last-first)/10))
	for i in range(count+1):
		var d := lerpf(first,last,float(i)/count)
		var bounds := Vector2(d-extent*0.5-20,d+extent*0.5+20+ahead)
		var blocked := false
		for span in occupied:
			if bounds.x < span.y and bounds.y > span.x: blocked = true; break
		if blocked: continue
		if tunnel.y > tunnel.x:
			var gap := Vector2(d-120,d+180) if kind == "ramp" else Vector2(bounds.x-40,bounds.y+40)
			if kind in ["ramp","water","truck","skyway"] and gap.x < tunnel.y+80 and gap.y > tunnel.x-40: continue
		var grade: float = (section.point(d+4).y-section.point(d-4).y)/8
		if kind == "ramp" and absf(grade) > 0.045: continue
		var score: float = absf(d-desired)+absf(section.curvature(d))*(18000 if kind == "ramp" else 9000)
		if kind == "ramp": score += absf(grade)*1000
		if score < best: best = score; chosen = d
	return chosen

static func tour_patch(section: Node3D, kind: String, d: float, fraction: float, extent: float, width: float, height: float = 0.0) -> Dictionary:
	var patch := {"kind":kind,"distance":d,"lane":fraction*section.half_width(d),"length":extent,"width":width}
	if kind == "ramp": patch["height"] = height
	if kind == "boost" and extent <= 12: patch["duration"] = 0.52
	return patch

static func tour_layout(section: Node3D) -> Array[Dictionary]:
	var side := -1.0 if (section.stage+section.route_node)%2 == 0 else 1.0
	var occupied: Array[Vector2] = []
	var crests: Array[Dictionary] = []
	var muds: Array[Dictionary] = []
	var trucks: Array[Dictionary] = []
	# Steep climbs and sudden narrowings keep their own stretch of road.
	for start in section.steep_starts():
		occupied.append(Vector2(start-40,start+160))
		var crest := tour_patch(section,"crest",start+90,0.0,8,60.0)
		crests.append(crest)
	for span in section.pinch_spans(): occupied.append(Vector2(span.x-50,span.y+40))
	var ramps: Array[Dictionary] = []
	var water: Array[Dictionary] = []
	var pads: Array[Dictionary] = []
	var lanes: Array[Dictionary] = []
	var tunnel := Library.tunnel_span(section.stage,section.route_node)
	if section.stage >= 1:
		# One tall jump with its own run-up pad: it launches much higher and needs speed.
		var desired_big: float = 180+(section.length-Library.CHECKPOINT_RUNUP-260)*0.52
		# The slot is searched with the whole run-up and landing corridor so nothing else lands in it.
		var big_d := tour_slot(section,desired_big,150,"ramp",occupied,100.0)
		if big_d >= 520:
			var big_fraction := -side*0.18
			var big := tour_patch(section,"ramp",big_d,big_fraction,26,4.6,2.6+section.stage*0.15)
			big["big"] = true
			ramps.append(big)
			pads.append(tour_patch(section,"boost",big_d-78,big_fraction,20,3.4))
			occupied.append(Vector2(big_d-110,big_d+200))
	var profile := feel(section)
	var skyways: Array[Dictionary] = []
	if int(profile.get("skyway",0)) > 0:
		var sky_d := tour_slot(section,section.length*0.62,SKYWAY_LENGTH+40,"skyway",occupied)
		if sky_d >= 0:
			var sky_fraction := side*0.5
			var deck := tour_patch(section,"skyway",sky_d,sky_fraction,SKYWAY_LENGTH,4.4)
			deck["height"] = SKYWAY_HEIGHT
			skyways.append(deck)
			# Parked trucks block the lane underneath: drive over them on the deck or go round.
			for offset in [-45.0,45.0]:
				trucks.append(tour_patch(section,"truck",sky_d+offset,sky_fraction,12.5,2.8))
			occupied.append(Vector2(sky_d-SKYWAY_LENGTH*0.5-60,sky_d+SKYWAY_LENGTH*0.5+60))
	var ramp_count := (2 if section.stage >= 2 and (section.stage+section.route_node)%2 == 0 and tunnel.y-tunnel.x < 700 else 1)+int(profile.get("jumps",0))
	for i in range(ramp_count):
		var desired: float = 180+(section.length-Library.CHECKPOINT_RUNUP-260)*[0.27,0.68,0.45,0.85,0.12][i%5]
		var d := tour_slot(section,desired,100,"ramp",occupied,120.0)
		if d < 0: d = tour_slot(section,desired,70,"ramp",occupied,120.0)
		# The tight last resort only keeps a first jump on crowded early routes.
		if d < 0 and i == 0: d = tour_slot(section,desired,18,"ramp",occupied,40.0)
		if d < 0: continue
		var fraction: float = side*(0.46 if i%2 == 0 else -0.46)
		ramps.append(tour_patch(section,"ramp",d,fraction,18,3.8,0.8+section.stage*0.05))
		# The lead-in is deliberate; the launch and landing corridor stays free
		# of every other surface gimmick, including opposite-side puddles.
		pads.append(tour_patch(section,"boost",d-62,fraction,20,3.4))
		occupied.append(Vector2(d-85,d+160))
	if (section.stage+section.route_node)%2 == 1 or int(profile.get("lane",0)) > 0:
		var d := tour_slot(section,section.length*0.58,180,"boost_lane",occupied)
		if d >= 0:
			lanes.append(tour_patch(section,"boost_lane",d,-side*0.42,180,3.4))
			occupied.append(Vector2(d-110,d+110))
	for i in range(2+int(profile.get("water",0))):
		var d := tour_slot(section,section.length*[0.46,0.80,0.30,0.62,0.90][i%5],18,"water",occupied)
		if d < 0: continue
		water.append(tour_patch(section,"water",d,-side*(0.44 if i%2 == 0 else -0.44),18,4.0))
		occupied.append(Vector2(d-40,d+40))
	var chains: Array[Dictionary] = []
	for group in range(3+int(profile.get("chains",0))):
		var desired: float = [450+section.stage*20+section.route_node*12,section.length*0.39,section.length*0.69,section.length*0.53,section.length*0.82][group%5]
		var middle := tour_slot(section,desired,112,"boost",occupied)
		if middle < 0: continue
		for i in range(2):
			var d := middle-50+i*100
			var fraction: float = side*(0.46 if (group+i)%2 == 0 else -0.46)
			chains.append(tour_patch(section,"boost",d,fraction,12,3.0))
			# Mud beside the pad: the free lane costs speed, the pad lane pays it back.
			if i == 0: muds.append(tour_patch(section,"mud",d,-fraction,14,3.6))
		occupied.append(Vector2(middle-76,middle+76))
	# Truck gates: two trucks side by side with a car-and-a-half gap to thread through.
	for i in range(int(profile.get("gates",0))):
		var gate_d := tour_slot(section,section.length*[0.47,0.74][i%2],14,"truck",occupied)
		if gate_d < 0: continue
		var gap_lane := 3.2
		for lane_side in [-1.0,1.0]:
			trucks.append(tour_patch(section,"truck",gate_d,lane_side*gap_lane/section.half_width(gate_d),12.5,2.8))
		occupied.append(Vector2(gate_d-50,gate_d+50))
	for i in range(int(profile.get("mud",0))):
		var mud_d := tour_slot(section,section.length*[0.35,0.66][i%2],16,"mud",occupied)
		if mud_d < 0: continue
		muds.append(tour_patch(section,"mud",mud_d,(0.3 if i%2 == 0 else -0.3),16,4.4))
		occupied.append(Vector2(mud_d-40,mud_d+40))
	# Long parked trucks take up one side of the road.
	var truck_count := 1+(1 if section.stage >= 2 else 0)+(1 if section.stage >= 4 else 0)+int(profile.get("trucks",0))
	for i in range(truck_count):
		var truck_d := tour_slot(section,section.length*[0.31,0.55,0.83,0.42,0.68][i%5],14,"truck",occupied)
		if truck_d < 0: continue
		trucks.append(tour_patch(section,"truck",truck_d,(0.5 if (i+section.stage)%2 == 0 else -0.5),12.5,2.8))
		occupied.append(Vector2(truck_d-50,truck_d+50))
	# Keep the introductory pad and puddle first for surface previews. IDs are
	# unique per section and do not change when another route is instantiated.
	var out: Array[Dictionary] = []
	if not chains.is_empty(): out.append(chains.pop_front())
	if not water.is_empty(): out.append(water.pop_front())
	out.append_array(chains)
	out.append_array(pads)
	out.append_array(water)
	out.append_array(ramps)
	out.append_array(lanes)
	out.append_array(muds)
	out.append_array(trucks)
	out.append_array(crests)
	out.append_array(skyways)
	for i in range(out.size()): out[i]["id"] = "%d:%d:%d" % [section.stage,section.route_node,i]
	return out

static func gentle_distance(section: Node3D, desired: float) -> float:
	var best := INF
	var chosen := desired
	for offset in range(-120,121,20):
		var d := clampf(desired+offset,300,section.length-280)
		var score: float = absf(section.curvature(d))*10000+absf(offset)*0.005
		if score < best: best = score; chosen = d
	return chosen

static func layout(section: Node3D) -> Array[Dictionary]:
	if not section.closed_loop: return tour_layout(section)
	var out: Array[Dictionary] = []
	var side := -1.0 if (section.stage+section.route_node)%2 == 0 else 1.0
	var specifications := [
		["boost",gentle_distance(section,440+section.stage*35+section.route_node*13),side*0.24,22.0,3.4],
		["water",section.length*0.47,-side*0.43,16.0,4.4]
	]
	var ramp_d := gentle_distance(section,section.length*0.33) if section.course_id == 1 else 220.0
	specifications.append(["ramp",ramp_d,side*0.5,16.0,3.8])
	# MIDNIGHT HARBOR places everything by hand (below): the generic spots fall inside its hairpins.
	if section.course_id in [2,3]: specifications.clear()
	if section.closed_loop and section.course_id == 0:
		# Fuji: launch-straight, cutting approach, viaduct and return-road boosts.
		# The paired pads leave enough run-up before each optional jump and an
		# unobstructed lane beside it. The cutting jump lands before the tunnel.
		specifications.append_array([
			["boost",150.0,-0.50,24.0,4.2],
			["boost",2420.0,-0.34,26.0,4.2],
			["ramp",2460.0,-0.34,20.0,4.6,1.35],
			["boost",3950.0,0.36,26.0,4.2],
			["ramp",4030.0,0.36,22.0,4.6,1.55],
			["boost",4850.0,-0.42,26.0,4.2]
		])
	if section.closed_loop and section.course_id == 2:
		# MIDNIGHT HARBOR: a pad on each hairpin exit pays for a clean slide, a short jump and a
		# boost lane on the long back straight, one puddle where the road is straight but slippery.
		specifications.append_array([
			["boost",170.0,-0.30,22.0,3.4],
			["boost",870.0,-0.30,20.0,3.4],
			["water",930.0,0.25,16.0,4.0],
			["boost",1330.0,-0.35,24.0,3.6],
			["ramp",1420.0,-0.35,18.0,3.8,0.9],
			["boost_lane",1580.0,0.40,200.0,3.8],
			["boost",2135.0,0.30,20.0,3.4],
			["boost",2355.0,-0.30,20.0,3.4],
			["boost",2670.0,0.0,24.0,3.6]
		])
	if section.closed_loop and section.course_id == 1:
		# Two readable slaloms: a neutral line misses the alternating pads.
		for start in [560.0,2490.0]:
			for index in range(6):
				specifications.append(["boost",start+index*78.0,-0.40 if index%2 == 0 else 0.40,12.0,3.0])
		specifications.append(["boost_lane",1050.0,0.42,240.0,4.4])
		specifications.append(["boost_lane",2070.0,-0.42,280.0,4.4])
	for i in range(specifications.size()):
		var spec: Array = specifications[i]
		var d: float = spec[1]
		out.append({"id":"%d:%d:%d" % [section.stage,section.route_node,i],"kind":spec[0],"distance":d,"lane":float(spec[2])*section.half_width(d),"length":spec[3],"width":spec[4]})
		if spec[0] == "ramp": out[-1]["height"] = float(spec[5]) if spec.size() > 5 else 0.75
		if section.closed_loop and section.course_id == 1 and spec[0] == "boost" and float(spec[3]) <= 12: out[-1]["duration"] = 0.48
	return out

static func lane_cost(section: Node3D, distance: float, lane: float) -> float:
	var cost := 0.0
	for feature in section.features:
		if feature.kind in ["crest","skyway"]: continue
		var gap: float = feature.distance-distance
		if section.closed_loop: gap = fposmod(gap,section.length)
		if gap < 0 or gap > 110: continue
		if absf(lane-float(feature.lane)) < float(feature.width)*0.5+1.0:
			cost += (40.0 if feature.kind == "truck" else (14.0 if feature.kind in ["water","mud"] else -3.5))*(1-gap/120)
	return cost

static func swept_hit(feature: Dictionary, from: Vector2, to: Vector2, center_distance: float) -> bool:
	# Road-space sweep against the patch expanded by the tire footprint.
	var half := Vector2(float(feature.width)*0.5+1.0,float(feature.length)*0.5+1.7)
	var a := from-Vector2(feature.lane,center_distance)
	var delta := to-from
	if feature.kind in ["water","mud"]:
		var start := a/half
		var move := delta/half
		var t := clampf(-start.dot(move)/maxf(move.length_squared(),0.000001),0,1)
		return (start+move*t).length_squared() <= 1
	var enter := 0.0
	var exit := 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.000001:
			if absf(a[axis]) > half[axis]: return false
		else:
			var first := (-half[axis]-a[axis])/delta[axis]
			var last := (half[axis]-a[axis])/delta[axis]
			enter = maxf(enter,minf(first,last))
			exit = minf(exit,maxf(first,last))
			if enter > exit: return false
	return true

static func build(section: Node3D) -> void:
	for feature in section.features:
		if feature.kind == "ramp":
			build_ramp(section,feature)
			continue
		if feature.kind == "truck":
			build_truck(section,feature)
			continue
		if feature.kind == "crest": continue
		if feature.kind == "skyway":
			build_skyway(section,feature)
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		if feature.kind in ["boost","boost_lane"]:
			var segments := maxi(10,ceili(float(feature.length)/3))
			for i in range(segments):
				var a: float = feature.distance-feature.length*0.5+feature.length*i/segments
				var b: float = feature.distance-feature.length*0.5+feature.length*(i+1)/segments
				var lanes := [feature.lane-feature.width*0.5,feature.lane+feature.width*0.5]
				var points := [section.point(a,lanes[0]),section.point(a,lanes[1]),section.point(b,lanes[0]),section.point(b,lanes[1])]
				var uv := [Vector2(0,float(i)/segments),Vector2(1,float(i)/segments),Vector2(0,float(i+1)/segments),Vector2(1,float(i+1)/segments)]
				for index in [0,2,1,1,2,3]: add_vertex(surface,points[index],uv[index])
		else:
			var center: Vector3 = section.point(feature.distance,feature.lane)
			for i in range(40):
				add_vertex(surface,center,Vector2(0.5,0.5))
				for j in [i+1,i]:
					var angle: float = TAU*j/40.0
					var radius := 1+0.06*sin(angle*5)+0.03*cos(angle*9)
					var p: Vector3 = section.point(feature.distance+cos(angle)*feature.length*0.5*radius,feature.lane+sin(angle)*feature.width*0.5*radius)
					add_vertex(surface,p,Vector2(0.5+sin(angle)*0.5,0.5+cos(angle)*0.5))
		var node := MeshInstance3D.new()
		node.name = "BoostLane" if feature.kind == "boost_lane" else ("BoostPad" if feature.kind == "boost" else ("MudPatch" if feature.kind == "mud" else "RoadPuddle"))
		node.mesh = surface.commit()
		if feature.kind == "mud":
			var mud := StandardMaterial3D.new()
			mud.albedo_color = Color("7a5430")
			mud.roughness = 0.96
			node.material_override = mud
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			section.add_child(node)
			continue
		var material := ShaderMaterial.new()
		material.shader = PAD_SHADER if feature.kind in ["boost","boost_lane"] else WATER_SHADER
		if feature.kind == "boost_lane":
			material.set_shader_parameter("lane_mode",true)
			material.set_shader_parameter("arrow_count",feature.length/9.0)
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		section.add_child(node)

# Jump ramps must read at a glance, day or night: the deck alternates orange and cream bands, the
# side walls are cream, the lip is a bright cream band, and dark chevrons point up the slope. Vertex
# colours keep it one mesh, which is also what the world collider is built from.
const RAMP_ORANGE := Color("ff7a1a")
const RAMP_CREAM := Color("f6f0dc")
const RAMP_CHEVRON := Color("1a222b")

static func build_ramp(section: Node3D, feature: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: float = feature.distance-feature.length*0.5
	var bands := 8
	for segment in range(bands):
		var a: float = start+feature.length*segment/float(bands)
		var b: float = start+feature.length*(segment+1)/float(bands)
		var left: float = feature.lane-feature.width*0.5
		var right: float = feature.lane+feature.width*0.5
		var points := [section.point(a,left)+Vector3.UP*feature.height*segment/bands,section.point(a,right)+Vector3.UP*feature.height*segment/bands,section.point(b,left)+Vector3.UP*feature.height*(segment+1)/bands,section.point(b,right)+Vector3.UP*feature.height*(segment+1)/bands]
		st.set_color(RAMP_CREAM if segment == bands-1 or segment%2 == 1 else RAMP_ORANGE)
		for n in [0,2,1,1,2,3]: st.add_vertex(points[n]+Vector3.UP*0.025)
	st.set_color(RAMP_CREAM)
	for side in [-1.0,1.0]:
		var lane: float = feature.lane+side*feature.width*0.5
		var a: Vector3 = section.point(start,lane)
		var b: Vector3 = section.point(start+feature.length,lane)
		for p in [a,b,b+Vector3.UP*feature.height]: st.add_vertex(p+Vector3.UP*0.025)
	var end_left: Vector3 = section.point(start+feature.length,feature.lane-feature.width*0.5)
	var end_right: Vector3 = section.point(start+feature.length,feature.lane+feature.width*0.5)
	st.set_color(RAMP_ORANGE)
	for p in [end_left,end_right,end_left+Vector3.UP*feature.height,end_left+Vector3.UP*feature.height,end_right,end_right+Vector3.UP*feature.height]: st.add_vertex(p+Vector3.UP*0.025)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "JumpRamp"
	node.set_meta("world_ground",true)
	node.mesh = st.commit()
	var deck := StandardMaterial3D.new()
	deck.vertex_color_use_as_albedo = true
	deck.roughness = 0.7
	# A little self-light keeps the ramp readable under the night moon without a real light.
	deck.emission_enabled = true
	deck.emission = Color("ff9a4a")
	deck.emission_energy_multiplier = 0.22
	node.material_override = deck
	section.add_child(node)
	build_ramp_gate(section,feature,start-9.0)
	# Dark chevrons across the full deck width, pointing up the slope.
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width: float = float(feature.width)*0.5-0.35
	for row in range(4):
		var d: float = start+1.6+row*(feature.length-4.0)/3.0
		for side in [-1,1]:
			var road_points := [Vector2(feature.lane,d+1.2),Vector2(feature.lane+side*half_width,d),Vector2(feature.lane+side*half_width,d+0.9),Vector2(feature.lane,d+2.1)]
			for n in [0,1,2,0,2,3]:
				var p: Vector2 = road_points[n]
				arrows.add_vertex(section.point(p.y,p.x)+Vector3.UP*(0.07+feature.height*(p.y-start)/feature.length))
	arrows.generate_normals()
	var markings := MeshInstance3D.new()
	markings.mesh = arrows.commit()
	var ink := StandardMaterial3D.new()
	ink.albedo_color = RAMP_CHEVRON
	ink.roughness = 0.8
	markings.material_override = ink
	section.add_child(markings)

# A glowing orange gantry over the road a few metres before the ramp: it is visible from far away.
static func build_ramp_gate(section: Node3D, feature: Dictionary, d: float) -> void:
	var edge := float(section.half_width(d))+1.2
	var gate := Node3D.new()
	gate.name = "JumpGate"
	var ahead: Vector3 = section.point(d+3,0.0)
	var behind: Vector3 = section.point(d-3,0.0)
	var middle: Vector3 = section.point(d,0.0)
	gate.basis = Basis.looking_at((ahead-behind).normalized(),Vector3.UP)
	section.add_child(gate)
	gate.position = middle
	var glow := StandardMaterial3D.new()
	glow.albedo_color = RAMP_ORANGE
	glow.emission_enabled = true
	glow.emission = RAMP_ORANGE
	glow.emission_energy_multiplier = 1.6
	var post: Material = section.material(Color("2a323a"))
	for x in [-edge,edge]:
		section.box(gate,Vector3(x,3.4,0),Vector3(0.35,6.8,0.35),post)
		section.box(gate,Vector3(x,6.9,0),Vector3(0.7,0.5,0.7),glow)
	section.box(gate,Vector3(0,6.5,0),Vector3(edge*2.0,0.8,0.3),glow)
	section.box(gate,Vector3(0,6.5,0.18),Vector3(edge*2.0-1.2,0.35,0.1),section.material(RAMP_CHEVRON))

static func add_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(point+Vector3.UP*0.075)

# A parked box truck: cab in front, long trailer behind, six wheels. Local -Z is the driving direction.
static func build_truck(section: Node3D, feature: Dictionary) -> void:
	var d: float = feature.distance
	var truck := Node3D.new()
	truck.name = "ParkedTruck"
	var ahead: Vector3 = section.point(d+7,feature.lane)
	var behind: Vector3 = section.point(d-7,feature.lane)
	var middle: Vector3 = section.point(d,feature.lane)
	truck.basis = Basis.looking_at((ahead-behind).normalized(),Vector3.UP)
	section.add_child(truck)
	truck.position = middle
	var palette := [Color("e8e6df"),Color("d8d05a"),Color("c9563c"),Color("3d6f9e")]
	var body: Color = palette[(section.stage+section.route_node+int(d/100))%palette.size()]
	var width := float(feature.width)
	var half := float(feature.length)*0.5
	section.box(truck,Vector3(0,0.55,0),Vector3(width-0.3,0.5,float(feature.length)),section.material(Color("2b2f33")))
	section.box(truck,Vector3(0,2.45,half-4.3),Vector3(width,3.2,8.6),section.material(body))
	section.box(truck,Vector3(0,1.9,-half+1.5),Vector3(width-0.1,2.3,2.8),section.material(body.darkened(0.25)))
	section.box(truck,Vector3(0,2.35,-half+0.2),Vector3(width-0.5,1.0,0.12),section.material(Color("1b2b3a"),0.2))
	section.box(truck,Vector3(0,0.9,half+0.05),Vector3(width-0.4,0.3,0.12),section.material(Color("d63b3b")))
	for z in [-half+1.8,half-2.4,half-3.9]:
		for x in [-width*0.5+0.1,width*0.5-0.1]:
			section.box(truck,Vector3(x,0.5,z),Vector3(0.45,1.0,1.0),section.material(Color("15181b")))

# What is coming up in the next stretch of road, for the on-screen warning.
static func hazard_ahead(section: Node3D, distance: float) -> String:
	if section.closed_loop: return ""
	var best := 150.0
	var label := ""
	for feature in section.features:
		var gap: float = float(feature.distance)-distance
		if gap < 25 or gap >= best: continue
		if feature.kind == "truck": best = gap; label = "TRUCK AHEAD"
		elif feature.kind == "crest": best = gap; label = "STEEP DROP"
	for span in section.pinch_spans():
		var gap: float = span.x-distance
		if gap >= 0 and gap < best: best = gap; label = "NARROW ROAD"
	return label

# A narrow deck on concrete arms: ramp up, a long flat run over the lane below, ramp down.
static func skyway_height(feature: Dictionary, distance: float) -> float:
	var t: float = distance-(float(feature.distance)-float(feature.length)*0.5)
	if t < 0 or t > float(feature.length): return 0.0
	return float(feature.height)*clampf(minf(t,float(feature.length)-t)/SKYWAY_RAMP,0,1)

static func build_skyway(section: Node3D, feature: Dictionary) -> void:
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: float = feature.distance-feature.length*0.5
	var half: float = feature.width*0.5
	var steps := int(feature.length/5.0)
	for i in range(steps):
		var a: float = start+i*5.0
		var b: float = a+5.0
		var ha := skyway_height(feature,a)+0.06
		var hb := skyway_height(feature,b)+0.06
		var l: float = feature.lane-half
		var r: float = feature.lane+half
		var top := [section.point(a,l)+Vector3.UP*ha,section.point(a,r)+Vector3.UP*ha,section.point(b,l)+Vector3.UP*hb,section.point(b,r)+Vector3.UP*hb]
		for n in [0,2,1,1,2,3]: deck.add_vertex(top[n])
		# Slab sides so the deck reads as a solid bridge from the road below.
		for edge in [l,r]:
			var side_quad := [section.point(a,edge)+Vector3.UP*ha,section.point(b,edge)+Vector3.UP*hb,section.point(a,edge)+Vector3.UP*maxf(0.05,ha-0.9),section.point(b,edge)+Vector3.UP*maxf(0.05,hb-0.9)]
			for n in [0,1,2,2,1,3,0,2,1,2,3,1]: deck.add_vertex(side_quad[n])
		# Yellow edge lines warn how narrow the deck is.
		for edge in [l+0.15,r-0.15]:
			var line := [section.point(a,edge-0.1)+Vector3.UP*(ha+0.02),section.point(a,edge+0.1)+Vector3.UP*(ha+0.02),section.point(b,edge-0.1)+Vector3.UP*(hb+0.02),section.point(b,edge+0.1)+Vector3.UP*(hb+0.02)]
			for n in [0,2,1,1,2,3]: edges.add_vertex(line[n])
	deck.generate_normals()
	edges.generate_normals()
	var deck_node := MeshInstance3D.new()
	deck_node.name = "Skyway"
	deck_node.mesh = deck.commit()
	deck_node.material_override = section.material(Color("4a5157"))
	section.add_child(deck_node)
	var line_node := MeshInstance3D.new()
	line_node.mesh = edges.commit()
	line_node.material_override = section.material(Color("ffcc3a"))
	line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	section.add_child(line_node)
	# Supports stand outside the road edge; arms reach over to the deck so cars can pass under.
	var outward := signf(float(feature.lane))
	var transforms: Array[Transform3D] = []
	var d := start+SKYWAY_RAMP*0.6
	while d < start+feature.length-SKYWAY_RAMP*0.6:
		var h := skyway_height(feature,d)
		var foot: Vector3 = section.point(d,outward*(section.half_width(d)+section.rail_setback(d,outward)+1.2))
		var deck_edge: Vector3 = section.point(d,feature.lane+outward*half)
		var heading: float = section.heading(d)
		transforms.append(Transform3D(Basis(Vector3.UP,heading).scaled_local(Vector3(1.0,h,1.0)),foot+Vector3.UP*h*0.5))
		var arm_mid := (foot+deck_edge)*0.5
		arm_mid.y = deck_edge.y+h-0.5
		var arm_length := Vector2(foot.x-deck_edge.x,foot.z-deck_edge.z).length()+1.0
		transforms.append(Transform3D(Basis(Vector3.UP,heading).scaled_local(Vector3(arm_length,0.7,0.9)),arm_mid))
		d += 30.0
	section.box_batch(Vector3.ONE,section.material(Color("9aa1a3")),transforms)

