extends Node3D
# 실제 노면과 일치하는 경기장 지형·콘크리트 방호벽·관중석·광고 구역.
const Course = preload("res://scripts/track/speedway_course.gd")
const Field = preload("res://scripts/environment/speedway_infield.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const BASE_HEIGHT := 6.5
const BERM_REACH := 45.0
const WALL_HEIGHT := 1.7
const AD_SPACING := 50.0
const STAND_COUNT := 16
const STAND_CENTER := 350.0
const STAND_GAP := 3.5
const WALL_AD_EDGES := [0., .1849, .3625, .5366, .7057, .8760, 1.]
var track: Node3D
var theme := "speedway"
var batches: Array[MultiMeshInstance3D] = []
var grandstand_anchors: Array[Transform3D] = []
var ad_regions: Array[Vector2] = []
var wall_ads: Array[Dictionary] = []


func make_sky() -> Sky:
	return preload("res://scripts/environment/track_background.gd").create(
		"res://assets/environment/speedway-panorama.png"
	)


# 좁은 인필드 코너에서 지형 띠가 회전 중심을 넘어 뒤집히지 않게 한다.
func berm_reach(d: float) -> float:
	var edge: float = track.half_width(d) + 2
	return minf(BERM_REACH, maxf(8, .7 / maxf(.0001, absf(track.curvature(d))) - edge))


func ground_height(d: float, lane: float) -> float:
	var edge: float = track.half_width(d) + track.rail_setback(d, signf(lane)) + .65
	var platform: float = maxf(BASE_HEIGHT, track.point(d, signf(lane) * edge).y - .15)
	# 지형 메시와 같은9개 구간 사이를 보간해 부지와 실제 지형의 높이를 맞춘다.
	var u := clampf((absf(lane) - edge) / berm_reach(d), 0, 1) * 9
	var first := floorf(u)
	var blend := lerpf(smoothstep(0, 9, first), smoothstep(0, 9, minf(9, first + 1)), u - first)
	return lerpf(platform, BASE_HEIGHT, blend)


func outer_ground_height(d: float, lane: float) -> float:
	return ground_height(d, absf(lane))


func inner_ground_height(d: float, lane: float) -> float:
	return ground_height(d, -absf(lane))


func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d, lane)
	p.y = ground_height(d, lane)
	return p


func distance_at_xz(p: Vector3) -> float:
	var d: float = track.curve.get_closest_offset(p)
	for iteration in range(4):
		var q: Vector3 = track.point(d)
		var tangent: Vector3 = (track.point(d + 1) - track.point(d - 1)) * .5
		var derivative := Vector2(tangent.x, tangent.z)
		var offset := Vector2(p.x - q.x, p.z - q.z)
		d = fposmod(d + clampf(offset.dot(derivative) / maxf(.01, derivative.length_squared()), -80, 80), track.length)
	return d


