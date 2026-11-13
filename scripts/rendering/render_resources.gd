extends RefCounted
# 한 게임 씬의 수명 동안 기본 메시를 공유한다. 마지막 씬이 나가면 강한 참조를 비운다.
static var spatial_shaders_warmed := false
static var warmed_spatial_shaders: Array[Shader] = []
static var owners := 0
static var quads: Dictionary = {}
static var box_mesh: ArrayMesh
static var vehicle_body: ShaderMaterial
static var vehicle_outline: ShaderMaterial
static var traffic_models := {}
static var shared_world_scenes := {}
static var shared_world_materials := {}
# 작업 스레드에서 읽는 중인 리소스 경로. fetch()가 결과를 받아 가면 지운다.
static var warming: Dictionary = {}


static func acquire_owner() -> void:
	owners += 1


static func release_owner() -> bool:
	assert(owners > 0)
	owners -= 1
	if owners != 0:
		return false
	spatial_shaders_warmed = false
	warmed_spatial_shaders.clear()
	quads.clear()
	box_mesh = null
	preload("res://scripts/rendering/primitive_assets.gd").clear()
	vehicle_body = null
	vehicle_outline = null
	traffic_models.clear()
	shared_world_scenes.clear()
	shared_world_materials.clear()
	preload("res://models/shared/world_geometry_map.gd").clear()
	for path in warming:
		ResourceLoader.load_threaded_get(path)
	warming.clear()
	return true


# 주행 중에 만드는 구간이 처음 쓰는 텍스처·모델을 작업 스레드에서 미리 읽기 시작한다.
static func warm(path: String) -> void:
	# 화면 없는 실행의 더미 렌더러는 스레드에서 리소스를 만들 수 없다. 그때는 fetch()가 바로 읽는다.
	if DisplayServer.get_name() == "headless":
		return
	if warming.has(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		warming[path] = true


# warm()으로 읽기 시작한 리소스는 그 결과를 받고, 아니면 바로 읽는다.
static func fetch(path: String) -> Resource:
	if warming.erase(path):
		return ResourceLoader.load_threaded_get(path)
	return load(path)


# 모든 차량의 차체·바퀴가 함께 쓰는 재질. 조각별 차이는 정점 자료에 있다.
static func vehicle_body_material() -> ShaderMaterial:
	if vehicle_body == null:
		vehicle_body = ShaderMaterial.new()
		vehicle_body.shader = preload("res://shaders/vehicle_body.gdshader")
	return vehicle_body


# 가까운 차체가 같은 외곽선 재질을 공유한다.
static func vehicle_outline_material() -> ShaderMaterial:
	if vehicle_outline == null:
		vehicle_outline = ShaderMaterial.new()
		vehicle_outline.shader = preload("res://shaders/vehicle_outline.gdshader")
	return vehicle_outline


# 미리 읽기 시작했지만 쓰이지 않은 리소스를 놓는다.
static func release(path: String) -> void:
	if warming.erase(path):
		ResourceLoader.load_threaded_get(path)


static func quad(size: Vector2) -> ArrayMesh:
	if not quads.has(size):
		quads[size] = preload("res://scripts/rendering/primitive_assets.gd").quad(size)
	return quads[size]


static func unit_box() -> ArrayMesh:
	if box_mesh == null:
		box_mesh = preload("res://scripts/rendering/primitive_assets.gd").mesh("unit_box")
	return box_mesh
