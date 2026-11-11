extends RefCounted
# STRAUD 6R: a fictional rear-engine GT. The classic rear-engine coupe is only a
# proportion reference (low nose between raised fenders, round lamps, one roof
# line falling to the tail, wide rear hips, short ducktail). No real badge,
# lettering or trademarked detail is reproduced.
#
# Unlike the faceted bodies of the other cars, the shell is one smooth lofted
# surface: a cross-section is evaluated at every station along the car and
# joined with analytic normals, so the paint reads as continuous sheet metal.
# Glass, seams and intakes are thin patches laid on that same surface.
# The car faces -Z; y is height above the road; the wheels sit at z = +/-AXLE.
const AXLE := 1.22
const WHEEL_CENTER_Y := 0.36
const ARCH_RADIUS := 0.41
const Z_FRONT := -2.14
const Z_REAR := 2.24
const STATIONS := 64
const HALF_SAMPLES := 16
# (z, value) keys: plan width, belt height, roof-edge width, centre-line height.
const WIDTH := [
	[-2.14, 0.68],
	[-1.95, 0.80],
	[-1.22, 0.88],
	[-0.60, 0.86],
	[0.30, 0.87],
	[1.05, 0.95],
	[1.55, 0.95],
	[2.00, 0.88],
	[2.24, 0.74]
]
const BELT := [
	[-2.14, 0.62], [-1.90, 0.76], [-1.22, 0.85], [-0.70, 0.87], [0.40, 0.87], [1.22, 0.90], [1.90, 0.86], [2.24, 0.75]
]
const EDGE := [
	[-2.14, 0.46],
	[-1.80, 0.60],
	[-1.10, 0.63],
	[-0.75, 0.64],
	[-0.40, 0.57],
	[0.00, 0.53],
	[0.50, 0.53],
	[1.00, 0.53],
	[1.50, 0.58],
	[1.90, 0.66],
	[2.24, 0.64]
]
const TOP := [
	[-2.14, 0.58],
	[-2.00, 0.66],
	[-1.50, 0.72],
	[-0.85, 0.79],
	[-0.40, 1.07],
	[-0.10, 1.24],
	[0.30, 1.28],
	[0.75, 1.20],
	[1.25, 1.04],
	[1.75, 0.91],
	[2.05, 0.90],
	[2.17, 0.93],
	[2.24, 0.83]
]


static func key(table: Array, z: float) -> float:
	# Catmull-Rom through the keys, clamped at both ends.
	if z <= table[0][0]:
		return table[0][1]
	if z >= table[-1][0]:
		return table[-1][1]
	var i := 0
	while i < table.size() - 2 and z > table[i + 1][0]:
		i += 1
	var p0: Array = table[maxi(i - 1, 0)]
	var p1: Array = table[i]
	var p2: Array = table[i + 1]
	var p3: Array = table[mini(i + 2, table.size() - 1)]
	var t: float = (z - p1[0]) / (p2[0] - p1[0])
	var m1: float = (p2[1] - p0[1]) / maxf(p2[0] - p0[0], 0.001) * (p2[0] - p1[0])
	var m2: float = (p3[1] - p1[1]) / maxf(p3[0] - p1[0], 0.001) * (p2[0] - p1[0])
	var t2 := t * t
	var t3 := t2 * t
	return (2 * t3 - 3 * t2 + 1) * p1[1] + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * p2[1] + (t3 - t2) * m2


static func arch(z: float) -> float:
	# Height of the wheel-arch opening's top edge; 0 away from the wheels.
	var top := 0.0
	for axle in [-AXLE, AXLE]:
		var d: float = z - axle
		if absf(d) < ARCH_RADIUS:
			top = maxf(top, WHEEL_CENTER_Y + sqrt(ARCH_RADIUS * ARCH_RADIUS - d * d))
	return top


