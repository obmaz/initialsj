extends RefCounted
# 한 게임 씬의 수명 동안 기본 메시를 공유한다. 마지막 씬이 나가면 강한 참조를 비운다.
static var owners := 0
static var quads: Dictionary = {}
static var box_mesh: ArrayMesh
static var vehicle_body: ShaderMaterial
# 작업 스레드에서 읽는 중인 리소스 경로. fetch()가 결과를 받아 가면 지운다.
static var warming: Dictionary = {}

static func acquire_owner() -> void:
	owners += 1

static func release_owner() -> bool:
	assert(owners > 0)
	owners -= 1
	if owners != 0: return false
	quads.clear()
	box_mesh = null
	vehicle_body = null
	for path in warming: ResourceLoader.load_threaded_get(path)
	warming.clear()
	return true

# 주행 중에 만드는 구간이 처음 쓰는 텍스처·모델을 작업 스레드에서 미리 읽기 시작한다.
static func warm(path: String) -> void:
	# 화면 없는 실행의 더미 렌더러는 스레드에서 리소스를 만들 수 없다. 그때는 fetch()가 바로 읽는다.
	if DisplayServer.get_name() == "headless": return
	if warming.has(path) or ResourceLoader.has_cached(path): return
	if ResourceLoader.load_threaded_request(path) == OK: warming[path] = true

# warm()으로 읽기 시작한 리소스는 그 결과를 받고, 아니면 바로 읽는다.
static func fetch(path: String) -> Resource:
	if warming.erase(path): return ResourceLoader.load_threaded_get(path)
	return load(path)

# 모든 차량의 차체·바퀴가 함께 쓰는 재질. 조각별 차이는 정점 자료에 있다.
static func vehicle_body_material() -> ShaderMaterial:
	if vehicle_body == null:
		vehicle_body = ShaderMaterial.new()
		vehicle_body.shader = preload("res://shaders/vehicle_body.gdshader")
	return vehicle_body

# 미리 읽기 시작했지만 쓰이지 않은 리소스를 놓는다.
static func release(path: String) -> void:
	if warming.erase(path): ResourceLoader.load_threaded_get(path)

static func quad(size: Vector2) -> QuadMesh:
	if not quads.has(size):
		var mesh := QuadMesh.new()
		mesh.size = size
		quads[size] = mesh
	return quads[size]

static func unit_box() -> ArrayMesh:
	if box_mesh == null:
		var source := BoxMesh.new()
		source.size = Vector3.ONE
		var data := source.surface_get_arrays(0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in data[Mesh.ARRAY_INDEX]:
			var p: Vector3 = data[Mesh.ARRAY_VERTEX][i]
			var n: Vector3 = data[Mesh.ARRAY_NORMAL][i]
			# 기본 BoxMesh의 3×2 펼침 대신 각 면을 0~1로 펼친다.
			var uv := Vector2(p.z+.5,.5-p.y) if absf(n.x)>.5 else (Vector2(p.x+.5,p.z+.5) if absf(n.y)>.5 else Vector2(p.x+.5,.5-p.y))
			st.set_normal(n)
			st.set_uv(uv)
			st.add_vertex(p)
		st.index()
		box_mesh = st.commit()
	return box_mesh
