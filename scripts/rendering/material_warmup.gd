extends Node
# 숨긴 구간도 작은 별도 뷰포트에서 실제 재질·인스턴싱 변형을 먼저 렌더한다.
# 파일 미리 읽기와 달리 드라이버 셰이더 준비·텍스처 업로드까지 수행한다.
signal completed
const Pool = preload("res://scripts/rendering/render_resources.gd")
var jobs: Array[Dictionary] = []
var keys := {}
var viewport: SubViewport
var stage: Node3D
var batch_size := 8
var collection: Array[Node] = []


static func prepare_course(race: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var worker := load("res://scripts/rendering/material_warmup.gd").new() as Node
	race.add_child(worker)
	worker.collect(race.track)
	worker.collect(race.player)
	worker.collect(race.thunderstorm)
	if race.mode == "tour" and not Pool.spatial_shaders_warmed:
		worker.collect_library()
	worker.begin(16)
	await worker.completed
	if race.mode == "tour":
		Pool.spatial_shaders_warmed = true
	var storm_pending: bool = race.thunderstorm.eligible() and not race.track.has_meta("storm_views_warmed")
	if race.track.active.closed_loop and (not race.track.has_meta("render_views_warmed") or storm_pending):
		await prepare_views(race)


# 큰 코스 메시의 첫 업로드·표지판 글꼴·실제 조명 변형도 불투명 로딩 화면 뒤에서 끝낸다.
static func prepare_views(race: Node3D) -> void:
	var camera: Camera3D = race.camera
	var saved := camera.global_transform
	var processing: bool = race.is_physics_processing()
	race.set_physics_process(false)
	# 번개가 추가하는 조명 변형도 로딩 화면 뒤에서 한 번 렌더한다.
	var storm_light: DirectionalLight3D = race.thunderstorm.light if race.thunderstorm.eligible() else null
	var light_visible := false
	var light_energy := 0.0
	if storm_light != null:
		light_visible = storm_light.visible
		light_energy = storm_light.light_energy
		storm_light.light_energy = .02
		storm_light.visible = true
	for distance in range(80, ceili(race.track.length), 180):
		camera.global_position = race.track.point(distance) + Vector3.UP * 3.4
		camera.look_at(race.track.point(distance + 55) + Vector3.UP * 2)
		camera.reset_physics_interpolation()
		await race.get_tree().process_frame
		await RenderingServer.frame_post_draw
	if storm_light != null:
		storm_light.visible = light_visible
		storm_light.light_energy = light_energy
		race.track.set_meta("storm_views_warmed", true)
	camera.global_transform = saved
	camera.reset_physics_interpolation()
	race.set_physics_process(processing)
	race.track.set_meta("render_views_warmed", true)


func add_mesh(mesh: Mesh, material: Material, surfaces: Array, instanced: bool, color: bool, custom: bool) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var ids: Array = surfaces.map(func(m): return m.get_instance_id() if m != null else 0)
	# 같은 재질이라도 서로 다른 메시의 첫 GPU 업로드를 각각 준비한다.
	var key := str(
		[
			mesh.get_instance_id(),
			mesh.surface_get_format(0),
			material.get_instance_id() if material != null else ids,
			instanced,
			color,
			custom
		]
	)
	if keys.has(key):
		return
	keys[key] = true
	jobs.append(
		{
			"mesh": mesh,
			"material": material,
			"surfaces": surfaces,
			"instanced": instanced,
			"color": color,
			"custom": custom
		}
	)


func collect(source: Node) -> void:
	for node in source.get_children():
		if node == self:
			continue
		collect_node(node)
		collect(node)


func collect_node(node: Node) -> void:
	if node is CPUParticles3D and node.mesh != null:
		var material: Material = node.material_override
		var key := "particles:" + str(material.get_instance_id() if material != null else node.mesh.get_instance_id())
		if not keys.has(key):
			keys[key] = true
			jobs.append({"particles": node})
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var multi: bool = node is MultiMeshInstance3D
		var mesh: Mesh = node.multimesh.mesh if multi else node.mesh
		var materials: Array = []
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				materials.append(mesh.surface_get_material(i) if multi else node.get_active_material(i))
		add_mesh(
			mesh,
			node.material_override,
			materials,
			multi,
			multi and node.multimesh.use_colors,
			multi and node.multimesh.use_custom_data
		)


func prepare_staged(source: Node) -> void:
	collection.assign(source.get_children())
	collection.reverse()
	call_deferred("collect_batches")


func collect_some(budget_usec: int = 500) -> bool:
	var started := Time.get_ticks_usec()
	var count := 0
	while not collection.is_empty():
		var node = collection.pop_back()
		if is_instance_valid(node) and node != self:
			collect_node(node)
			var children: Array[Node] = node.get_children()
			children.reverse()
			collection.append_array(children)
		count += 1
		if count >= 16 or Time.get_ticks_usec() - started >= budget_usec:
			break
	return collection.is_empty()


func collect_batches() -> void:
	while not cancelled() and not collect_some():
		await get_tree().process_frame
	if not cancelled():
		# 주행 화면과 동시에 렌더하므로 로딩 화면 뒤 준비보다 작게 나눈다.
		begin(1, Vector2i(128, 64))


func cancelled() -> bool:
	return (
		not is_inside_tree()
		or is_queued_for_deletion()
		or get_parent().is_queued_for_deletion()
		or get_parent().get_meta("retirement_pending", false)
	)


func collect_library() -> void:
	var mesh := Pool.unit_box()
	for file in ResourceLoader.list_directory("res://shaders"):
		if not file.ends_with(".gdshader"):
			continue
		var shader: Shader = load("res://shaders/" + file)
		if not shader.code.contains("shader_type spatial"):
			continue
		Pool.warmed_spatial_shaders.append(shader)
		var material := ShaderMaterial.new()
		material.shader = shader
		add_mesh(mesh, material, [], false, false, false)
		add_mesh(mesh, material, [], true, true, true)


func begin(limit: int = 8, size_px: Vector2i = Vector2i(256, 128)) -> void:
	batch_size = limit
	viewport = SubViewport.new()
	viewport.size = size_px
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.size = 24
	camera.position = Vector3(0, 0, 30)
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -20, 0)
	viewport.add_child(light)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 4, 9)
	spot.rotation_degrees.x = -20
	spot.spot_range = 60
	spot.spot_angle = 80
	viewport.add_child(spot)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 3, 4)
	omni.omni_range = 40
	viewport.add_child(omni)
	call_deferred("render_batches")