# Five half-section control points, from the sill (0) to the roof centre (4).
static func controls(z: float) -> Array[Vector2]:
	var width := key(WIDTH, z)
	var belt := key(BELT, z)
	var top := key(TOP, z)
	var greenhouse := smoothstep(-0.95, -0.70, z) * (1 - smoothstep(1.45, 2.10, z))
	var fender := 0.07 * smoothstep(-2.12, -1.72, z) * (1 - smoothstep(-0.2, 1.2, z)) + 0.035 * smoothstep(-0.2, 1.2, z)
	var crest := lerpf(belt + fender, top - 0.05, greenhouse)
	var bumper := 0.30 + 0.05 * (1 - smoothstep(-2.14, -1.90, z)) + 0.08 * smoothstep(1.95, 2.24, z)
	var sill := minf(maxf(bumper, arch(z)), belt - 0.06)
	var side := minf(maxf(0.55, sill + 0.05), belt - 0.03)
	return [
		Vector2(width - 0.07, sill),
		Vector2(width, side),
		Vector2(width - 0.03, belt),
		Vector2(key(EDGE, z), crest),
		Vector2(0, top)
	]


static func half_point(c: Array[Vector2], s: float) -> Vector2:
	var f := clampf(s, 0, 1) * 4
	var i := mini(int(f), 3)
	var t := f - i
	var p0 := c[maxi(i - 1, 0)]
	var p1 := c[i]
	var p2 := c[i + 1]
	var p3 := c[mini(i + 2, 4)]
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


# A point on the shell: s runs 0 (sill) to 1 (roof centre); side is -1 or 1.
static func surface(z: float, side: float, s: float) -> Vector3:
	var p := half_point(controls(z), s)
	return Vector3(side * p.x, p.y, z)


static func normal_at(z: float, side: float, s: float) -> Vector3:
	var dz := surface(z + 0.01, side, s) - surface(z - 0.01, side, s)
	var ds := surface(z, side, minf(s + 0.01, 1)) - surface(z, side, maxf(s - 0.01, 0))
	# Along the ring the left half runs up and the right half down (see shell()).
	var n := dz.cross(ds * -side)
	if n.length_squared() < 1e-10:
		return Vector3.UP
	return n.normalized()


static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	# Godot front faces are clockwise: keep each triangle facing its outward normal.
	if (c - a).cross(b - a).dot(na + nb + nc) < 0:
		var swap := b
		b = c
		c = swap
		var swap_n := nb
		nb = nc
		nc = swap_n
	for pair in [[a, na], [b, nb], [c, nc]]:
		st.set_normal(pair[1])
		st.add_vertex(pair[0])


static func patch(car: Node3D, material: Material, rows: int, columns: int, point: Callable, lift: float) -> void:
	# point(u, v) -> [position, normal] over u,v in 0..1; lifted along the normal.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for r in range(rows + 1):
		var line := []
		for c in range(columns + 1):
			var sample: Array = point.call(float(c) / columns, float(r) / rows)
			line.append([sample[0] + sample[1] * lift, sample[1]])
		grid.append(line)
	for r in range(rows):
		for c in range(columns):
			var a: Array = grid[r][c]
			var b: Array = grid[r][c + 1]
			var d: Array = grid[r + 1][c]
			var e: Array = grid[r + 1][c + 1]
			add_tri(st, a[0], b[0], e[0], a[1], b[1], e[1])
			add_tri(st, a[0], e[0], d[0], a[1], e[1], d[1])
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	car.body.add_child(node)


static func shell(car: Node3D, paint: Material, lining: Material) -> void:
	# Ring index runs left sill -> roof centre -> right sill.
	var ring := HALF_SAMPLES * 2
	var outer := func(u: float, v: float) -> Array:
		var z := lerpf(Z_FRONT, Z_REAR, v)
		var side := -1.0 if u < 0.5 else 1.0
		var s := u * 2 if u < 0.5 else (1 - u) * 2
		return [surface(z, side, s), normal_at(z, side, s)]
	patch(car, paint, STATIONS, ring, outer, 0.0)
	# The same sheet seen from inside is black, so wheel arches and the open
	# underside show dark wheel wells instead of looking through the car.
	var inner := func(u: float, v: float) -> Array:
		var sample: Array = outer.call(u, v)
		return [sample[0], -sample[1]]
	patch(car, lining, STATIONS, ring, inner, 0.004)
	# Front fascia and tail panel close the loft.
	for end in [Z_FRONT, Z_REAR]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var c := controls(end)
		var centre := Vector3(0, (c[0].y + c[4].y) / 2, end)
		var outward := Vector3(0, 0, signf(end))
		var points: Array[Vector3] = []
		for i in range(ring + 1):
			var u := float(i) / ring
			var side := -1.0 if u < 0.5 else 1.0
			points.append(surface(end, side, u * 2 if u < 0.5 else (1 - u) * 2))
		points.append(points[0])
		for i in range(points.size() - 1):
			add_tri(st, centre, points[i], points[i + 1], outward, outward, outward)
		var cap := MeshInstance3D.new()
		cap.mesh = st.commit()
		cap.material_override = paint
		car.body.add_child(cap)


