extends RefCounted
# 한 게임 씬의 수명 동안 기본 메시를 공유한다. 마지막 씬이 나가면 강한 참조를 비운다.
static var owners := 0
static var quads: Dictionary = {}
static var box_mesh: ArrayMesh

static func acquire_owner() -> void:
	owners += 1

static func release_owner() -> bool:
	assert(owners > 0)
	owners -= 1
	if owners != 0: return false
	quads.clear()
	box_mesh = null
	return true

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
