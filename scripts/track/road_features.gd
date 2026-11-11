extends RefCounted
const PAD_SHADER = preload("res://shaders/boost_pad.gdshader")
const WATER_SHADER = preload("res://shaders/road_puddle.gdshader")
const Library = preload("res://scripts/track/route_library.gd")

# Each region leans on different devices so every route has its own feel. Extra counts are added
# to the shared base layout; a device that does not fit is simply left out.
#   jumps: extra ramps, chains: extra pad pairs, lane: a boost lane, water / mud: extra patches,
#   trucks: extra single trucks, gates: pairs of trucks to thread between.
# 고가 통로는 주차된 트럭 위를 지나며 옆으로 벗어나면 아래 도로로 내려온다.
const THEME_FEEL := {
	"hawaii": {"label": "COAST CRUISE"},
	"jungle": {"label": "CANOPY JUMPS", "jumps": 2},
	"city": {"label": "SKYWAY CITY", "skyway": 1, "gates": 1, "lane": 1},
	"pyramid": {"label": "DESERT JUMPS", "jumps": 2, "gates": 1},
	"amusement": {"label": "BOOST PARK", "chains": 2, "lane": 1},
	"jeju": {"label": "STONE AND MUD", "water": 2, "mud": 2},
	"ruins": {"label": "BROKEN ROAD", "jumps": 1, "mud": 2},
	"seoul": {"label": "EXPRESSWAY", "skyway": 1, "gates": 1, "trucks": 1},
	"fuji": {"label": "PAD RUN", "chains": 2, "lane": 1},
	"neon": {"label": "NEON BOOST", "chains": 2, "lane": 1, "skyway": 1},
	"canyon": {"label": "CANYON JUMPS", "jumps": 2},
	"harbor": {"label": "CONTAINER YARD", "gates": 2, "trucks": 2, "skyway": 1},
	"bamboo": {"label": "MUDDY PASS", "mud": 2, "water": 1},
	"snow": {"label": "ICE ROAD", "water": 3},
	"volcano": {"label": "LAVA JUMPS", "jumps": 2, "gates": 1}
}
const SKYWAY_LENGTH := 300.0
const SKYWAY_RAMP := 75.0
const SKYWAY_HEIGHT := 6.0
const SKYWAY_WIDTH := 9.0


static func feel(section: Node3D) -> Dictionary:
	return THEME_FEEL.get(Library.theme(section.stage, section.route_node), {})


static func tour_slot(
	section: Node3D, desired: float, extent: float, kind: String, occupied: Array[Vector2], ahead: float = 0.0
) -> float:
	var first := 320 + extent * 0.5 + (110 if kind == "ramp" else 0)
	var last: float = section.length - Library.CHECKPOINT_RUNUP - 100 - extent * 0.5 - (160 if kind == "ramp" else 0)
	var tunnel := Library.tunnel_span(section.stage, section.route_node)
	var best := INF
	var chosen := -1.0
	var count := maxi(1, ceili((last - first) / 10))
	for i in range(count + 1):
		var d := lerpf(first, last, float(i) / count)
		var bounds := Vector2(d - extent * 0.5 - 20, d + extent * 0.5 + 20 + ahead)
		var blocked := false
		for span in occupied:
			if bounds.x < span.y and bounds.y > span.x:
				blocked = true
				break
		if blocked:
			continue
		# 능선 꼭대기에서 도로가 급히 멀어지는 점프는 피하고 착지 여유를 남긴다.
		if kind == "ramp":
			var launch_y: float = section.point(d).y
			var launch_grade: float = (section.point(d + 4).y - section.point(d - 4).y) / 8
			for ahead_m in [40.0, 80.0, 120.0, 180.0]:
				if section.point(d + ahead_m).y < launch_y + launch_grade * ahead_m - 1.0:
					blocked = true
					break
		if blocked:
			continue
		if tunnel.y > tunnel.x:
			var gap := Vector2(d - 120, d + 180) if kind == "ramp" else Vector2(bounds.x - 40, bounds.y + 40)
			if kind in ["ramp", "water", "truck", "skyway"] and gap.x < tunnel.y + 80 and gap.y > tunnel.x - 40:
				continue
		var grade: float = (section.point(d + 4).y - section.point(d - 4).y) / 8
		if kind == "ramp" and absf(grade) > 0.045:
			continue
		var score: float = absf(d - desired) + absf(section.curvature(d)) * (600000 if kind == "ramp" else 9000)
		if kind == "ramp":
			score += absf(grade) * 1000
		if score < best:
			best = score
			chosen = d
	return chosen


