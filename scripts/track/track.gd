extends Node3D
const Section = preload("res://scripts/track/road_section.gd")
const Library = preload("res://scripts/track/route_library.gd")
var active: Section
var previous: Section
var sibling: Section
var previews: Array[Section] = []
var history: Array[int] = []
var weather_seed := int(Time.get_ticks_usec() % 100000)
const RegionMetadata = preload("res://scripts/environment/tour_region_metadata.gd")
var base_material: StandardMaterial3D
var ground_plane: MeshInstance3D
var length: float:
	get:
		return active.length
var scenery: Node3D:
	get:
		return active.scenery
var road_surface: MeshInstance3D:
	get:
		return active.road_surface
var prop_batches: Array[MultiMeshInstance3D]:
	get:
		return active.prop_batches


func _ready() -> void:
	reset()
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50000, 50000)
	base.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6e8563")
	material.roughness = 1
	base.material_override = material
	base_material = material
	base.position.y = -5
	ground_plane = base
	add_child(base)
	update_ground()


func disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		disable_collisions(child)


func retire(node: Node) -> void:
	disable_collisions(node)
	node.queue_free()


func _exit_tree() -> void:
	disable_collisions(self)


func reset(stage: int = 0, node_index: int = 0) -> void:
	for node in [active, previous, sibling]:
		if is_instance_valid(node):
			retire(node)
	for node in previews:
		if is_instance_valid(node):
			retire(node)
	previews.clear()
	history.clear()
	previous = null
	sibling = null
	for i in range(stage):
		history.append(1 if i < node_index else 0)
	weather_seed += 37
	var previous_weather := "clear"
	var previous_node := 0
	for i in range(stage):
		previous_weather = (
			RegionMetadata.resolve(Library.theme(i, previous_node), previous_weather, weather_seed).weather
		)
		previous_node += history[i]
	active = Section.new(Vector3(0, 6, 0), -PI / 2, stage, node_index)
	active.region_metadata = RegionMetadata.resolve(Library.theme(stage, node_index), previous_weather, weather_seed)
	add_child(active)
	add_world_collision(active)
	build_previews()
	update_ground()


func add_world_collision(section: Section) -> void:
	section.add_child(preload("res://scripts/physics/world_collision.gd").build(section))


# 충돌체도 형상 수집·장벽 구간·물리 등록으로 나눠 만든 뒤 구간을 보이게 한다.
func stage_world_collision(section: Section) -> void:
	var Collision := preload("res://scripts/physics/world_collision.gd")
	var state := {}
	var steps: Array[Callable] = [func(): state.merge(Collision.begin(section))]
	for part in range(ceili(section.length / 400.0)):
		steps.append(func(): Collision.walls(section, state, 400.0))
	steps.append(func(): state.ground_body = Collision.body("RoadSurfaceBody", state.ground, 1))
	steps.append(func(): section.add_child(Collision.finish(state)))
	steps.append(func(): section.visible = true)
	section.queue_next(steps)


# 주행 중 다음 구간 생성에 한 프레임이 쓸 수 있는 시간. 한 단계는 끝까지 실행한다.
const BUILD_BUDGET_USEC := 1500
# 갈림길까지 이 거리 안으로 들어오면 남은 단계를 한 번에 끝낸다(정상 주행에서는 그 전에 끝난다).
const BUILD_DEADLINE := 1200.0


func update_ground() -> void:
	if base_material != null:
		var theme_id := Library.theme(active.stage, active.route_node)
		var urban_colors := {"city": "505963", "seoul": "64665f", "ruins": "5c6256", "neon": "232932"}
		if urban_colors.has(theme_id):
			base_material.albedo_color = Color(urban_colors[theme_id])
		else:
			base_material.albedo_color = (
				Color("125a79") if Library.coastal(theme_id) else Color(Library.PALETTES[theme_id]).darkened(0.2)
			)


