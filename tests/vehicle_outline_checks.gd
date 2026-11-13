extends RefCounted
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	for index in range(5):
		var car := Factory.create(index)
		tree.root.add_child(car)
		var shell: MeshInstance3D = car.body.get_node("PaintShell")
		var mesh := shell.mesh
		var overlay := shell.material_overlay
		var count := car.body.get_child_count()
		check(overlay is ShaderMaterial, "플레이어 차체 외피에 공유 외곽선을 연결한다")
		for wheel in car.wheels:
			check(wheel.material_overlay == null, "휠에는 외곽선 패스를 추가하지 않는다")
		car.set_protection(true)
		check(shell.material_overlay == overlay, "보호색 전환이 외곽선을 끊지 않는다")
		for iteration in range(8):
			car.set_detail(100)
			check(shell.material_overlay == null, "먼 차량에는 추가 패스가 없다")
			car.set_detail(10)
			check(shell.material_overlay == overlay, "근접 재진입은 동일한 재질을 재사용한다")
		check(shell.mesh == mesh and car.body.get_child_count() == count, "메시·노드를 복제하지 않는다")
		car.traffic = true
		car.refresh_outline()
		check(shell.material_overlay == null, "투어 교통 차량은 추가 패스를 쓰지 않는다")
		car.free()
	print("5차량 외곽선 / 45m 패스 제한 / 보호색·공유 메시 / 교통 제외: ", "PASS" if failures == 0 else "FAIL")
	return failures
