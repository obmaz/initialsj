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
func set_mode(value: int, race: Node3D) -> void:
	last_tick = 0
	mode = posmod(value,3)
	level = (2 if race.lite_graphics else (1 if OS.has_feature("web") or OS.has_feature("android") else 0)) if mode == 0 else (0 if mode == 1 else 2)
	seconds = 0
	frames = 0
	slow_windows = 0
	apply(race)
func apply(race: Node3D) -> void:
	race.sun_light.directional_shadow_max_distance = [220.0,120.0,75.0][level]
	race.sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if level > 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	race.sun_light.directional_shadow_blend_splits = level == 0
	RenderingServer.directional_shadow_atlas_set_size(4096 if level == 0 else (2048 if level == 1 else 1024),false)
	if race.track.scenery.has_method("set_shadow_quality"): race.track.scenery.set_shadow_quality(level < 2)
	resize(race)
func resize(race: Node3D) -> void:
	var viewport := race.get_viewport()
	viewport_size = Vector2i(viewport.get_texture().get_size())
	var factor := 1.0
	if level > 0:
		var cap := Vector2(1600,900) if level == 1 else Vector2(1280,720)
		factor = minf(1,minf(cap.x/maxi(1,viewport_size.x),cap.y/maxi(1,viewport_size.y)))
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if not is_equal_approx(viewport.scaling_3d_scale,factor): viewport.scaling_3d_scale = factor
func tick(race: Node3D) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now-last_tick)/1000000.0 if last_tick > 0 else 0.0
	last_tick = now
	if Vector2i(race.get_viewport().get_texture().get_size()) != viewport_size: resize(race)
	if mode != 0 or race.state != RaceState.RACING or race.elapsed < 6 or race.shell.portrait or dt <= 0:
		seconds = 0
		frames = 0
		slow_windows = 0
		return
	seconds += dt
	frames += 1
	if seconds < 1: return
	var fps := frames/seconds
	slow_windows = slow_windows+1 if fps < 50 else 0
	seconds = 0
	frames = 0
	if slow_windows >= 2 and level < 2:
		level += 1
		slow_windows = 0
		apply(race)
