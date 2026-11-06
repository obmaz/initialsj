extends RefCounted
# Metres in a local east / south projection. Road coordinates come from OSM,
# not an invented circuit. Street heights and corner rounding are a game prototype.
const DATA = preload("res://data/seocho-osm-route.json")
const TERRAIN = preload("res://data/seocho-elevation.json")
static var terrain_cache: Array[Vector3] = []
const ORIGIN := Vector2(127.01348,37.51209)
static func flat_project(p: Dictionary) -> Vector3:
	return Vector3((float(p.lon)-ORIGIN.x)*111320*cos(deg_to_rad(37.502)),0,(ORIGIN.y-float(p.lat))*111320)
static func height_at(p: Vector3) -> float:
	if terrain_cache.is_empty():
		for sample in TERRAIN.data.samples:
			var position := flat_project(sample)
			position.y = float(sample.elevation_m)
			terrain_cache.append(position)
	var nearest: Array[Vector2] = []
	for sample in terrain_cache:
		var sq := Vector2(p.x-sample.x,p.z-sample.z).length_squared()
		if nearest.size() < 4 or sq < nearest[-1].x:
			nearest.append(Vector2(sq,sample.y))
			nearest.sort_custom(func(a,b): return a.x < b.x)
			if nearest.size() > 4: nearest.pop_back()
	var weight := 0.0
	var value := 0.0
	for sample in nearest:
		var w := 1.0/(sample.x+1600)
		weight += w
		value += sample.y*w
	return value/weight
static func project(p: Dictionary) -> Vector3:
	var position := flat_project(p)
	position.y = height_at(position)
	return position
static func build(section: Node3D) -> void:
	var source: Array = DATA.data.game_points
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	for i in range(source.size()-1):
		var p := flat_project(source[i])
		if not points.is_empty() and points[-1].distance_to(p) < 4: continue
		points.append(p)
		var main: bool = source[i].highway in ["primary","secondary"]
		widths.append(9.0 if main else (5.2 if source[i].highway == "residential" else 6.8))
	section.curve.clear_points()
	section.curve.bake_interval = 1
	# Round road junctions locally (at most 35m), preserving the mapped alignment.
	for i in range(points.size()):
		var p := points[i]
		var before := points[posmod(i-1,points.size())]
		var after := points[(i+1)%points.size()]
		var incoming := (p-before).normalized()
		var outgoing := (after-p).normalized()
		var cut := minf(35,minf(p.distance_to(before),p.distance_to(after))*0.35)
		section.curve.add_point(p-incoming*cut,Vector3.ZERO,incoming*cut*0.67)
		section.curve.add_point(p+outgoing*cut,-outgoing*cut*0.67,Vector3.ZERO)
	var first: Vector3 = section.curve.get_point_position(0)
	section.curve.add_point(first,Vector3.ZERO,section.curve.get_point_out(0))
	# Sample the rounded map path against the coarse SRTM terrain, then smooth
	# longitudinally so DEM/building noise cannot create road-height steps.
	var base: Curve3D = section.curve.duplicate()
	var count := int(ceil(base.get_baked_length()/12))
	var road: Array[Vector3] = []
	for i in range(count):
		var p := base.sample_baked(base.get_baked_length()*i/count)
		p.y = height_at(p)
		road.append(p)
	for pass_index in range(2):
		var next: Array[Vector3] = []
		for i in range(count):
			var p := road[i]
			p.y = (road[posmod(i-2,count)].y+4*road[posmod(i-1,count)].y+6*road[i].y+4*road[(i+1)%count].y+road[(i+2)%count].y)/16
			next.append(p)
		road = next
	section.curve.clear_points()
	for i in range(count+1):
		var index := i%count
		var tangent := (road[(index+1)%count]-road[posmod(index-1,count)])/6
		section.curve.add_point(road[index],-tangent,tangent)
	section.length = section.curve.get_baked_length()
	# Locate width changes on the actual baked centreline, then blend across 24m.
	var last := -100.0
	for i in range(points.size()):
		if i > 0 and is_equal_approx(widths[i],widths[i-1]): continue
		var d: float = section.curve.get_closest_offset(Vector3(points[i].x,height_at(points[i]),points[i].z))
		if d < last: continue
		if i > 0:
			section.map_widths.append(Vector2(maxf(last,d-24),widths[i-1]))
		section.map_widths.append(Vector2(d,widths[i]))
		last = d
	section.map_widths.append(Vector2(section.length,widths[0]))