static func tour_patch(
	section: Node3D, kind: String, d: float, fraction: float, extent: float, width: float, height: float = 0.0
) -> Dictionary:
	var patch := {
		"kind": kind, "distance": d, "lane": fraction * section.half_width(d), "length": extent, "width": width
	}
	if kind == "ramp":
		patch["height"] = height
	if kind == "boost" and extent <= 12:
		patch["duration"] = 0.52
	return patch


static func tour_layout(section: Node3D) -> Array[Dictionary]:
	section.configure_skyways([])
	var side := -1.0 if (section.stage + section.route_node) % 2 == 0 else 1.0
	var occupied: Array[Vector2] = []
	var crests: Array[Dictionary] = []
	var muds: Array[Dictionary] = []
	var trucks: Array[Dictionary] = []
	# Steep climbs and sudden narrowings keep their own stretch of road.
	for start in section.steep_starts():
		occupied.append(Vector2(start - 40, start + 160))
		var crest := tour_patch(section, "crest", start + 90, 0.0, 8, 60.0)
		crests.append(crest)
	for span in section.pinch_spans():
		occupied.append(Vector2(span.x - 50, span.y + 40))
	var ramps: Array[Dictionary] = []
	var water: Array[Dictionary] = []
	var pads: Array[Dictionary] = []
	var lanes: Array[Dictionary] = []
	var tunnel := Library.tunnel_span(section.stage, section.route_node)
	if section.stage >= 1:
		# One tall jump with its own run-up pad: it launches much higher and needs speed.
		var desired_big: float = 180 + (section.length - Library.CHECKPOINT_RUNUP - 260) * 0.52
		# The slot is searched with the whole run-up and landing corridor so nothing else lands in it.
		var big_d := tour_slot(section, desired_big, 150, "ramp", occupied, 100.0)
		if big_d >= 520:
			var big_fraction := -side * 0.18
			var big := tour_patch(section, "ramp", big_d, big_fraction, 26, 4.6, 2.6 + section.stage * 0.15)
			big["big"] = true
			ramps.append(big)
			pads.append(tour_patch(section, "boost", big_d - 78, big_fraction, 20, 3.4))
			occupied.append(Vector2(big_d - 110, big_d + 200))
	var profile := feel(section)
	var skyways: Array[Dictionary] = []
	if int(profile.get("skyway", 0)) > 0:
		var sky_d := tour_slot(section, section.length * 0.62, SKYWAY_LENGTH + 200, "skyway", occupied)
		if sky_d >= 0:
			var sky_fraction := side * 0.5
			var deck := tour_patch(section, "skyway", sky_d, sky_fraction, SKYWAY_LENGTH, SKYWAY_WIDTH)
			deck["height"] = SKYWAY_HEIGHT
			skyways.append(deck)
			# Parked trucks block the lane underneath: drive over them on the deck or go round.
			for offset in [-45.0, 45.0]:
				trucks.append(tour_patch(section, "truck", sky_d + offset, sky_fraction, 12.5, 2.8))
			occupied.append(Vector2(sky_d - SKYWAY_LENGTH * 0.5 - 60, sky_d + SKYWAY_LENGTH * 0.5 + 60))
	var ramp_count := (
		(2 if section.stage >= 2 and (section.stage + section.route_node) % 2 == 0 and tunnel.y - tunnel.x < 700 else 1)
		+ int(profile.get("jumps", 0))
	)
	for i in range(ramp_count):
		var desired: float = (
			180 + (section.length - Library.CHECKPOINT_RUNUP - 260) * [0.27, 0.68, 0.45, 0.85, 0.12][i % 5]
		)
		var d := tour_slot(section, desired, 100, "ramp", occupied, 120.0)
		if d < 0:
			d = tour_slot(section, desired, 70, "ramp", occupied, 120.0)
		# The tight last resort only keeps a first jump on crowded early routes.
		if d < 0 and i == 0:
			d = tour_slot(section, desired, 18, "ramp", occupied, 120.0)
		if d < 0:
			continue
		var fraction: float = side * (0.46 if i % 2 == 0 else -0.46)
		ramps.append(tour_patch(section, "ramp", d, fraction, 18, 3.8, 0.8 + section.stage * 0.05))
		# The lead-in is deliberate; the launch and landing corridor stays free
		# of every other surface gimmick, including opposite-side puddles.
		pads.append(tour_patch(section, "boost", d - 62, fraction, 20, 3.4))
		occupied.append(Vector2(d - 85, d + 160))
	if (section.stage + section.route_node) % 2 == 1 or int(profile.get("lane", 0)) > 0:
		var d := tour_slot(section, section.length * 0.58, 180, "boost_lane", occupied)
		if d >= 0:
			lanes.append(tour_patch(section, "boost_lane", d, -side * 0.42, 180, 3.4))
			occupied.append(Vector2(d - 110, d + 110))
	for i in range(2 + int(profile.get("water", 0))):
		var d := tour_slot(section, section.length * [0.46, 0.80, 0.30, 0.62, 0.90][i % 5], 18, "water", occupied)
		if d < 0:
			continue
		water.append(tour_patch(section, "water", d, -side * (0.44 if i % 2 == 0 else -0.44), 18, 4.0))
		occupied.append(Vector2(d - 40, d + 40))
	var chains: Array[Dictionary] = []
	for group in range(3 + int(profile.get("chains", 0))):
		var desired: float = [
			450 + section.stage * 20 + section.route_node * 12,
			section.length * 0.39,
			section.length * 0.69,
			section.length * 0.53,
			section.length * 0.82
		][group % 5]
		var middle := tour_slot(section, desired, 112, "boost", occupied)
		if middle < 0:
			continue
		for i in range(2):
			var d := middle - 50 + i * 100
			var fraction: float = side * (0.46 if (group + i) % 2 == 0 else -0.46)
			chains.append(tour_patch(section, "boost", d, fraction, 12, 3.0))
			# Mud beside the pad: the free lane costs speed, the pad lane pays it back.
			if i == 0:
				muds.append(tour_patch(section, "mud", d, -fraction, 14, 3.6))
		occupied.append(Vector2(middle - 76, middle + 76))
	# Truck gates: two trucks side by side with a car-and-a-half gap to thread through.
	for i in range(int(profile.get("gates", 0))):
		var gate_d := tour_slot(section, section.length * [0.47, 0.74][i % 2], 14, "truck", occupied)
		if gate_d < 0:
			continue
		var gap_lane := 3.2
		for lane_side in [-1.0, 1.0]:
			trucks.append(
				tour_patch(section, "truck", gate_d, lane_side * gap_lane / section.half_width(gate_d), 12.5, 2.8)
			)
		occupied.append(Vector2(gate_d - 50, gate_d + 50))
	for i in range(int(profile.get("mud", 0))):
		var mud_d := tour_slot(section, section.length * [0.35, 0.66][i % 2], 16, "mud", occupied)
		if mud_d < 0:
			continue
		muds.append(tour_patch(section, "mud", mud_d, 0.3 if i % 2 == 0 else -0.3, 16, 4.4))
		occupied.append(Vector2(mud_d - 40, mud_d + 40))
	# Long parked trucks take up one side of the road.
	var truck_count := (
		1 + (1 if section.stage >= 2 else 0) + (1 if section.stage >= 4 else 0) + int(profile.get("trucks", 0))
	)
	for i in range(truck_count):
		var truck_d := tour_slot(section, section.length * [0.31, 0.55, 0.83, 0.42, 0.68][i % 5], 14, "truck", occupied)
		if truck_d < 0:
			continue
		trucks.append(tour_patch(section, "truck", truck_d, 0.5 if (i + section.stage) % 2 == 0 else -0.5, 12.5, 2.8))
		occupied.append(Vector2(truck_d - 50, truck_d + 50))
	# Keep the introductory pad and puddle first for surface previews. IDs are
	# unique per section and do not change when another route is instantiated.
	var out: Array[Dictionary] = []
	if not chains.is_empty():
		out.append(chains.pop_front())
	if not water.is_empty():
		out.append(water.pop_front())
	out.append_array(chains)
	out.append_array(pads)
	out.append_array(water)
	out.append_array(ramps)
	out.append_array(lanes)
	out.append_array(muds)
	# 일반 승용차는 한쪽 차로만 차지하며 기존 기믹·터널에서 충분히 떨어뜨린다.
	for i in range(3 + section.stage):
		var at := tour_slot(section, section.length * (.18 + i * .095), 8, "truck", occupied)
		if at < 0:
			continue
		out.append(tour_patch(section, "car", at, .48 if i % 2 else -.48, 4.5, 2.05))
		occupied.append(Vector2(at - 42, at + 42))
	out.append_array(trucks)
	out.append_array(crests)
	out.append_array(skyways)
	for i in range(out.size()):
		out[i]["id"] = "%d:%d:%d" % [section.stage, section.route_node, i]
	section.configure_skyways(skyways)
	return out


