extends RefCounted
# Wall-clock sampling is independent of the 1.2x game simulation tempo.
const RaceState = preload("res://scripts/race/race_state.gd")
var level := 0
var mode := 0
var last_tick := 0
var seconds := 0.0
var frames := 0
var slow_windows := 0
var viewport_size := Vector2i.ZERO
var mobile := OS.has_feature("android") or OS.has_feature("ios")


func set_mode(value: int, race: Node3D) -> void:
	last_tick = 0
	mode = posmod(value, 3)
	level = (
		(2 if race.lite_graphics else (1 if OS.has_feature("web") or mobile else 0))
		if mode == 0
		else (0 if mode == 1 else 2)
	)
	seconds = 0
	frames = 0
	slow_windows = 0
	apply(race)


func apply(race: Node3D) -> void:
	# 모바일 고화질도 넓은 폴더블 화면에서 픽셀·그림자 비용이 무제한 증가하지 않게 한다.
	var detailed_shadows := level == 0 and not mobile
	race.sun_light.directional_shadow_max_distance = [140.0 if mobile else 220.0, 120.0, 75.0][level]
	race.sun_light.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if detailed_shadows else DirectionalLight3D.SHADOW_ORTHOGONAL
	)
	race.sun_light.directional_shadow_blend_splits = detailed_shadows
	RenderingServer.directional_shadow_atlas_set_size(
		4096 if detailed_shadows else (2048 if level < 2 else 1024), false
	)
	if race.track.scenery.has_method("set_shadow_quality"):
		race.track.scenery.set_shadow_quality(level < 2)
	resize(race)


func framebuffer_size(viewport: Viewport) -> Vector2i:
	# canvas_items에서 ViewportTexture 크기는 창 배율을 중복 반영할 수 있다.
	# 논리 영역을 스트레치 변환으로 한 번만 픽셀에 대응시키며 GPU 읽기는 하지 않는다.
	return Vector2i((viewport.get_visible_rect().size * viewport.get_stretch_transform().get_scale()).round())


func resize(race: Node3D) -> void:
	var viewport := race.get_viewport()
	viewport_size = framebuffer_size(viewport)
	var factor := 1.0
	if level > 0 or mobile:
		var cap: Vector2 = [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1280, 720)][level]
		factor = minf(1, minf(cap.x / maxi(1, viewport_size.x), cap.y / maxi(1, viewport_size.y)))
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if not is_equal_approx(viewport.scaling_3d_scale, factor):
		viewport.scaling_3d_scale = factor


func tick(race: Node3D) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - last_tick) / 1000000.0 if last_tick > 0 else 0.0
	last_tick = now
	if framebuffer_size(race.get_viewport()) != viewport_size:
		resize(race)
	if mode != 0 or race.state != RaceState.RACING or race.elapsed < 6 or race.shell.portrait or dt <= 0:
		seconds = 0
		frames = 0
		slow_windows = 0
		return
	seconds += dt
	frames += 1
	if seconds < 1:
		return
	var fps := frames / seconds
	slow_windows = slow_windows + 1 if fps < 50 else 0
	seconds = 0
	frames = 0
	if slow_windows >= 2 and level < 2:
		level += 1
		slow_windows = 0
		apply(race)