func render_batches() -> void:
	while not jobs.is_empty() and not cancelled():
		for node in stage.get_children():
			node.free()
		for index in range(mini(batch_size, jobs.size())):
			var job: Dictionary = jobs.pop_back()
			if job.has("particles"):
				var source: CPUParticles3D = job.particles
				var particles := CPUParticles3D.new()
				particles.emitting = false
				particles.local_coords = true
				particles.mesh = source.mesh
				particles.material_override = source.material_override
				particles.color_ramp = source.color_ramp
				particles.amount = 4
				particles.lifetime = .2
				particles.preprocess = .1
				stage.add_child(particles)
				particles.emitting = true
				continue
			var node: GeometryInstance3D
			var mesh: Mesh = job.mesh
			var bounds := mesh.get_aabb()
			var factor := 1.7 / maxf(.01, bounds.size[bounds.size.max_axis_index()])
			var position_at := Vector3((index % 8 - 3.5) * 2.6, (index / 8 - .5) * 3.0, 0)
			var pose := Transform3D(
				Basis.IDENTITY.scaled(Vector3.ONE * factor), position_at - bounds.get_center() * factor
			)
			if job.instanced:
				var batch := MultiMeshInstance3D.new()
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.use_colors = job.color
				multi.use_custom_data = job.custom
				multi.mesh = mesh
				multi.instance_count = 1
				multi.set_instance_transform(0, pose)
				if job.color:
					multi.set_instance_color(0, Color.WHITE)
				if job.custom:
					multi.set_instance_custom_data(0, Color(20, 20, 20, .5))
				batch.multimesh = multi
				node = batch
			else:
				var part := MeshInstance3D.new()
				part.mesh = mesh
				for surface in range(job.surfaces.size()):
					part.set_surface_override_material(surface, job.surfaces[surface])
				part.transform = pose
				node = part
			node.material_override = job.material
			stage.add_child(node)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		if cancelled():
			return
		await RenderingServer.frame_post_draw
		if cancelled():
			return
	if cancelled():
		return
	jobs.clear()
	keys.clear()
	viewport.free()
	queue_free()
	completed.emit()


func _exit_tree() -> void:
	collection.clear()
	jobs.clear()
	keys.clear()
