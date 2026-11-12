extends Node3D
# 주회마다 다른 협곡 지점에 떨어진 바위가 남는다. 중앙 통과 폭을 보장한다.
const ROAD_REMAINS := 9
const ROAD_FALL_COUNT := 24
const SCENIC_FALL_COUNT := 24
const SCENIC_BURSTS := 10
const PRE_FALL := .95
const FALL_DURATION := 1.9
const STAGGER := .06
const BOUNCE_TIME := .42
var section: Node3D
var rng := RandomNumberGenerator.new()
var plans: Array[Dictionary] = []
var scenic_plans: Array[Dictionary] = []
var planned_lap := -1
var rock_mesh: Mesh
var rock_material: ShaderMaterial
var rock_shape: ConvexPolygonShape3D


func configure(road: Node3D) -> void:
	section = road
	rock_mesh = preload("res://scripts/rendering/primitive_assets.gd").mesh("rockfall_rock")
	rock_shape = rock_mesh.create_convex_shape()
	rock_material = ShaderMaterial.new()
	rock_material.shader = preload("res://shaders/sandstone.gdshader")
	rock_material.set_shader_parameter("rock_detail", load("res://assets/environment/generated-rock-variants.png"))


func reset_effect(seed_value: int = -1) -> void:
	for plan in plans + scenic_plans:
		if is_instance_valid(plan.get("node")):
			plan.node.queue_free()
	plans.clear()
	scenic_plans.clear()
	planned_lap = -1
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	plan_lap(0)


func allowed_site(d: float) -> bool:
	if (
		d < 1100
		or d > section.length - 280
		or section.in_tunnel(d)
		or section.on_bridge(d)
		or section.half_width(d) < 8
	):
		return false
	for old in plans:
		var gap: float = absf(d - float(old.distance))
		if minf(gap, section.length - gap) < 400:
			return false
	for feature in section.features:
		if absf(d - float(feature.distance)) < float(feature.length) * .5 + 90:
			return false
	return true


func flow_score(d: float) -> float:
	# 계획 단계에서만 계산한다. 진입·회피 후 도로가 완만한 위치를 우선한다.
	var score := 0.0
	for offset in [-100.0, 0.0, 120.0]:
		score += absf(section.curvature(d + offset))
		if section.in_tunnel(d + offset) or section.on_bridge(d + offset):
			score += .1
	return score


func plan_lap(lap: int) -> void:
	if lap <= planned_lap or lap >= 3:
		return
	var candidates: Array[float] = []
	for i in range(120):
		var d: float = rng.randf_range(1100, section.length - 280)
		if allowed_site(d):
			candidates.append(d)
	if candidates.is_empty():
		for d in range(1100, int(section.length - 280), 20):
			if allowed_site(d):
				candidates.append(float(d))
	if candidates.is_empty():
		return
	var ranked: Array[Dictionary] = []
	for candidate in candidates:
		ranked.append({"distance": candidate, "score": flow_score(candidate)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary): return a.score < b.score)
	# 기존 이격·장애물 조건은 그대로 두고 완만한 후보 절반에서 무작위 선택한다.
	var d: float = ranked[rng.randi_range(0, maxi(0, ceili(ranked.size() * .5) - 1))].distance
	var side := -1.0 if rng.randf() < .5 else 1.0
	plans.append(
		{
			"distance": d,
			"side": side,
			"lap": lap,
			"elapsed": -1.0,
			"landed": false,
			"node": null,
			"bodies": [],
			"targets": [],
			"marker": null
		}
	)
	# 도로 장애물과 별도로, 협곡 양쪽에서 주회마다 열 차례 대량 낙하한다.
	for i in range(SCENIC_BURSTS):
		var at: float = 1120 + (section.length - 1400) * (i + .5) / SCENIC_BURSTS + rng.randf_range(-70, 70)
		scenic_plans.append(
			{
				"distance": at,
				"side": -1.0 if rng.randf() < .5 else 1.0,
				"lap": lap,
				"elapsed": -1.0,
				"landed": false,
				"node": null,
				"bodies": [],
				"targets": [],
				"marker": null,
				"scenic": true
			}
		)
	planned_lap = lap


