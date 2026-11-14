extends RefCounted
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1


func click(race: Node3D, rect: Rect2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = rect.get_center() * race.hud.ui_scale() + race.hud.ui_offset()
	race.hud.handle_pointer(event)
	event.pressed = false
	race.hud.handle_pointer(event)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	check(race.state == "menu", "Startup must offer modes before vehicle selection")
	var initial_sound: bool = race.sound_enabled
	click(race, race.hud.HOME_SETTINGS)
	click(race, race.hud.SettingsAudio.toggle_rect(race.hud, false))
	click(race, race.hud.SETTINGS_CLOSE)
	check(
		race.state == "menu" and race.sound_enabled != initial_sound,
		"Settings must return to the mode menu and retain the chosen value"
	)
	# Every switch persists at once, and only an explicit choice overrides the system motion preference.
	race.preferences_path = "user://preferences_check.cfg"
	race.save_records = true
	race.sound_enabled = true
	race.motion_reduced = true
	race.motion_user_set = false
	race.toggle_sound()
	var stored := ConfigFile.new()
	check(
		stored.load(race.preferences_path) == OK and stored.get_value("preferences", "sound") == false,
		"A sound switch must be written when toggled, not only when Settings closes"
	)
	check(
		not stored.has_section_key("preferences", "reduced_motion"),
		"The system reduced-motion preference must not be stored as the player's choice"
	)
	race.toggle_motion()
	stored = ConfigFile.new()
	check(
		stored.load(race.preferences_path) == OK and stored.get_value("preferences", "reduced_motion") == false,
		"A motion switch on a dialog must be written immediately"
	)
	race.sound_enabled = true
	race.motion_reduced = true
	race.motion_user_set = false
	race.load_preferences()
	check(
		not race.sound_enabled and not race.motion_reduced and race.motion_user_set,
		"A stored choice must be restored and then take priority over the system preference"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(race.preferences_path))
	race.save_records = false
	race.sound_enabled = not initial_sound
	race.motion_reduced = false
	race.motion_user_set = false
	click(race, race.hud.HOME_TRACK)
	check(race.state == "courses", "Track menu must offer both courses before the garage")
	click(race, race.hud.COURSE_FUJI)
	click(race, race.hud.rev3.rect("continue"))
	check(race.state == "ready" and race.mode == "track", "Track selection must lead to the shared garage")
	check(
		race.track.previews.is_empty() and race.track.scenery.theme == "fuji",
		"Fuji must use its own scenery and have no route forks"
	)
	var length: float = race.track.length
	var low := INF
	var high := -INF
	var left_curve := 0.0
	var right_curve := 0.0
	for sample in range(500):
		var d := length * sample / 500
		var y: float = race.track.point(d).y
		low = minf(low, y)
		high = maxf(high, y)
		var curve: float = race.track.curvature(d)
		left_curve = minf(left_curve, curve)
		right_curve = maxf(right_curve, curve)
	check(
		length > 4000 and high - low > 30 and left_curve < -0.012 and right_curve > 0.012,
		"Fuji must have a long elevated course and substantial bends in both directions"
	)
	check(
		race.track.active.in_tunnel(race.track.active.underpass_span().x + 120) and not race.track.active.in_tunnel(80),
		"The ridge tunnel must have a bounded real road span"
	)
	var portal: float = race.track.active.underpass_span().x
	check(
		race.track.active.excavation_depth(portal + 80) > 6 and race.track.active.excavation_depth(portal - 190) < 0.01,
		"Underpass must cut the road below surrounding ground"
	)
	check(
		(
			race.track.point(portal - 180).y - race.track.point(portal + 20).y > 4
			and race.track.point(portal + 420).y - race.track.point(portal + 220).y > 4
		),
		"Underpass must have a real descent and an ascending exit"
	)
	for d in [-5.0, 0.0, 80.0, length - 1]:
		check(
			race.track.point(d).distance_to(race.track.point(d + length)) < 0.002,
			"Circuit positions must wrap continuously"
		)
	check(
		absf(wrapf(race.track.heading(-0.1) - race.track.heading(0.1), -PI, PI)) < 0.01,
		"Start/finish tangent must be continuous"
	)
	var active := 0
	for r in race.rivals:
		if r.active:
			active += 1
	var ranks := {race.race_position(): true}
	for rival in race.rivals:
		if rival.active:
			ranks[race.competitor_position(rival.id)] = true
	check(ranks.size() == 8, "Tied grid rows must still give every competitor a unique place")
	check(active == 7 and race.race_position() == 8, "Track must have a fixed grid of eight cars")
	race.state = "racing"
	click(race, race.hud.PAUSE_BUTTON)
	check(race.state == "paused", "The visible pause button must work by touch")
	click(race, race.hud.START_BUTTON)
	check(race.state == "racing", "The pause dialog must resume the same race")
	# Both circuits use real bodies; their driving and contacts have dedicated checks.
	race.choose_mode("track", 1)
	length = race.track.length
	race.restart()
	race.state = "racing"
	for r in race.rivals:
		r.active = false
	race.distance = 450
	race.lane = 0
	race.speed = 38
	race.drift_latched = true
	race.drift_sign = 1
	for frame in range(40):
		race.step(1.0 / 60, 0, false, true, false)
	check(not race.drifting, "Unwinding steering with recovered grip must settle a drift on gentle circuit bends")
	# Lap counting and the three-lap finish need a real drive around the loop: see suncoast_world_checks.gd.
	race.restart()
	race.state = "racing"
	race.distance = 80 + length
	race.speed = 60
	var other = race.rivals[0]
	other.distance = 83.2
	other.lane = race.lane
	other.speed = 40.0
	check(
		absf(race.relative_gap(other.distance, race.distance) - 3.2) < 0.001,
		"Physical traffic gaps must wrap independently of lap progress"
	)
	check(
		Catalog.record_key(0, "track") != Catalog.record_key(0, "tour"), "Circuit and Tour records must stay separate"
	)
	race.choose_mode("tour")
	check(
		race.mode == "tour" and not race.track.active.closed_loop and race.track.previews.size() == 2,
		"Tour must retain its open branching roads after switching modes"
	)
	print("Mode / circuit checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await tree.process_frame
	return failures