static func gentle_distance(section: Node3D, desired: float) -> float:
	var best := INF
	var chosen := desired
	for offset in range(-120, 121, 20):
		var d := clampf(desired + offset, 300, section.length - 280)
		var score: float = absf(section.curvature(d)) * 10000 + absf(offset) * 0.005
		if score < best:
			best = score
			chosen = d
	return chosen


static func layout(section: Node3D) -> Array[Dictionary]:
	if not section.closed_loop:
		return tour_layout(section)
	var out: Array[Dictionary] = []
	var side := -1.0 if (section.stage + section.route_node) % 2 == 0 else 1.0
	var specifications := [
		["boost", gentle_distance(section, 440 + section.stage * 35 + section.route_node * 13), side * 0.24, 22.0, 3.4],
		["water", section.length * 0.47, -side * 0.43, 16.0, 4.4]
	]
	var ramp_d := gentle_distance(section, section.length * 0.33) if section.course_id == 1 else 220.0
	specifications.append(["ramp", ramp_d, side * 0.5, 16.0, 3.8])
	# MIDNIGHT HARBOR places everything by hand (below): the generic spots fall inside its hairpins.
	if section.course_id in [2, 3, 4]:
		specifications.clear()
	if section.closed_loop and section.course_id == 0:
		# Fuji: launch-straight, cutting approach, viaduct and return-road boosts.
		# The paired pads leave enough run-up before each optional jump and an
		# unobstructed lane beside it. The cutting jump lands before the tunnel.
		specifications.append_array(
			[
				["boost", 150.0, -0.50, 24.0, 4.2],
				["boost", 2420.0, -0.34, 26.0, 4.2],
				["ramp", 2460.0, -0.34, 20.0, 4.6, 1.35],
				["boost", 3950.0, 0.36, 26.0, 4.2],
				["ramp", 4030.0, 0.36, 22.0, 4.6, 1.55],
				["boost", 4850.0, -0.42, 26.0, 4.2]
			]
		)
	if section.closed_loop and section.course_id == 2:
		# 항만 뒤쪽 비포장 통로를 비우고 점프는 출발 직선, 부스트 차로는 앞쪽 연결 직선에 둔다.
		specifications.append_array(
			[
				["boost", 130.0, -0.30, 22.0, 3.4],
				["boost", 870.0, -0.30, 20.0, 3.4],
				["water", 930.0, 0.25, 16.0, 4.0],
				["ramp", 220.0, -0.35, 18.0, 3.8, 0.9],
				["boost_lane", 480.0, 0.40, 90.0, 3.8],
				["boost", 2135.0, 0.30, 20.0, 3.4],
				["boost", 2355.0, -0.30, 20.0, 3.4],
				["boost", 2670.0, 0.0, 24.0, 3.6]
			]
		)
	if section.closed_loop and section.course_id == 3:
		# 점프·가속 차로는 아치 붕괴와 좁아지는 협곡 진입을 피해 넓은 구간에 둔다.
		for desired in [500.0, 1780.0]:
			var at := gentle_distance(section, desired)
			var lane := .52 if desired < 1000 else -.52
			specifications.append(["boost", at - 75, lane, 22.0, 3.6])
			specifications.append(["ramp", at, lane, 18.0, 4.2, 1.0])
		specifications.append_array(
			[
				["boost", 180.0, .38, 22.0, 3.6],
				["boost_lane", 680.0, .42, 120.0, 3.6],
				["boost", 1530.0, .34, 22.0, 3.6],
				["boost", 2780.0, -.34, 22.0, 3.6],
				["boost_lane", section.length - 360, -.42, 180.0, 3.8]
			]
		)
	if section.closed_loop and section.course_id == 4:
		# 착지 구간과 코너 진입을 비워 두고, 패드 선택에 따라 주행선을 바꿉니다.
		for start in [170.0, 1720.0]:
			for index in range(3):
				specifications.append(["boost", start + index * 70, -.42 if index % 2 == 0 else .42, 12.0, 3.4])
		specifications.append_array(
			[
				["boost", 347.0, .62, 22.0, 5.4],
				["ramp", 399.0, .62, 28.0, 6.0, 8.0],
				["boost_lane", 600.0, .40, 120.0, 3.8],
				["boost", 590.0, -.38, 18.0, 3.8],
				["ramp", 660.0, -.38, 18.0, 4.4, .70],
				["boost", 1930.0, .38, 20.0, 3.8],
				["ramp", 2000.0, .38, 20.0, 4.4, .75],
				["boost_lane", section.length - 340, -.40, 140.0, 3.8]
			]
		)
	if section.closed_loop and section.course_id == 1:
		# 새 코스의 실제 직선에 배치하고 인필드 헤어핀 진입에서 가속시키지 않는다.
		specifications.clear()
		for start in [120.0, 1920.0]:
			for index in range(6):
				specifications.append(["boost", start + index * 78.0, -.40 if index % 2 == 0 else .40, 12.0, 3.0])
		specifications.append_array(
			[
				["boost_lane", 650.0, .42, 140.0, 4.4],
				["boost_lane", 5075.0, -.42, 140.0, 4.4],
				["boost", 4670.0, .35, 22.0, 3.6],
				["water", 3620.0, .35, 16.0, 4.0],
				["ramp", 5110.0, .40, 16.0, 3.8, .65]
			]
		)
	for i in range(specifications.size()):
		var spec: Array = specifications[i]
		var d: float = spec[1]
		out.append(
			{
				"id": "%d:%d:%d" % [section.stage, section.route_node, i],
				"kind": spec[0],
				"distance": d,
				"lane": float(spec[2]) * section.half_width(d),
				"length": spec[3],
				"width": spec[4]
			}
		)
		if spec[0] == "ramp":
			out[-1]["height"] = float(spec[5]) if spec.size() > 5 else 0.75
		if section.closed_loop and section.course_id == 1 and spec[0] == "boost" and float(spec[3]) <= 12:
			out[-1]["duration"] = 0.48
	return out


