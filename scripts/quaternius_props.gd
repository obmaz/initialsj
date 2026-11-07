extends RefCounted
# CC0 low-poly nature models by Quaternius (assets/environment/props/README.md), turned into the
# one-surface, vertex-colour meshes that RegionalProps3D batches with a single shared material.
# Each model is scaled here to the track's proportions, so mesh AABBs and radii are final.
const MODELS := {
	"lake_pine_1":{"mesh":preload("res://assets/environment/props/PineTree_1.obj"),"scale":4.2},
	"lake_pine_2":{"mesh":preload("res://assets/environment/props/PineTree_4.obj"),"scale":4.0},
	"lake_pine_3":{"mesh":preload("res://assets/environment/props/PineTree_5.obj"),"scale":4.4},
	"lake_oak_1":{"mesh":preload("res://assets/environment/props/CommonTree_3.obj"),"scale":3.4},
	"lake_oak_2":{"mesh":preload("res://assets/environment/props/CommonTree_4.obj"),"scale":3.8},
	"lake_willow_1":{"mesh":preload("res://assets/environment/props/Willow_3.obj"),"scale":3.6},
	"lake_willow_2":{"mesh":preload("res://assets/environment/props/Willow_4.obj"),"scale":3.2},
	"lake_willow_3":{"mesh":preload("res://assets/environment/props/Willow_5.obj"),"scale":3.8},
	"lake_bush_1":{"mesh":preload("res://assets/environment/props/Bush_1.obj"),"scale":2.2},
	"lake_bush_2":{"mesh":preload("res://assets/environment/props/Bush_2.obj"),"scale":2.4},
	"lake_rock_1":{"mesh":preload("res://assets/environment/props/Rock_Moss_2.obj"),"scale":2.8},
	"lake_rock_2":{"mesh":preload("res://assets/environment/props/Rock_Moss_4.obj"),"scale":2.4},
	"lake_rock_3":{"mesh":preload("res://assets/environment/props/Rock_Moss_6.obj"),"scale":2.6},
	"lake_rock_4":{"mesh":preload("res://assets/environment/props/Rock_3.obj"),"scale":3.0},
}
const TREES := ["lake_pine_1","lake_pine_2","lake_pine_3","lake_oak_1","lake_oak_2","lake_willow_1","lake_willow_2","lake_willow_3"]
const PINES := ["lake_pine_1","lake_pine_2","lake_pine_3"]
const OAKS := ["lake_oak_1","lake_oak_2"]
const WILLOWS := ["lake_willow_1","lake_willow_2","lake_willow_3"]
const BUSHES := ["lake_bush_1","lake_bush_2"]
const ROCKS := ["lake_rock_1","lake_rock_2","lake_rock_3","lake_rock_4"]
# The pack's colours are linear; the shared material reads vertex colours as sRGB, and the
# pack's flat greens are slightly grey beside the rest of the scenery, so lift them a little.
const SATURATION := 1.18

static func has(kind: String) -> bool:
	return MODELS.has(kind)

static func is_tree(kind: String) -> bool:
	return kind in TREES

static func build(kind: String) -> ArrayMesh:
	var source: Mesh = MODELS[kind].mesh
	var scale: float = MODELS[kind].scale
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
