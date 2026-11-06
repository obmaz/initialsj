extends RefCounted
# Metres in a local east / south projection. Road coordinates come from OSM,
# not an invented circuit. Street heights and corner rounding are a game prototype.
const DATA = preload("res://data/seocho-osm-route.json")
const ORIGIN := Vector2(127.01348,37.51209)
static func project(p: Dictionary) -> Vector3:
	return Vector3((float(p.lon)-ORIGIN.x)*111320*cos(deg_to_rad(37.502)),6,(ORIGIN.y-float(p.lat))*111320)
static func build(section: Node3D) -> void:
	var source: Array = DATA.data.game_points
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	for i in range(source.size()-1):
		var p := project(source[i])
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
	section.length = section.curve.get_baked_length()
	# Locate width changes on the actual baked centreline, then blend across 24m.
	var last := -100.0
	for i in range(points.size()):
		if i > 0 and is_equal_approx(widths[i],widths[i-1]): continue
		var d: float = section.curve.get_closest_offset(points[i])
		if d < last: continue
		if i > 0:
			section.map_widths.append(Vector2(maxf(last,d-24),widths[i-1]))
		section.map_widths.append(Vector2(d,widths[i]))
		last = d
	section.map_widths.append(Vector2(section.length,widths[0]))