func batch(label: String, size: Vector3, color: Color, poses: Array[Transform3D]) -> void:
	if poses.is_empty():
		return
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = size
	instances.mesh = mesh
	instances.instance_count = poses.size()
	for i in range(poses.size()):
		instances.set_instance_transform(i, poses[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = track.material(color)
	add_child(node)
	batches.append(node)


func pose(d: float, lane: float, height: float, size: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(
		Basis(Vector3.UP, track.heading(d)).scaled_local(size), terrain_point(d, lane) + Vector3.UP * height
	)


func _ready() -> void:
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://shaders/grass_ground.gdshader")
	grass.set_shader_parameter("terrain_variants", load("res://assets/environment/terrain-variants.png"))
	grass.set_shader_parameter("lawn_gain", Vector3(.72, 1.16, .82))
	grass.set_shader_parameter("mowing_strength", .12)
	Field.build(self, grass)
	make_berms(grass, -1, "SpeedwayInnerGround")
	make_berms(grass, 1, "SpeedwayOuterGround")
	make_walls_and_fences()
	make_stands()
	make_pits()
	make_lights()
	make_palms()
	make_infield_ads()
	make_wall_ads()


func make_berms(grass: Material, side: float, label: String) -> void:
	var root := Node3D.new()
	root.name = label
	add_child(root)
	var pieces := ceili(track.length / 240)
	for piece in range(pieces):
		var start: float = track.length * piece / pieces
		var finish: float = track.length * (piece + 1) / pieces
		var steps := ceili((finish - start) / 4)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(steps):
			var a := lerpf(start, finish, float(i) / steps)
			var b := lerpf(start, finish, float(i + 1) / steps)
			for band in range(9):
				var points: Array[Vector3] = []
				for pair in [Vector2(a, band), Vector2(a, band + 1), Vector2(b, band), Vector2(b, band + 1)]:
					var edge: float = track.half_width(pair.x) + track.rail_setback(pair.x, side) + .65
					points.append(terrain_point(pair.x, side * (edge + berm_reach(pair.x) * pair.y / 9)))
				for index in [0, 1, 2, 1, 3, 2] if side < 0 else [0, 2, 1, 1, 2, 3]:
					st.add_vertex(points[index])
		st.index()
		st.generate_normals()
		var node := MeshInstance3D.new()
		node.mesh = st.commit()
		node.material_override = grass
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)


func wall_point(d: float, height: float, offset: float = 0) -> Vector3:
	# 인쇄면을 방호벽과 같은4m 구간에 맞춰 곡선 안쪽으로 묻히는 깊이 충돌을 막는다.
	var step: float = track.length / ceili(track.length / 4)
	var cell := fposmod(d, track.length) / step
	var a := floorf(cell) * step
	var b := a + step
	var left: Vector3 = track.point(a, track.half_width(a) + track.rail_setback(a, 1) + offset)
	var right: Vector3 = track.point(b, track.half_width(b) + track.rail_setback(b, 1) + offset)
	return left.lerp(right, cell - floorf(cell)) + Vector3.UP * height


func make_walls_and_fences() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fence := SurfaceTool.new()
	fence.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posts: Array[Transform3D] = []
	var count := ceili(track.length / 4)
	for i in range(count):
		var a: float = track.length * i / count
		var b: float = track.length * (i + 1) / count
		# 두께60cm·높이1.7m의 닫힌 콘크리트 단면. 차도 쪽 면은 아스팔트 끝에 맞춘다.
		var profile := [Vector2(-.3, -.25), Vector2(-.3, WALL_HEIGHT), Vector2(.3, WALL_HEIGHT), Vector2(.3, -.25)]
		for face in range(4):
			var near: Vector2 = profile[face]
			var next: Vector2 = profile[(face + 1) % 4]
			var points := [
				wall_point(a, near.y, near.x),
				wall_point(b, near.y, near.x),
				wall_point(a, next.y, next.x),
				wall_point(b, next.y, next.x)
			]
			for n in [0, 1, 2, 1, 3, 2]:
				st.add_vertex(points[n])
		for n in [0, 1, 2, 2, 1, 3]:
			var d: float = a if n % 2 == 0 else b
			fence.set_uv(Vector2(d / 2, 0 if n < 2 else 1))
			fence.add_vertex(wall_point(d, WALL_HEIGHT if n < 2 else 5.6))
		if i % 3 == 0:
			var center := wall_point(a, (WALL_HEIGHT + 5.6) * .5)
			posts.append(Transform3D(Basis(Vector3.UP, track.heading(a)), center))
	st.generate_normals()
	var wall := MeshInstance3D.new()
	wall.name = "SpeedwaySafetyWalls"
	wall.mesh = st.commit()
	wall.material_override = track.material(Color("b7bdba"))
	add_child(wall)
	fence.generate_normals()
	var net := MeshInstance3D.new()
	net.name = "CatchFence"
	net.mesh = fence.commit()
	var wire := ShaderMaterial.new()
	wire.shader = preload("res://shaders/catch_fence.gdshader")
	net.material_override = wire
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)
	batch("FencePosts", Vector3(.15, 3.9, .15), Color("65747a"), posts)


func make_stands() -> void:
	var placements: Array[Dictionary] = []
	var foundations: Array[Transform3D] = []
	var bounds := Props.model("stadium_grandstand").get_aabb()
	var limits: Vector2 = Props.Models.definition("stadium_grandstand").placement_limits
	var scales: Array[float] = []
	var span := STAND_GAP * (STAND_COUNT - 1)
	for i in range(STAND_COUNT):
		var from_center := absf(2.0 * i / (STAND_COUNT - 1) - 1)
		var scale := lerpf(limits.y, limits.x, smoothstep(0, 1, from_center))
		scales.append(scale)
		span += bounds.size.x * scale
	var cursor := STAND_CENTER - span * .5
	for scale in scales:
		var width: float = bounds.size.x * scale
		var d := cursor + width * .5
		cursor += width + STAND_GAP
		var yaw: float = track.heading(d) - PI * .5
		var frame := Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3.ONE * scale), track.point(d, 30))
		var base := BASE_HEIGHT
		for x in [bounds.position.x, bounds.get_center().x, bounds.end.x]:
			for z in [bounds.position.z, bounds.get_center().z, bounds.end.z]:
				var sample := frame * Vector3(x, 0, z)
				var at := distance_at_xz(sample)
				var center: Vector3 = track.point(at)
				var lane := Vector2(sample.x - center.x, sample.z - center.z).length()
				base = maxf(base, outer_ground_height(at, lane))
		frame.origin.y = base + .4
		grandstand_anchors.append(frame)
		var height := frame.origin.y - BASE_HEIGHT
		var foundation_center := frame * Vector3(bounds.get_center().x, 0, bounds.get_center().z)
		foundations.append(
			Transform3D(
				Basis(Vector3.UP, yaw).scaled_local(Vector3(width, height, bounds.size.z * scale)),
				foundation_center - Vector3.UP * height * .5
			)
		)
		placements.append({"kind": "stadium_grandstand", "position": frame.origin, "yaw": yaw, "scale": scale})
	batch("GrandstandFoundations", Vector3.ONE, Color("7b8588"), foundations)
	var stands := Props.new()
	stands.name = "MainGrandstands"
	stands.configure("hawaii", placements)
	add_child(stands)


