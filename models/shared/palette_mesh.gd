extends RefCounted
# CC0 재질을 한 표면의 정점색으로 변환한다. 원본 메시를 정적 참조하지 않는다.
const SATURATION := 1.18
static func build(definition: Resource) -> ArrayMesh:
	var source: Mesh = load(definition.source_mesh_path)
	var scale: float = definition.parameters.source_scale
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in range(source.get_surface_count()):
		var material := source.surface_get_material(surface) as BaseMaterial3D
		var color := (material.albedo_color if material != null else Color(0.5,0.5,0.5)).linear_to_srgb()
		color.s = clampf(color.s*SATURATION,0,1)
		var data := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		for i in range(indices.size() if not indices.is_empty() else vertices.size()):
			var index: int = indices[i] if not indices.is_empty() else i
			st.set_color(color)
			st.set_normal(normals[index])
			st.add_vertex(vertices[index]*scale)
	st.index()
	return st.commit()
