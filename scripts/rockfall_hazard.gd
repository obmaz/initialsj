extends Node3D
# 주회마다 다른 협곡 지점에 떨어진 바위가 남는다. 중앙 통과 폭을 보장한다.
var section: Node3D
var rng := RandomNumberGenerator.new()
var plans: Array[Dictionary] = []
var scenic_plans: Array[Dictionary] = []
var planned_lap := -1
var rock_mesh: SphereMesh
var rock_material: ShaderMaterial
func configure(road: Node3D) -> void:
	section = road
	rock_mesh = SphereMesh.new()
	rock_mesh.radius = 1
	rock_mesh.height = 2
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 3
	rock_material = ShaderMaterial.new()
	rock_material.shader = preload("res://shaders/sandstone.gdshader")
	rock_material.set_shader_parameter("rock_detail",preload("res://assets/environment/generated-rock-variants.png"))
func reset_effect(seed_value: int = -1) -> void:
	for plan in plans+scenic_plans:
		if is_instance_valid(plan.get("node")): plan.node.queue_free()
	plans.clear()
	scenic_plans.clear()
	planned_lap = -1
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value
	plan_lap(0)
func allowed_site(d: float) -> bool:
	if d < 1100 or d > section.length-280 or section.in_tunnel(d) or section.on_bridge(d) or section.half_width(d) < 8: return false
	for old in plans:
		var gap: float = absf(d-float(old.distance))
		if minf(gap,section.length-gap) < 400: return false
	for feature in section.features:
		if absf(d-float(feature.distance)) < float(feature.length)*.5+90: return false
	return true
func plan_lap(lap: int) -> void:
	if lap <= planned_lap or lap >= 3: return
	var candidates: Array[float] = []
	for i in range(120):
		var d: float = rng.randf_range(1100,section.length-280)
		if allowed_site(d): candidates.append(d)
	if candidates.is_empty():
		for d in range(1100,int(section.length-280),20):
			if allowed_site(d): candidates.append(float(d))
	if candidates.is_empty(): return
	var d: float = candidates[rng.randi_range(0,candidates.size()-1)]
	var side := -1.0 if rng.randf()<.5 else 1.0
	plans.append({"distance":d,"side":side,"lap":lap,"elapsed":-1.0,"landed":false,"node":null,"bodies":[],"targets":[],"marker":null})
	# 도로 장애물과 별도로, 협곡 양쪽에서 주회마다 다섯 차례 대량 낙하한다.
	for i in range(5):
		var at: float = 1120+(section.length-1400)*(i+.5)/5+rng.randf_range(-70,70)
		scenic_plans.append({"distance":at,"side":-1.0 if rng.randf()<.5 else 1.0,"lap":lap,"elapsed":-1.0,"landed":false,"node":null,"bodies":[],"targets":[],"marker":null,"scenic":true})
	planned_lap = lap
func start_fall(plan: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "RockfallLap"+str(plan.lap+1)
	add_child(group)
	plan.node = group
	var scenic: bool = plan.get("scenic",false)
	for i in range(14 if scenic else 9):
		var d: float = float(plan.distance)+(i-(6.5 if scenic else 4))*3.7
		var lane: float = float(plan.side)*(section.half_width(d)*.66+(i%2)*.8)
		if scenic: lane = float(plan.side)*(section.half_width(d)+section.rail_setback(d,plan.side)+5.5+(i%3)*2.4)
		var size := Vector3(rng.randf_range(1.4,1.9),rng.randf_range(1.1,1.7),rng.randf_range(1.7,2.2))
		var target: Vector3 = (section.roadside_point(d,lane) if scenic else section.point(d,lane))+Vector3.UP*size.y*.85
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 4
		body.scale = size
		var mesh := MeshInstance3D.new()
		mesh.mesh = rock_mesh
		mesh.material_override = rock_material
		body.add_child(mesh)
		if not scenic:
			var shape := CollisionShape3D.new()
			shape.shape = rock_mesh.create_convex_shape()
			body.add_child(shape)
		group.add_child(body)
		body.position = target+Vector3(float(plan.side)*22,30+i*3,0)
		plan.bodies.append(body)
		plan.targets.append(target)
	if scenic: return
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 2.3
	ring.outer_radius = 2.55
	ring.rings = 16
	ring.ring_segments = 6
	marker.mesh = ring
	marker.material_override = section.paint(Color("ffc138"))
	marker.position = section.point(plan.distance,float(plan.side)*section.half_width(plan.distance)*.62)+Vector3.UP*.09
	group.add_child(marker)
	plan.marker = marker
func advance(delta: float, distance: float, lap: int) -> void:
	plan_lap(lap)
	var d := fposmod(distance,section.length)
	for plan in plans+scenic_plans:
		if plan.landed: continue
		if plan.elapsed < 0:
			if int(plan.lap) != lap or d < float(plan.distance)-380 or d > float(plan.distance)+30: continue
			plan.elapsed = 0.0
			start_fall(plan)
		plan.elapsed += delta
		var scenic: bool = plan.get("scenic",false)
		var all_landed := true
		if is_instance_valid(plan.marker): plan.marker.visible = float(plan.elapsed) < 3.5 and fposmod(float(plan.elapsed),.3)<.2
		for i in range(plan.bodies.size()):
			var body: StaticBody3D = plan.bodies[i]
			var target: Vector3 = plan.targets[i]
			var t := clampf((float(plan.elapsed)-.75-i*.055)/1.4,0,1)
			var bounce := sin(clampf((float(plan.elapsed)-2.15-i*.055)/.5,0,1)*PI)*.65
			body.position = target+Vector3(float(plan.side)*22*(1-t),(30+i*1.5)*(1-t*t)+bounce,0)
			body.rotation = Vector3(t*(.3+i*.21),t*i*.43,t*.8*float(plan.side))
			if t >= 1 and not scenic: body.collision_layer = 2
			if t < 1 or float(plan.elapsed) < 2.65+i*.055: all_landed = false
		if all_landed:
			plan.landed = true
			if is_instance_valid(plan.marker): plan.marker.visible = false
func safe_lane(distance: float, requested: float) -> float:
	var d := fposmod(distance,section.length)
	for plan in plans:
		if plan.elapsed < 0: continue
		var gap: float = fposmod(float(plan.distance)-d+20,section.length)-20
		if gap > -18 and gap < 170: return -float(plan.side)*section.half_width(d)*.3
	return requested
func warning(distance: float) -> String:
	var d := fposmod(distance,section.length)
	for plan in plans:
		if plan.elapsed < 0: continue
		var gap: float = float(plan.distance)-d
		if gap > -30 and gap < 380:
			return ("ROCKS ON ROAD" if plan.landed else "ROCKFALL")+" / KEEP "+("LEFT" if plan.side > 0 else "RIGHT")
	return ""