static func lane_cost(section: Node3D, distance: float, lane: float) -> float:
	var cost := 0.0
	for feature in section.features:
		if feature.kind in ["crest", "skyway"]:
			continue
		var gap: float = feature.distance - distance
		if section.closed_loop:
			gap = fposmod(gap, section.length)
		if gap < 0 or gap > 110:
			continue
		if absf(lane - float(feature.lane)) < float(feature.width) * 0.5 + 1.0:
			cost += (
				(40.0 if feature.kind in ["truck", "car"] else (14.0 if feature.kind in ["water", "mud"] else -3.5))
				* (1 - gap / 120)
			)
	return cost


static func swept_hit(feature: Dictionary, from: Vector2, to: Vector2, center_distance: float) -> bool:
	# Road-space sweep against the patch expanded by the tire footprint.
	var half := Vector2(float(feature.width) * 0.5 + 1.0, float(feature.length) * 0.5 + 1.7)
	var a := from - Vector2(feature.lane, center_distance)
	var delta := to - from
	if feature.kind in ["water", "mud"]:
		var start := a / half
		var move := delta / half
		var t := clampf(-start.dot(move) / maxf(move.length_squared(), 0.000001), 0, 1)
		return (start + move * t).length_squared() <= 1
	var enter := 0.0
	var exit := 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.000001:
			if absf(a[axis]) > half[axis]:
				return false
		else:
			var first := (-half[axis] - a[axis]) / delta[axis]
			var last := (half[axis] - a[axis]) / delta[axis]
			enter = maxf(enter, minf(first, last))
			exit = minf(exit, maxf(first, last))
			if enter > exit:
				return false
	return true


