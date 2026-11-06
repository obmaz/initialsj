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
	for i in range(specifications.size()):
		var spec: Array = specifications[i]
		var d: float = spec[1]
		out.append({"id":"%d:%d:%d" % [section.stage,section.route_node,i],"kind":spec[0],"distance":d,"lane":float(spec[2])*section.half_width(d),"length":spec[3],"width":spec[4]})
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
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		if feature.kind == "boost":
			for i in range(10):
				var a: float = feature.distance-feature.length*0.5+feature.length*i/10.0
				var b: float = feature.distance-feature.length*0.5+feature.length*(i+1)/10.0
				var lanes := [feature.lane-feature.width*0.5,feature.lane+feature.width*0.5]
				var points := [section.point(a,lanes[0]),section.point(a,lanes[1]),section.point(b,lanes[0]),section.point(b,lanes[1])]
				var uv := [Vector2(0,i/10.0),Vector2(1,i/10.0),Vector2(0,(i+1)/10.0),Vector2(1,(i+1)/10.0)]
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
		node.name = "BoostPad" if feature.kind == "boost" else "RoadPuddle"
		node.mesh = surface.commit()
		var material := ShaderMaterial.new()
		material.shader = PAD_SHADER if feature.kind == "boost" else WATER_SHADER
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		section.add_child(node)

static func add_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(point+Vector3.UP*0.075)