func start_fall(plan: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "RockfallLap" + str(plan.lap + 1)
	add_child(group)
	plan.node = group
	var scenic: bool = plan.get("scenic", false)
	var count := SCENIC_FALL_COUNT if scenic else ROAD_FALL_COUNT
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = rock_mesh
	multi.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multi
	batch.material_override = rock_material
	group.add_child(batch)
	plan.batch = batch
	plan.poses = []
	plan.sizes = []
	for i in range(count):
		var d: float = float(plan.distance) + ((i - (count - 1) * .5) if scenic else (i % ROAD_REMAINS - 4)) * 3.7
		var lane: float = float(plan.side) * (section.half_width(d) * .66 + (i % 2) * .8)
		if scenic:
			lane = float(plan.side) * (section.half_width(d) + section.rail_setback(d, plan.side) + 5.5 + (i % 3) * 2.4)
		var size := Vector3(rng.randf_range(1.4, 1.9), rng.randf_range(1.1, 1.7), rng.randf_range(1.7, 2.2))
		# 도로에 남는9개의 치수는 유지한다. 큰 낙하 조각은 추가분과 도로 밖 연출로 제한한다.
		if scenic:
			size *= 1.6
		elif i >= ROAD_REMAINS:
			size *= 2.1
		var target: Vector3 = (
			(section.roadside_point(d, lane) if scenic else section.point(d, lane)) + Vector3.UP * size.y * .85
		)
		var pose := Transform3D(
			Basis.IDENTITY.scaled_local(size), target + Vector3(float(plan.side) * 22, 30 + i * 3, 0)
		)
		multi.set_instance_transform(i, pose)
		plan.poses.append(pose)
		plan.sizes.append(size)
		plan.targets.append(target)
		# 도로 밖 연출에는 물리 노드가 없다. 도로 안 장애물만 같은 충돌 모양을 공유한다.
		if not scenic and i < ROAD_REMAINS:
			var body := preload("res://scripts/physics/road_debris.gd").new()
			body.batch = batch
			body.slot = i
			body.collision_layer = 0
			body.collision_mask = 4
			body.transform = pose
			var shape := CollisionShape3D.new()
			shape.shape = rock_shape
			body.add_child(shape)
			group.add_child(body)
			plan.bodies.append(body)
	if scenic:
		return
	var marker := MeshInstance3D.new()
	var ring := preload("res://scripts/rendering/primitive_assets.gd").mesh("rockfall_marker")
	marker.mesh = ring
	marker.material_override = section.paint(Color("ffc138"))
	marker.position = (
		section.point(plan.distance, float(plan.side) * section.half_width(plan.distance) * .62) + Vector3.UP * .09
	)
	group.add_child(marker)
	plan.marker = marker


func advance(delta: float, distance: float, lap: int, speed: float = 70) -> void:
	plan_lap(lap)
	var d := fposmod(distance, section.length)
	for plan in plans + scenic_plans:
		if plan.landed:
			continue
		if plan.elapsed < 0:
			var lead := clampf(speed * 3.4, 160, 310)
			if int(plan.lap) != lap or d < float(plan.distance) - lead or d > float(plan.distance) + 30:
				continue
			plan.elapsed = 0.0
			start_fall(plan)
		plan.elapsed += delta
		var scenic: bool = plan.get("scenic", false)
		var all_landed := true
		if is_instance_valid(plan.marker):
			plan.marker.visible = fposmod(float(plan.elapsed), .3) < .2
		for i in range(plan.targets.size()):
			if i < plan.bodies.size() and plan.bodies[i].broken:
				continue
			var target: Vector3 = plan.targets[i]
			var lands_at := PRE_FALL + FALL_DURATION + i * STAGGER
			var t := clampf((float(plan.elapsed) - PRE_FALL - i * STAGGER) / FALL_DURATION, 0, 1)
			var bounce := sin(clampf((float(plan.elapsed) - lands_at) / BOUNCE_TIME, 0, 1) * PI) * .65
			var position_at := (
				target + Vector3(float(plan.side) * 22 * (1 - t), (30 + i * 1.5) * (1 - t * t) + bounce, 0)
			)
			var rotation_at := Vector3(t * (.3 + i * .21), t * i * .43, t * .8 * float(plan.side))
			var pose := Transform3D(Basis.from_euler(rotation_at).scaled_local(plan.sizes[i]), position_at)
			plan.poses[i] = pose
			# 도로 안의 추가 낙하는 착지하면서 사라진다. 남는9개만 충돌체를 가진다.
			if not scenic and i >= ROAD_REMAINS and t >= 1:
				pose.basis = Basis.IDENTITY.scaled(Vector3.ZERO)
			plan.batch.multimesh.set_instance_transform(i, pose)
			if not scenic and i < plan.bodies.size():
				plan.bodies[i].transform = pose
				if t >= 1:
					plan.bodies[i].collision_layer = 8
			if t < 1 or float(plan.elapsed) < lands_at + BOUNCE_TIME:
				all_landed = false
		if all_landed:
			plan.landed = true
			if not scenic:
				plan.batch.multimesh.visible_instance_count = ROAD_REMAINS
			if is_instance_valid(plan.marker):
				plan.marker.visible = false


func safe_lane(distance: float, requested: float) -> float:
	var d := fposmod(distance, section.length)
	for plan in plans:
		if plan.elapsed < 0:
			continue
		var gap: float = fposmod(float(plan.distance) - d + 20, section.length) - 20
		if gap > -18 and gap < 170:
			return -float(plan.side) * section.half_width(d) * .3
	return requested


func warning(distance: float) -> String:
	var d := fposmod(distance, section.length)
	for plan in plans:
		if plan.elapsed < 0:
			continue
		var gap: float = float(plan.distance) - d
		if gap > -30 and gap < 380:
			return (
				("ROCKS ON ROAD" if plan.landed else "ROCKFALL") + " / KEEP " + ("LEFT" if plan.side > 0 else "RIGHT")
			)
	return ""
