extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var index: int = definition.parameters.variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var size: Vector3 = definition.base_size * Vector3(1.4, 1.25, 1.4)
	var roof_height: float = [2.1, 1.8, 1.5, 2.8, 3.2, .45, 1.4, .6, 2.2, 1.0][index]
	var roof_color := Color(
		["944d36", "516b59", "70544b", "69554a", "3f657c", "52725d", "a95036", "7c7c55", "536f82", "7c8280"][index]
	)
	Geometry.box(st, Vector3(0, .1, 0), Vector3(size.x + .8, .55, size.z + .8), Color("858375"))
	Geometry.box(st, Vector3(0, size.y * .5 + .35, 0), size, Color.WHITE, 0, 30 + index)
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x + 1.2, roof_height, size.z + 1.2)
	Geometry.append(st, roof, Transform3D(Basis.IDENTITY, Vector3(0, size.y + .35 + roof_height * .5, 0)), roof_color)
	# 처마 끝·석재 기단·모서리는 텍스처와 별개의 실제 부피를 가진다.
	for side in [-1.0, 1.0]:
		Geometry.box(
			st,
			Vector3(side * size.x * .5, size.y * .5 + .35, size.z * .5 + .06),
			Vector3(.18, size.y, .2),
			Color("aaa18b")
		)
	Geometry.box(
		st, Vector3(0, size.y + .35, size.z * .5 + .15), Vector3(size.x + 1.3, .2, .3), roof_color.darkened(.2)
	)
	if index in [0, 2, 3, 4, 8]:
		var y := 3.2
		Geometry.box(st, Vector3(0, y, size.z * .5 + 1.1), Vector3(size.x * .85, .2, 2.8), roof_color)
		for side in [-1.0, 1.0]:
			Geometry.box(
				st, Vector3(side * size.x * .38, y * .5, size.z * .5 + 2.1), Vector3(.18, y, .18), Color("b5a78a")
			)
	if index in [1, 2, 4]:
		Geometry.box(st, Vector3(size.x * .28, size.y + roof_height * .6, 0), Vector3(.85, 2.2, 1), Color("81786c"))
	if index in [3, 8]:
		Geometry.box(st, Vector3(0, 3.3, size.z * .5 + 1), Vector3(size.x * .7, .22, 2.4), Color("695143"))
		Geometry.box(st, Vector3(0, 4.3, size.z * .5 + 2), Vector3(size.x * .7, .12, .13), Color("594534"))
		for post in range(9):
			Geometry.box(
				st, Vector3((post - 4) * size.x * .075, 3.8, size.z * .5 + 2), Vector3(.08, 1, .08), Color("594534")
			)
	if index in [5, 6, 7, 8]:
		for strip in range(6):
			var x: float = -size.x * .45 + (strip + .5) * size.x * .15
			Geometry.box(
				st,
				Vector3(x, 3.25, size.z * .5 + 1.1),
				Vector3(size.x * .15, .18, 2.6),
				roof_color if strip % 2 == 0 else Color("e5d6b5")
			)
		if index in [5, 7]:
			for crate in range(3):
				var at := Vector3((crate - 1) * 2.3, .65, size.z * .5 + 1.1)
				Geometry.box(st, at, Vector3(1.8, .7, 1.1), Color("8b653c"))
				for fruit in range(9):
					Geometry.round_part(
						st,
						at + Vector3((fruit % 3 - 1) * .48, .5, (fruit / 3 - 1) * .3),
						Vector3.ONE * .28,
						Color("d3a43d") if crate % 2 == 0 else Color("9f5137")
					)
	if index == 9:
		for tire in range(3):
			Geometry.column(
				st, Vector3(-size.x * .38, .3 + tire * .35, size.z * .5 + .8), .3, .55, .55, Color("303638"), 10
			)
	st.index()
	return st.commit()
