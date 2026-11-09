extends Node3D
# 도로 양옆의 층상 절벽을 잇는 두꺼운 자연 암석 아치. 차선 위 유효 높이를 비운다.
var track: Node3D
var distances: Array[float] = [1140.0,2380.0]
var manifest: Array[Dictionary] = []

func _ready() -> void:
	for d in distances: make_arch(d)

func make_arch(d: float) -> void:
	var center: Vector3 = track.point(d)
	var right: Vector3 = (track.point(d,1)-center).normalized()
	var forward: Vector3 = (track.point(d+1)-track.point(d-1)).normalized()
	var radius: float = track.half_width(d)+track.rail_setback(d,1)+15
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 앞뒤 면·윗면·안쪽 면을 닫아 충분한 두께와 깊이를 가진 단면을 만든다.
	for i in range(48):
		var vertices: Array[Vector3] = []
		for step in [i,i+1]:
			var angle: float = PI*step/48
			var erosion := 0.7*sin(angle*13)+0.35*sin(angle*29)
			for outer in [false,true]:
				var rx: float = radius+(6.5+erosion if outer else 0)
				var ry: float = 27+(7.5+erosion if outer else 0)
				for depth in [-1.0,1.0]:
					vertices.append(center+right*cos(angle)*rx+Vector3.UP*(sin(angle)*ry-3)+forward*depth*(6.5+0.6*sin(angle*11)))
		for index in [0,4,1,1,4,5,2,3,6,3,7,6,0,2,4,2,6,4,1,5,3,3,5,7]: st.add_vertex(vertices[index])
	st.index()
	st.generate_normals()
	var rock := MeshInstance3D.new()
	rock.name = "CanyonRockArch"
	rock.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sandstone.gdshader")
	mat.set_shader_parameter("rock_detail",preload("res://assets/environment/generated-rock-variants.png"))
	rock.material_override = mat
	add_child(rock)
	manifest.append({"distance":d,"inner_radius":radius,"crown_clearance":24.0,"depth":13.0,"mesh":rock})