# staged이면 구간의 곡선만 즉시 만들고 메시·풍경·충돌체는 maintain()이 프레임마다 나눠 만든다.
# 완성 전에는 숨겨 두며, 그동안에도 point()·half_width()는 곡선만으로 동작한다.
func build_previews(staged: bool = false) -> void:
	if previews.size() >= 2 or active.stage >= Library.STAGES - 1:
		return
	for side in range(previews.size(), 2):
		var section := Section.new(
			active.point(active.length),
			active.heading(active.length),
			active.stage + 1,
			active.route_node + side,
			-1 if side == 0 else 1
		)
		section.region_metadata = RegionMetadata.resolve(
			Library.theme(section.stage, section.route_node), active.region_metadata.weather, weather_seed
		)
		section.staged = staged
		section.visible = not staged
		add_child(section)
		if staged:
			section.build_queue.append(func(): stage_world_collision(section))
		else:
			add_world_collision(section)
		previews.append(section)
		if staged:
			break


func finish_previews() -> void:
	build_previews()
	for section in previews:
		section.build_some()


func maintain(distance: float) -> void:
	# 지나온 구간을 한 프레임에 하나씩 먼저 해제한 뒤에 다음 구간을 만들어, 동시에 살아 있는 구간 수를 줄인다.
	if distance > 420:
		if is_instance_valid(sibling):
			retire(sibling)
			sibling = null
		elif is_instance_valid(previous):
			retire(previous)
			previous = null
		else:
			build_previews(true)
	var budget := BUILD_BUDGET_USEC if distance < active.length - BUILD_DEADLINE else -1
	for section in previews:
		if section.build_pending():
			section.build_some(budget)
			if budget >= 0:
				break


func point(distance: float, lane: float = 0) -> Vector3:
	if distance < 0 and is_instance_valid(previous):
		return previous.point(previous.length + distance, lane)
	if distance <= active.length or previews.size() != 2:
		return active.point(distance, lane)
	var d := distance - active.length
	var center := (previews[0].point(d) + previews[1].point(d)) / 2
	var next := (previews[0].point(d + 2) + previews[1].point(d + 2)) / 2
	var f := (next - center).normalized()
	return center + Vector3(-f.z, 0, f.x).normalized() * lane


func heading(distance: float) -> float:
	var f := point(distance + 2) - point(distance - 2)
	return atan2(-f.x, -f.z)


func curvature(distance: float) -> float:
	return wrapf(heading(distance + 12) - heading(distance - 12), -PI, PI) / 24


func traffic_point(distance: float, lane: float, side: int = 0) -> Vector3:
	if distance > active.length and previews.size() == 2:
		return previews[clampi(side, 0, 1)].point(distance - active.length, lane)
	return point(distance, lane)


func half_width(distance: float) -> float:
	if distance < 0 and is_instance_valid(previous):
		return previous.half_width(previous.length + distance)
	if distance > active.length and previews.size() == 2:
		var d := distance - active.length
		return (
			previews[0].point(d).distance_to(previews[1].point(d)) * 0.5
			+ minf(previews[0].half_width(d), previews[1].half_width(d))
		)
	return active.half_width(distance)


func advance(side: int, distance: float, lane: float) -> Dictionary:
	finish_previews()
	var world := point(distance, lane)
	var old_length := active.length
	if is_instance_valid(previous):
		retire(previous)
	if is_instance_valid(sibling):
		retire(sibling)
	previous = active
	active = previews[side]
	sibling = previews[1 - side]
	sibling.scenery.set_ground_enabled(false)
	active.scenery.set_ground_enabled(true)
	previews.clear()
	history.append(side)
	update_ground()
	var d := distance - old_length
	var forward := (active.point(d + 2) - active.point(d)).normalized()
	d += (world - active.point(d)).dot(forward)
	var right := Vector3(-forward.z, 0, forward.x).normalized()
	return {"distance": d, "lane": (world - active.point(d)).dot(right), "old_length": old_length, "sibling": sibling}


func reconsider(distance: float, lane: float) -> Dictionary:
	if distance >= 150 or not is_instance_valid(sibling):
		return {}
	var world := point(distance, lane)
	if world.distance_to(sibling.point(distance)) + 0.7 >= world.distance_to(active.point(distance)):
		return {}
	var old := active
	active = sibling
	sibling = old
	sibling.scenery.set_ground_enabled(false)
	active.scenery.set_ground_enabled(true)
	history[-1] = 0 if active.entry_side < 0 else 1
	update_ground()
	var f := (active.point(distance + 2) - active.point(distance)).normalized()
	var d := distance + (world - active.point(distance)).dot(f)
	var right := Vector3(-f.z, 0, f.x).normalized()
	return {"distance": d, "lane": (world - active.point(d)).dot(right)}
