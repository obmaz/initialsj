extends Node3D
# 주행 형상과 분리된 시각 배치. 단계별 큐에서 GLB를 조립해 투어 연결 프레임의 작업을 나눈다.
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Library = preload("res://scripts/track/route_library.gd")
const Meter = preload("res://scripts/environment/speed_trap.gd")
const NAME := "RoadsideGuidance"
const ARROWS := ["bend_arrow_45", "bend_arrow_60", "bend_arrow_75"]
var road: Node3D
var corners: Array[Dictionary] = []
var markings: Array[Dictionary] = []
var station: Node3D
var camera_distance := -1.0
var digital_material: ShaderMaterial
var original_marker_mesh: Mesh
var original_marker_material: Material
var motion_setting := -1
var vessel: Node3D


static func has_camera(section: Node3D) -> bool:
	return section.course_id == 1 if section.closed_loop else section.stage in [1, 3]


static func dependencies(section: Node3D) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(ARROWS)
	if has_camera(section):
		ids.append_array(["speed_camera", "speed_display", "digital_chevrons"])
	elif is_night(section):
		ids.append("digital_chevrons")
	if section.closed_loop and section.course_id == 0:
		ids.append("lake_cruiser")
	var paths: Array[String] = []
	for id in ids:
		paths.append(preload("res://models/prop_models.gd").definition(id).scene_path)
	return paths


static func is_night(section: Node3D) -> bool:
	if section.closed_loop:
		return section.region_metadata.get("time_of_day", "night" if section.course_id == 2 else "day") == "night"
	return Library.theme(section.stage, section.route_node) == "neon"


static func attach(section: Node3D) -> void:
	if section.has_node(NAME):
		return
	var Assets = preload("res://scripts/rendering/world_assets.gd")
	for placement in [["checkpoint.tscn", "CircuitCheckpoint"], ["seasonal_avenue.tscn", "CherryAvenue"]]:
		var path: String = Assets.folder(section) + placement[0]
		if not ResourceLoader.exists(path) or section.has_node(placement[1]):
			continue
		var decoration: Node3D = preload("res://scripts/rendering/render_resources.gd").fetch(path).instantiate()
		Assets.geometry(decoration)
		decoration.transform = Assets.content_placement(section)
		section.add_child(decoration)
	var guide: Node3D = load("res://scripts/environment/roadside_guidance.gd").new()
	guide.name = NAME
	guide.road = section
	section.add_child(guide)
	var steps: Array[Callable] = [
		func(): guide.plan(),
		func(): guide.install_chevrons(),
		func(): guide.install_markings(),
		func(): guide.install_station(),
		func(): guide.install_vessel()
	]
	section.queue_next(steps)


static func reset(section: Node3D) -> void:
	var guide: Node3D = section.get_node_or_null(NAME)
	if guide != null and guide.station != null:
		guide.station.reset()


static func sync_visuals(race: Node3D) -> void:
	sync_section(race.track.active, race.motion_reduced)
	sync_section(race.track.previous, race.motion_reduced)
	sync_section(race.track.sibling, race.motion_reduced)
	for section in race.track.previews:
		sync_section(section, race.motion_reduced)


static func sync_section(section: Node3D, reduced_motion: bool) -> void:
	if not is_instance_valid(section):
		return
	var guide: Node3D = section.get_node_or_null(NAME)
	if guide == null or guide.motion_setting == int(reduced_motion):
		return
	guide.motion_setting = int(reduced_motion)
	if guide.digital_material != null:
		guide.digital_material.set_shader_parameter("animate", not reduced_motion)


static func advance(race: Node3D, delta: float) -> void:
	var guide: Node3D = race.track.active.get_node_or_null(NAME)
	if guide == null or guide.station == null:
		return
	guide.station.advance(
		delta,
		race.distance,
		race.speed,
		race.lane,
		(
			race.world_race.player_body.grounded
			and not race.air.active
			and not race.crash.active
			and race.protection_left <= 0
		),
		race.laps_completed
	)


func plan() -> void:
	var start := -1.0
	var turn := 0.0
	var peak := 0.0
	var direction := 0.0
	var end: float = road.length if road.closed_loop else road.checkpoint_distance() - 80
	for distance in range(0, ceili(end) + 12, 12):
		var curvature: float = road.curvature(minf(distance, end)) if distance < end else 0
		var side := signf(curvature) if absf(curvature) >= .0018 else 0.0
		if start >= 0 and (side == 0 or side != direction):
			if absf(turn) >= deg_to_rad(35) and peak >= .0045:
				var angle := absf(rad_to_deg(turn))
				corners.append(
					{
						"distance": start,
						"angle": 75 if angle >= 67.5 else (60 if angle >= 52.5 else 45),
						"side": -direction
					}
				)
			start = -1
			turn = 0
			peak = 0
		if side != 0:
			if start < 0:
				start = float(distance)
				direction = side
			turn += wrapf(road.heading(distance + 12) - road.heading(distance), -PI, PI)
			peak = maxf(peak, absf(curvature))
	if has_camera(road):
		camera_distance = straight_site()


