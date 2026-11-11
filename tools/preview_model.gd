extends SceneTree
const Catalog = preload("res://models/model_catalog.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Car = preload("res://scripts/vehicles/car.gd")
const Architecture = preload("res://scripts/environment/urban_architecture.gd")
var camera: Camera3D
var focus := Vector3.ZERO
var distance := 8.0
var output := ""
var frames := 0
var capturing := false


func _initialize() -> void:
	call_deferred("build")


func build() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args[0] not in ["--prop", "--vehicle", "--building"]:
		push_error("사용법: -- --prop ID | --vehicle ID | --building ID [--output build/reports/model.png]")
		quit(2)
		return
	var category: String = {"--prop": "props", "--vehicle": "vehicles", "--building": "buildings"}[args[0]]
	var item: Resource = Catalog.find(category, args[1])
	if item == null:
		push_error("모델을 찾을 수 없다: " + args[1])
		quit(2)
		return
	if args.size() > 2:
		if args.size() != 4 or args[2] != "--output":
			push_error("출력 경로는 --output PATH로 지정한다")
			quit(2)
			return
		output = args[3]
		if DisplayServer.get_name() == "headless":
			push_error("이미지 저장은 그래픽 세션에서 실행한다. Linux CI는 xvfb-run -a를 사용한다")
			quit(2)
			return
	root.size = Vector2i(1280, 800)
	var stage := Node3D.new()
	root.add_child(stage)
	var bounds: AABB
	if category == "vehicles":
		var car := Car.new()
		car.model = item.id
		car.paint = Color("3476a4")
		stage.add_child(car)
		bounds = collect_bounds(car, Transform3D.IDENTITY)
	elif category == "props":
		var node := MeshInstance3D.new()
		node.mesh = Props.model(item.id)
		node.material_override = (
			preload("res://scripts/environment/advertisement_library.gd").prop_material(0)
			if item.id == "billboard"
			else Props.material_for(item.id)
		)
		stage.add_child(node)
		bounds = node.get_aabb()
	else:
		var size := Vector3(
			item.parameters.width_range.x, item.parameters.height_range.x, item.parameters.depth_range.x
		)
		var parts: Array = preload("res://scripts/environment/urban_architecture.gd").parts(
			item.order, size.x, size.y, size.z
		)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		var scene := preload("res://models/shared/scene_source.gd").instantiate_static(item.scene_path)
		multi.mesh = preload("res://models/shared/scene_source.gd").collect_meshes(scene)[0].mesh
		scene.free()
		multi.instance_count = parts.size()
		for i in range(parts.size()):
			var part: Dictionary = parts[i]
			multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(part.size), part.position))
			multi.set_instance_custom_data(i, Color(part.size.x, part.size.y, part.size.z, .5))
			var next := AABB(part.position - part.size * .5, part.size)
			bounds = next if i == 0 else bounds.merge(next)
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = Architecture.material(Catalog.all("buildings").find(item), "city")
		stage.add_child(node)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("26323c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5cce0")
	environment.ambient_light_energy = .65
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -35, 0)
	light.light_energy = 1.1
	stage.add_child(light)
	focus = bounds.get_center()
	distance = maxf(4, bounds.size.length() * 1.25)
	camera = Camera3D.new()
	camera.fov = 45
	camera.position = focus + Vector3(-.8, .5, -1 if category == "vehicles" else 1).normalized() * distance
	stage.add_child(camera)
	camera.look_at(focus)
	add_grid(stage, ceili(maxf(bounds.size.x, bounds.size.z) * .8) + 2, bounds.position.y - .03)
	print("모델: ", category, "/", item.id, " / 미터 치수: ", bounds.size, " / 격자 간격: 1m")
	if output.is_empty():
		print("A/D: 회전, W/S: 확대·축소, Esc: 종료")


func collect_bounds(node: Node3D, parent: Transform3D) -> AABB:
	var pose := parent * node.transform
	var bounds: AABB = pose * node.get_aabb() if node is MeshInstance3D else AABB()
	for child in node.get_children():
		if not child is Node3D or not child.visible:
			continue
		var next := collect_bounds(child, pose)
		if next.size != Vector3.ZERO:
			bounds = next if bounds.size == Vector3.ZERO else bounds.merge(next)
	return bounds


func add_grid(stage: Node3D, extent: int, y: float) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-extent, extent + 1):
		for p in [Vector3(i, y, -extent), Vector3(i, y, extent), Vector3(-extent, y, i), Vector3(extent, y, i)]:
			mesh.surface_add_vertex(p)
	mesh.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("52616b")
	grid.material_override = mat
	stage.add_child(grid)


func _process(delta: float) -> bool:
	if camera == null:
		return false
	frames += 1
	if not output.is_empty() and frames >= 10 and not capturing:
		capturing = true
		call_deferred("capture")
	if Input.is_key_pressed(KEY_ESCAPE):
		quit()
	var turn := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var offset := (camera.position - focus).rotated(Vector3.UP, turn * delta)
	var zoom := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	camera.position = focus + offset * exp(zoom * delta)
	camera.look_at(focus)
	return false


func capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result := root.get_texture().get_image().save_png(output)
	print("모델 미리보기 저장: ", output)
	quit(0 if result == OK else 1)