func make_pits() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(100):
		var a := 15.0 + i * 6
		var b := a + 6
		var pts := [track.point(a, -18), track.point(a, -32), track.point(b, -18), track.point(b, -32)]
		for n in [0, 2, 1, 1, 2, 3]:
			var p: Vector3 = pts[n]
			p.y = inner_ground_height(a if n < 2 else b, -18 if n % 2 == 0 else -32) + 0.03
			st.add_vertex(p)
	st.generate_normals()
	var apron := MeshInstance3D.new()
	apron.name = "PitLane"
	apron.mesh = st.commit()
	apron.material_override = track.material(Color("47555b"))
	add_child(apron)
	var garages: Array[Transform3D] = []
	var doors: Array[Transform3D] = []
	for i in range(20):
		var d := 30.0 + i * 28
		var p: Vector3 = track.point(d, -45)
		p.y = inner_ground_height(d, -45) + 3.5
		garages.append(Transform3D(Basis(Vector3.UP, track.heading(d)), p))
		p = track.point(d, -34.7)
		p.y = inner_ground_height(d, -34.7) + 2.4
		doors.append(Transform3D(Basis(Vector3.UP, track.heading(d)), p))
	batch("PitGarages", Vector3(20, 7, 26), Color("d4dbd8"), garages)
	batch("PitDoors", Vector3(0.2, 4, 20), Color("235565"), doors)
	var tower := Node3D.new()
	tower.name = "RaceControlTower"
	add_child(tower)
	tower.position = track.point(170, -70)
	tower.position.y = inner_ground_height(170, -70) + 0.05
	tower.rotation.y = track.heading(170)
	track.box(tower, Vector3(0, 10, 0), Vector3(15, 20, 20), track.material(Color("cbd6d4")))
	track.box(tower, Vector3(0, 21, 0), Vector3(21, 5, 27), track.material(Color("28566c"), 0.4))
	track.box(tower, Vector3(0, 24, 0), Vector3(24, 1, 30), track.material(Color("e4ad4b")))
	var label := Label3D.new()
	label.text = "SUNCOAST"
	label.font_size = 90
	label.pixel_size = 0.035
	label.position = Vector3(11, 21, 0)
	label.rotation.y = PI / 2
	tower.add_child(label)


