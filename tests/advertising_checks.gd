extends RefCounted
const Ads = preload("res://scripts/environment/advertisement_library.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	Ads.deck.clear()
	var seen := {}
	var order: Array[int] = []
	for i in range(Ads.count()):
		var index: int = Ads.choose()
		check(not seen.has(index), "모든 광고를 사용하기 전에 같은 광고가 반복되면 안 된다")
		seen[index] = true
		order.append(index)
	var second: Array[int] = []
	for i in range(Ads.count()):
		second.append(Ads.choose())
	check(order != second and seen.size() == 48, "48종을 무작위 새 순서로 섞어야 한다")
	var categories := {}
	for index in range(36):
		var info: Dictionary = Ads.selection(index)
		categories[info.category] = int(categories.get(info.category, 0)) + 1
		check(info.tile.x < info.grid.x and info.tile.y < info.grid.y, "각 광고의 선택 영역은 원본 아틀라스 안에 있어야 한다")
		check(Ads.material(index).get_shader_parameter("ad_atlas") == info.atlas, "인쇄 재질은 해당 광고의 원본을 사용해야 한다")
	check(categories.size() == 12, "프로젝트2종과 상품10종을 각각 구분해야 한다")
	for name in categories:
		check(categories[name] == 3, "모든 프로젝트·상품에 서로 다른3종이 있어야 한다: " + str(name))
	for index in range(Ads.count()):
		var info: Dictionary = Ads.selection(index)
		var printed: ShaderMaterial = Ads.prop_material(index)
		check(
			(
				printed.get_shader_parameter("ad_atlas") == info.atlas
				and printed.get_shader_parameter("ad_tile") == info.tile
			),
			"일반 간판도 지정한 광고 원본과 그림 한 칸을 정확히 사용해야 한다"
		)
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 4)
	race.restart()
	var ads: Node3D = race.track.scenery.landmarks
	var before: Array[int] = []
	for record in ads.billboard_manifest:
		before.append(record.ad_index)
	for i in range(5):
		await tree.process_frame
	var stable: Array[int] = []
	for record in ads.billboard_manifest:
		stable.append(record.ad_index)
	check(before == stable, "주행 중에는 간판 그림이 깜빡이거나 바뀌면 안 된다")
	race.restart()
	var after: Array[int] = []
	for record in ads.billboard_manifest:
		after.append(record.ad_index)
	check(before != after, "동일 코스 재시작에도 광고 순서가 바뀌어야 한다")
	race.queue_free()
	await tree.process_frame
	print("프로젝트6종·상품30종 / 48종 중복 억제 / 일반 간판 인쇄 재질 / 주행 고정·재시작 무작위: ", "PASS" if failures == 0 else "FAIL")
	return failures