static func surface_patch(
	car: Node3D,
	material: Material,
	side: float,
	z0: Callable,
	z1: Callable,
	s0: float,
	s1: float,
	lift: float,
	rows: int = 10,
	columns: int = 6
) -> void:
	# A region of the shell bounded in s, with z limits that may slant with s.
	var region := func(u: float, v: float) -> Array:
		var s := lerpf(s0, s1, u)
		var z := lerpf(float(z0.call(s)), float(z1.call(s)), v)
		return [surface(z, side, s), normal_at(z, side, s)]
	patch(car, material, rows, columns, region, lift)


static func build(car: Node3D) -> void:
	var paint: StandardMaterial3D = car.mat(car.paint, 0.55)
	paint.roughness = 0.22
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.8
	paint.clearcoat_roughness = 0.08
	var glass: StandardMaterial3D = car.mat(Color("0d171e"), 0.7)
	glass.roughness = 0.05
	var trim: StandardMaterial3D = car.mat(Color("111519"), 0.15)
	trim.roughness = 0.55
	var seam: StandardMaterial3D = car.mat(Color("2a2f33"), 0.3)
	var metal: StandardMaterial3D = car.mat(Color("8c959b"), 0.9)
	metal.roughness = 0.25
	shell(car, paint, trim)
	for side in [-1.0, 1.0]:
		# Windscreen and rear glass are single panels across both halves.
		var flat_z0 := func(_s: float) -> float: return -0.72
		var flat_z1 := func(_s: float) -> float: return -0.16
		surface_patch(car, glass, side, flat_z0, flat_z1, 0.80, 1.0, 0.006)
		surface_patch(
			car,
			glass,
			side,
			func(_s: float) -> float: return 0.64,
			func(_s: float) -> float: return 1.36,
			0.82,
			1.0,
			0.006
		)
		# Frameless side glass: raked A-pillar edge and a C-pillar that follows the roof.
		surface_patch(
			car,
			glass,
			side,
			func(s: float) -> float: return lerpf(-0.60, -0.24, (s - 0.52) / 0.225),
			func(s: float) -> float: return lerpf(1.08, 0.56, (s - 0.52) / 0.225),
			0.52,
			0.745,
			0.006,
			14,
			5
		)
		surface_patch(
			car,
			trim,
			side,
			func(_s: float) -> float: return 0.40,
			func(_s: float) -> float: return 0.44,
			0.52,
			0.72,
			0.009,
			2,
			4
		)
		# Door shut lines, handle and the intake ahead of the rear wheel.
		for z in [-0.64, 0.62]:
			surface_patch(
				car,
				seam,
				side,
				func(_s: float) -> float: return z,
				func(_s: float) -> float: return z + 0.012,
				0.12,
				0.48,
				0.003,
				1,
				6
			)
		surface_patch(
			car,
			metal,
			side,
			func(_s: float) -> float: return 0.30,
			func(_s: float) -> float: return 0.44,
			0.40,
			0.44,
			0.004,
			2,
			2
		)
		surface_patch(
			car,
			trim,
			side,
			func(s: float) -> float: return lerpf(0.78, 0.70, (s - 0.30) / 0.18),
			func(_s: float) -> float: return 0.95,
			0.30,
			0.48,
			0.004,
			3,
			4
		)
		# Mirror on a short arm at the base of the side glass.
		var root := surface(-0.50, side, 0.52)
		car.block(root + Vector3(side * 0.05, 0.03, 0.02), Vector3(0.09, 0.03, 0.05), paint)
		var housing := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.5
		shape.height = 1.0
		shape.radial_segments = 16
		shape.rings = 8
		housing.mesh = shape
		housing.material_override = paint
		housing.transform = Transform3D(
			Basis.IDENTITY.scaled(Vector3(0.20, 0.11, 0.13)), root + Vector3(side * 0.13, 0.07, 0.03)
		)
		car.body.add_child(housing)
		# Round lamps set into the raised front fenders, tilted with the panel.
		var lamp_at := surface(-1.90, side, 0.64)
		var facing := (normal_at(-1.90, side, 0.64) + Vector3(0, 0, -0.9)).normalized()
		var lamp_basis := Basis.looking_at(facing, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
		lamp(car, lamp_at - facing * 0.012, lamp_basis, 0.118, 0.03, trim)
		lamp(car, lamp_at + facing * 0.002, lamp_basis, 0.102, 0.014, car.mat(Color("cfe6f2"), 0.3))
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.062
		torus.outer_radius = 0.078
		torus.rings = 20
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = car.mat(Color("eef8ff"), 0, true)
		ring.transform = Transform3D(lamp_basis, lamp_at + facing * 0.010)
		car.body.add_child(ring)
		# Lower front intakes and a small corner reflector.
		car.block(Vector3(side * 0.50, 0.40, Z_FRONT - 0.006), Vector3(0.34, 0.13, 0.02), trim)
		car.block(Vector3(side * 0.66, 0.53, Z_FRONT - 0.006), Vector3(0.16, 0.035, 0.015), car.mat(Color("d48a2e")))
	car.block(Vector3(0, 0.37, Z_FRONT - 0.006), Vector3(0.52, 0.09, 0.02), trim)
	# Engine-lid grille on the rear deck, slats following its slope.
	for i in range(7):
		var z := 1.72 + i * 0.05
		var deck := surface(z, 1.0, 1.0)
		var slope := atan2(key(TOP, z + 0.02) - key(TOP, z - 0.02), 0.04)
		var slat: MeshInstance3D = car.block(deck + Vector3(0, 0.006, 0), Vector3(0.80, 0.012, 0.026), trim)
		slat.rotation.x = -slope
	# Full-width tail light bar, corner clusters and the rear diffuser.
	var red: StandardMaterial3D = car.mat(Color("ff2a22"), 0, true)
	car.brake_lights.append(red)
	car.block(Vector3(0, 0.765, Z_REAR + 0.008), Vector3(1.24, 0.032, 0.02), red)
	for side in [-1.0, 1.0]:
		car.block(Vector3(side * 0.56, 0.755, Z_REAR + 0.01), Vector3(0.20, 0.06, 0.022), red)
		car.add_boost_jet(Vector3(side * 0.11, 0.44, Z_REAR + 0.04), 0.12)
		var tip := MeshInstance3D.new()
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.055
		pipe.bottom_radius = 0.055
		pipe.height = 0.10
		pipe.radial_segments = 14
		tip.mesh = pipe
		tip.material_override = metal
		tip.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(side * 0.11, 0.44, Z_REAR + 0.02))
		car.body.add_child(tip)
	car.block(Vector3(0, 0.46, Z_REAR + 0.006), Vector3(1.10, 0.10, 0.02), trim)
	car.block(Vector3(0, 0.665, Z_REAR + 0.006), Vector3(1.30, 0.03, 0.016), trim)
	preload("res://models/shared/vehicle_geometry.gd").label(
		car, "STRAUD", Vector3(0, 0.60, Z_REAR + 0.02), Color("d9dee2"), 0.0016
	)
	car.add_headlight(Vector3(0, 0.76, -1.95))
	var flap: MeshInstance3D = car.block(Vector3(0, .98, 1.81), Vector3(1.42, .085, .30), trim)
	var aero_parts: Array[MeshInstance3D] = [flap]
	car.add_active_aero(aero_parts, Vector3(0, .98, 1.68), .10, deg_to_rad(-8))


static func lamp(car: Node3D, at: Vector3, frame: Basis, radius: float, depth: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = depth
	disc.radial_segments = 24
	node.mesh = disc
	node.material_override = material
	node.transform = Transform3D(frame, at)
	car.body.add_child(node)