static func hazard_ahead(section: Node3D, distance: float) -> String:
	if section.closed_loop:
		return ""
	var best := 150.0
	var label := ""
	for feature in section.features:
		var gap: float = float(feature.distance) - distance
		if gap < 25 or gap >= best:
			continue
		if feature.kind == "truck":
			best = gap
			label = "TRUCK AHEAD"
		elif feature.kind == "car":
			best = gap
			label = "TRAFFIC AHEAD"
		elif feature.kind == "crest":
			best = gap
			label = "STEEP DROP"
	for span in section.pinch_spans():
		var gap: float = span.x - distance
		if gap >= 0 and gap < best:
			best = gap
			label = "NARROW ROAD"
	return label


# A narrow deck on concrete arms: ramp up, a long flat run over the lane below, ramp down.
static func skyway_height(feature: Dictionary, distance: float) -> float:
	var t: float = distance - (float(feature.distance) - float(feature.length) * 0.5)
	if t < 0 or t > float(feature.length):
		return 0.0
	return float(feature.height) * smoothstep(0, 1, clampf(minf(t, float(feature.length) - t) / SKYWAY_RAMP, 0, 1))


static func truck_skin(dimensions: Vector3, cabin: bool, red: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/truck_skin.gdshader")
	mat.set_shader_parameter("skins", load("res://assets/environment/urban-truck-elevations.png"))
	mat.set_shader_parameter("dimensions", dimensions)
	mat.set_shader_parameter("cabin", cabin)
	mat.set_shader_parameter("red_trailer", red)
	return mat

# 일반 교통 차량은 실제 차체로 움직이며 순위·랩 경쟁에는 참여하지 않는다.
