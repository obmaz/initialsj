extends RefCounted
const Store = preload("res://scripts/vehicles/customization_store.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var normal := Factory.create(0)
	var toon := Factory.create(1)
	tree.root.add_child(normal)
	tree.root.add_child(toon)
	var a := Store.defaults(0)
	var b := Store.defaults(1)
	a.shading = 0
	b.shading = 1
	b.toon_strength = 100
	Custom.apply(normal, a, 0)
	Custom.apply(toon, b, 1)
	var normal_shell: MeshInstance3D = normal.body.get_node("PaintShell")
	var toon_shell: MeshInstance3D = toon.body.get_node("PaintShell")
	var normal_material: ShaderMaterial = normal_shell.material_override
	var toon_material: ShaderMaterial = toon_shell.material_override
	check(
		normal_material != toon_material and normal_material.shader == toon_material.shader,
		"셰이더 코드만 공유하고 재질 값은 차량별로 독립적이다"
	)
	check(not normal_material.get_shader_parameter("toon_enabled"), "일반 모드 차체는 연속 명암을 사용한다")
	check(
		(
			toon_material.get_shader_parameter("toon_enabled")
			and toon_material.get_shader_parameter("toon_strength") == 1.0
		),
		"툰 강도100이 차체 셰이더에 반영된다"
	)
	check(normal_shell.material_overlay == null and toon_shell.material_overlay != null, "일반 모드는 외곽선을 숨기고 툰만 표시한다")
	var outline: Material = toon_shell.material_overlay
	var mesh: Mesh = toon_shell.mesh
	for i in range(3):
		b.shading = 0
		Custom.apply(toon, b, 1)
		b.shading = 1
		Custom.apply(toon, b, 1)
	check(toon_shell.material_overlay == outline and toon_shell.mesh == mesh, "스타일 전환은 원본 메시와 외곽선 재질을 재사용한다")
	check(not normal_material.get_shader_parameter("toon_enabled"), "다른 차량의 스타일은 바뀌지 않는다")
	toon.set_protection(true)
	check(toon_shell.material_override.get_shader_parameter("toon_strength") == 1.0, "무적 보호색도 차량별 툰 강도를 유지한다")
	toon.set_protection(false)
	var store := Store.new()
	store.path = "user://vehicle_shading_checks.cfg"
	check(store.save(0, a) == OK and store.save(1, b) == OK, "차량별 스타일을 저장한다")
	var restored := Store.new()
	restored.path = store.path
	restored.load_config()
	check(
		(
			restored.selection(0).shading == 0
			and restored.selection(1).shading == 1
			and restored.selection(1).toon_strength == 100
		),
		"서로 다른 차량의 설정이 독립 복원된다"
	)
	check(
		(
			Store.sanitize({"shading": "bad", "toon_strength": -10}, 0).shading == 0
			and Store.sanitize({"toon_strength": -10}, 0).toon_strength == 0
		),
		"손상된 스타일은 기본값, 강도는 범위 안으로 복구한다"
	)
	DirAccess.remove_absolute(store.path)
	normal.free()
	toon.free()
	print("차량별 일반/툰·강도·독립 재질·보호색·저장·원본 메시 보존: ", "PASS" if failures == 0 else "FAIL")
	return failures