func straight_site() -> float:
	var best := -1.0
	var score := INF
	for at in range(320, int(road.length - 600), 24):
		var clear := true
		var bend := 0.0
		for offset in [-50, 0, 60, 120, 180, 220]:
			var d: float = at + offset
			if road.in_tunnel(d) or road.on_bridge(d) or absf(road.point(d + 4).y - road.point(d - 4).y) > 1.2:
				clear = false
			bend += absf(road.curvature(d))
		for feature in road.features:
			if (
				feature.kind in ["jump", "skyway", "gate"]
				and feature.distance > at - 120
				and feature.distance < at + 300
			):
				clear = false
		if clear and bend < score:
			score = bend
			best = float(at)
	return best


func install_chevrons() -> void:
	if road.curve_markers == null:
		return
	if original_marker_mesh == null:
		original_marker_mesh = road.curve_markers.multimesh.mesh
		original_marker_material = road.curve_markers.material_override
		road.curve_markers.multimesh = road.curve_markers.multimesh.duplicate()
	if not is_night(road):
		road.curve_markers.multimesh.mesh = original_marker_mesh
		road.curve_markers.material_override = original_marker_material
		return
	if digital_material == null:
		digital_material = ShaderMaterial.new()
		digital_material.shader = preload("res://shaders/digital_chevrons.gdshader")
		digital_material.set_shader_parameter("animate", motion_setting != 1)
	road.curve_markers.multimesh.mesh = Props.model("digital_chevrons")
	road.curve_markers.material_override = digital_material


func surface_pose(distance: float, lane: float, side: float) -> Transform3D:
	var forward: Vector3 = (road.point(distance + 3, lane) - road.point(distance - 3, lane)).normalized()
	var across: Vector3 = (road.point(distance, lane + .5) - road.point(distance, lane - .5)).normalized()
	var up := across.cross(forward).normalized()
	var right := forward.cross(up).normalized()
	var scale_factor := minf(1, (road.half_width(distance) - absf(lane) - .6) / 3.5)
	return Transform3D(
		Basis(right * side, up, -forward).scaled_local(Vector3.ONE * scale_factor),
		road.point(distance, lane) + up * .045
	)


func install_markings() -> void:
	var groups := {}
	for corner in corners:
		var angle: int = corner.angle
		if not groups.has(angle):
			groups[angle] = []
		for ahead in [150, 105, 60]:
			var d: float = corner.distance - ahead
			if road.closed_loop:
				d = fposmod(d, road.length)
			elif d < 65:
				continue
			if not clear_marking(d, 0):
				continue
			groups[angle].append(surface_pose(d, 0, corner.side))
			markings.append(
				{"distance": d, "angle": angle, "lane": 0.0, "corner": corner.distance, "side": corner.side}
			)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://shaders/approach_arrow.gdshader")
	paint.set_shader_parameter("night", is_night(road))
	for angle: int in groups:
		if groups[angle].is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = Props.model("bend_arrow_" + str(angle))
		multi.instance_count = groups[angle].size()
		for i in range(groups[angle].size()):
			multi.set_instance_transform(i, groups[angle][i])
		var batch := MultiMeshInstance3D.new()
		batch.name = "ApproachArrow" + str(angle)
		batch.multimesh = multi
		batch.material_override = paint
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)


func clear_marking(distance: float, lane: float) -> bool:
	if road.on_bridge(distance):
		return false
	for feature in road.features:
		if feature.kind not in ["boost", "boost_lane", "jump", "gate", "skyway", "truck"]:
			continue
		var gap: float = absf(distance - float(feature.distance))
		if road.closed_loop:
			gap = minf(gap, road.length - gap)
		if gap < float(feature.length) * .5 + 7 and absf(lane - float(feature.lane)) < float(feature.width) * .5 + 3.5:
			return false
	return true


func install_station() -> void:
	if camera_distance < 0:
		return
	station = Meter.new()
	station.name = "SpeedMeasurement"
	add_child(station)
	station.configure(road, camera_distance)


func install_vessel() -> void:
	if not road.closed_loop or road.course_id != 0:
		return
	# 가장 가까운 도로까지75m 이상인 호수 안쪽을 골라 반대편 노면과도 겹치지 않는다.
	for anchor in [Vector2(360, -100), Vector2(720, -140), Vector2(940, -175), Vector2(1280, -175)]:
		var at: Vector3 = road.point(anchor.x, anchor.y)
		var nearest: float = road.curve.get_closest_offset(at)
		if Vector2(at.x - road.point(nearest).x, at.z - road.point(nearest).z).length() < 75:
			continue
		vessel = Meter.instance("lake_cruiser")
		vessel.name = "LakeCruiser"
		vessel.position = Vector3(at.x, 0, at.z)
		vessel.rotation.y = road.heading(anchor.x) + .25
		add_child(vessel)
		return
