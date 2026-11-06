extends RefCounted
const PAD_SHADER = preload("res://shaders/boost_pad.gdshader")
const WATER_SHADER = preload("res://shaders/road_puddle.gdshader")

static func gentle_distance(section: Node3D, desired: float) -> float:
	var best := INF
	var chosen := desired
	for offset in range(-120,121,20):
		var d := clampf(desired+offset,300,section.length-280)
		var score: float = absf(section.curvature(d))*10000+absf(offset)*0.005
		if score < best: best = score; chosen = d
	return chosen

static func layout(section: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side := -1.0 if (section.stage+section.route_node)%2 == 0 else 1.0
	var specifications := [
		["boost",gentle_distance(section,440+section.stage*35+section.route_node*13),side*0.24,22.0,3.4],
		["water",section.length*0.47,-side*0.43,16.0,4.4]
	]
	if not section.closed_loop and section.stage == 0:
		var opposite := maxf(specifications[0][1]+90,gentle_distance(section,specifications[0][1]+200))
		specifications.append(["boost",opposite,-side*0.55,22.0,3.4])
	if not section.closed_loop and section.stage%2 == 1:
		specifications.append(["boost",gentle_distance(section,section.length*0.70),-side*0.60,22.0,3.4])
		specifications.append(["water",section.length*0.84,side*0.46,18.0,4.2])
	if section.closed_loop or section.stage%2 == 0:
		var ramp_d := gentle_distance(section,section.length*0.33) if section.course_id == 1 else (220.0 if section.closed_loop else gentle_distance(section,950+section.stage*90+section.route_node*20))
		specifications.append(["ramp",ramp_d,side*0.5,16.0,3.8])
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
	if section.closed_loop and section.course_id == 1:
		# Two readable slaloms: a neutral line misses the alternating pads.
		for start in [560.0,2490.0]:
			for index in range(6):
				specifications.append(["boost",start+index*78.0,-0.24 if index%2 == 0 else 0.24,12.0,3.6])
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
		var gap: float = feature.distance-distance
		if section.closed_loop: gap = fposmod(gap,section.length)
		if gap < 0 or gap > 110: continue
		if absf(lane-float(feature.lane)) < float(feature.width)*0.5+1.0:
			cost += (14.0 if feature.kind == "water" else -3.5)*(1-gap/120)
	return cost

static func swept_hit(feature: Dictionary, from: Vector2, to: Vector2, center_distance: float) -> bool:
	# Road-space sweep against the patch expanded by the tire footprint.
	var half := Vector2(float(feature.width)*0.5+1.0,float(feature.length)*0.5+1.7)
	var a := from-Vector2(feature.lane,center_distance)
	var delta := to-from
	if feature.kind == "water":
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
		node.name = "BoostLane" if feature.kind == "boost_lane" else ("BoostPad" if feature.kind == "boost" else "RoadPuddle")
		node.mesh = surface.commit()
		var material := ShaderMaterial.new()
		material.shader = PAD_SHADER if feature.kind in ["boost","boost_lane"] else WATER_SHADER
		if feature.kind == "boost_lane":
			material.set_shader_parameter("lane_mode",true)
			material.set_shader_parameter("arrow_count",feature.length/9.0)
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		section.add_child(node)

static func build_ramp(section: Node3D, feature: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: float = feature.distance-feature.length*0.5
	for segment in range(8):
		var a: float = start+feature.length*segment/8.0
		var b: float = start+feature.length*(segment+1)/8.0
		var left: float = feature.lane-feature.width*0.5
		var right: float = feature.lane+feature.width*0.5
		var points := [section.point(a,left)+Vector3.UP*feature.height*segment/8,section.point(a,right)+Vector3.UP*feature.height*segment/8,section.point(b,left)+Vector3.UP*feature.height*(segment+1)/8,section.point(b,right)+Vector3.UP*feature.height*(segment+1)/8]
		for n in [0,2,1,1,2,3]: st.add_vertex(points[n]+Vector3.UP*0.025)
	for side in [-1.0,1.0]:
		var lane: float = feature.lane+side*feature.width*0.5
		var a: Vector3 = section.point(start,lane)
		var b: Vector3 = section.point(start+feature.length,lane)
		for p in [a,b,b+Vector3.UP*feature.height]: st.add_vertex(p+Vector3.UP*0.025)
	var end_left: Vector3 = section.point(start+feature.length,feature.lane-feature.width*0.5)
	var end_right: Vector3 = section.point(start+feature.length,feature.lane+feature.width*0.5)
	for p in [end_left,end_right,end_left+Vector3.UP*feature.height,end_left+Vector3.UP*feature.height,end_right,end_right+Vector3.UP*feature.height]: st.add_vertex(p+Vector3.UP*0.025)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "JumpRamp"
	node.set_meta("world_ground",true)
	node.mesh = st.commit()
	node.material_override = section.material(Color("3a4447"))
	section.add_child(node)
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(5):
		var d: float = start+2+row*2.4
		for side in [-1,1]:
			var road_points := [Vector2(feature.lane,d+0.9),Vector2(feature.lane+side*1.4,d),Vector2(feature.lane+side*1.4,d+0.7),Vector2(feature.lane,d+1.6)]
			for n in [0,1,2,0,2,3]:
				var p: Vector2 = road_points[n]
				arrows.add_vertex(section.point(p.y,p.x)+Vector3.UP*(0.05+feature.height*(p.y-start)/feature.length))
	arrows.generate_normals()
	var markings := MeshInstance3D.new()
	markings.mesh = arrows.commit()
	markings.material_override = section.material(Color("ffca42"))
	section.add_child(markings)

static func add_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(point+Vector3.UP*0.075)