func make_lights() -> void:
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for i in range(40):
		var d: float = Course.offset(track, 10) * i / 40
		poles.append(pose(d, 125, 22))
		heads.append(pose(d, 125, 44))
	batch("StadiumLightPoles", Vector3(.45, 44, .45), Color("738594"), poles)
	batch("StadiumLightBanks", Vector3(4.5, 1.8, 7), Color("f5f0d5"), heads)


func make_palms() -> void:
	var placements: Array[Dictionary] = []
	for i in range(20):
		var d := 500.0 + i * 40
		var p := terrain_point(d, -80)
		if Field.contains(p):
			continue
		var near: Vector3 = track.point(distance_at_xz(p))
		if Vector2(near.x - p.x, near.z - p.z).length() < 30:
			continue
		placements.append({"position": p, "yaw": i * 1.7, "scale": .85 + (i % 4) * .09, "variant": i})
	var palms := Props.new()
	palms.name = "SpeedwayPalms"
	palms.configure("hawaii", placements)
	add_child(palms)


func make_infield_ads() -> void:
	var placements: Array[Dictionary] = []
	for start in [Course.offset(track, 3) + 50, Course.offset(track, 15) + 20]:
		ad_regions.append(Vector2(start, start + 20 * AD_SPACING))
		for i in range(21):
			var d: float = start + i * AD_SPACING
			var radius: float = Props.radius("billboard")
			var lane: float = -(track.half_width(d) + track.rail_setback(d, -1) + radius + 2)
			placements.append(
				{
					"kind": "billboard",
					"position": terrain_point(d, lane),
					"distance": d,
					"lane": lane,
					"yaw": preload("res://scripts/environment/billboard_facing.gd").yaw(track, d, lane, 40, .60),
					"scale": 1.0,
					"print_fill": .6
				}
			)
	var props := Props.new()
	props.name = "InfieldAdvertisements"
	props.configure("hawaii", placements)
	add_child(props)


func make_wall_ads() -> void:
	var materials: Array[ShaderMaterial] = []
	var atlas: Texture2D = preload("res://scripts/rendering/render_resources.gd").fetch(
		"res://assets/environment/speedway-wall-ads.png"
	)
	for design in range(6):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/speedway_wall_ad.gdshader")
		mat.set_shader_parameter("atlas", atlas)
		mat.set_shader_parameter("row_bounds", Vector2(WALL_AD_EDGES[design], WALL_AD_EDGES[design + 1]))
		materials.append(mat)
	var root := Node3D.new()
	root.name = "WallAdvertisements"
	add_child(root)
	for i in range(54):
		var d: float = 100 + (track.length - 180) * i / 54
		var design := i % 6
		# 생성 원본의 실제 행 높이와 같은 종횡비. 문자·상품을 가로로 늘리지 않는다.
		var width: float = (
			1.18 * atlas.get_width() / (atlas.get_height() * (WALL_AD_EDGES[design + 1] - WALL_AD_EDGES[design]))
		)
		var metric: float = wall_point(d + .5, 0).distance_to(wall_point(d - .5, 0))
		var span := width / maxf(.5, metric)
		var begin := d - span * .5
		var end := d + span * .5
		var step: float = track.length / ceili(track.length / 4)
		var cuts: Array[float] = [begin, end]
		var index := floori(begin / step) + 1
		while index * step < end:
			cuts.append(index * step)
			index += 1
		cuts.sort()
		var origin := wall_point(d, .86, -.325)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in range(cuts.size() - 1):
			var a: float = cuts[segment]
			var b: float = cuts[segment + 1]
			for n in [0, 1, 2, 1, 3, 2]:
				var at: float = a if n % 2 == 0 else b
				st.set_uv(Vector2(1 - (at - begin) / span, 1 if n < 2 else 0))
				st.add_vertex(wall_point(at, .27 if n < 2 else 1.45, -.325) - origin)
		st.generate_normals()
		var node := MeshInstance3D.new()
		node.mesh = st.commit()
		node.position = origin
		node.material_override = materials[design]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 360
		root.add_child(node)
		wall_ads.append({"distance": d, "width": width, "height": 1.18, "design": design, "span": span})


func set_shadow_quality(enabled: bool) -> void:
	for node in batches:
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
