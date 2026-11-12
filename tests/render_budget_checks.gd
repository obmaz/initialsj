extends RefCounted
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.state = "racing"
	race.elapsed = 10
	var budget = race.render_budget
	budget.set_mode(0, race)
	budget.level = 0
	for frame in range(65):
		budget.last_sample_usec = Time.get_ticks_usec() - 33334
		budget.tick(race)
	check(budget.level == 1, "Sustained 30 FPS must lower automatic quality after two windows")
	for frame in range(65):
		budget.last_sample_usec = Time.get_ticks_usec() - 33334
		budget.tick(race)
	check(budget.level == 2, "Automatic quality must reach the fast setting if poor pacing continues")
	check(race.sun_light.directional_shadow_max_distance == 75, "Fast quality must shorten the expensive shadow range")
	budget.set_mode(1, race)
	for frame in range(65):
		budget.last_sample_usec = Time.get_ticks_usec() - 33334
		budget.tick(race)
	check(budget.level == 0, "Manual high quality must honor the player's choice")
	var saved_size := tree.root.size
	var saved_content_size := tree.root.content_scale_size
	var saved_content_mode := tree.root.content_scale_mode
	tree.root.content_scale_size = Vector2i(1280, 720)
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	budget.is_mobile_platform = true
	tree.root.size = Vector2i(2340, 1800)
	await tree.process_frame
	budget.set_mode(1, race)
	var pixels: Vector2 = Vector2(budget.framebuffer_size_px) * tree.root.scaling_3d_scale
	check(pixels.x <= 1920.1 and pixels.y <= 1080.1 and budget.level == 0, "모바일 고화질은 화면 비율을 유지하며 1920×1080 안에서 렌더한다")
	check(maxf(pixels.x / 1920, pixels.y / 1080) > .999, "큰 화면을 상한보다 불필요하게 더 축소하지 않는다")
	check(
		(
			race.sun_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL
			and race.sun_light.directional_shadow_max_distance == 140
		),
		"모바일 고화질은 가까운 그림자를 유지하면서 이중 그림자 패스를 제거한다"
	)
	tree.root.size = Vector2i(1280, 720)
	budget.resize(race)
	check(tree.root.scaling_3d_scale == 1, "상한보다 작은 모바일 화면을 불필요하게 축소하지 않는다")
	budget.is_mobile_platform = false
	tree.root.size = saved_size
	tree.root.content_scale_size = saved_content_size
	tree.root.content_scale_mode = saved_content_mode
	budget.set_mode(0, race)
	race.state = "paused"
	budget.last_sample_usec = Time.get_ticks_usec() - 2000000
	budget.tick(race)
	check(
		budget.sample_frame_count == 0 and budget.sample_elapsed_seconds == 0,
		"Pauses and background stalls must not degrade automatic quality"
	)
	race.lite_graphics = true
	budget.set_mode(0, race)
	check(budget.level == 2, "Low-memory consoles must start on the lightest rendering level")
	race.queue_free()
	await tree.process_frame
	print("Adaptive render quality / manual override / paused timing: ", "PASS" if failures == 0 else "FAIL")
	return failures
