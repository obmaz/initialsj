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
	for choice in [["tour", 0], ["track", 0], ["track", 1]]:
		race.choose_mode(choice[0], choice[1])
		race.state = "racing"
		race.motion_reduced = false
		race.surface.pad_time = 1
		race.surface.pad_flash = 1.1
		check(race.hud.boost_feedback_strength() > 0.99, "Every game mode must show the pad activation pulse")
		check(race.hud.boost_feedback_label() == "BOOST PAD", "A normal pad must have a readable boost label")
		race.surface.pad_flash = 0.3
		check(
			race.hud.boost_feedback_strength() < 0.1,
			"The initial screen pulse must fade quickly instead of flashing throughout the boost"
		)
		race.surface.pad_time = 0
		race.surface.lane_active = true
		check(
			race.hud.boost_feedback_label() == "BOOST LANE",
			"A sustained lane boost must stay distinguishable from a one-shot pad"
		)
		race.motion_reduced = true
		check(
			race.hud.boost_feedback_strength() == 0 and race.hud.boost_feedback_label() == "BOOST LANE",
			"Reduced motion must retain the useful label without animated peripheral effects"
		)
		race.motion_reduced = false
		for state in ["paused", "countdown", "menu", "courses", "ready", "settings", "finished", "failed"]:
			race.state = state
			check(
				race.hud.boost_feedback_strength() == 0 and race.hud.boost_feedback_label().is_empty(),
				"Boost overlays must not leak onto " + state
			)
		race.state = "racing"
		race.surface.cancel_boost()
		check(
			race.hud.boost_feedback_strength() == 0 and race.hud.boost_feedback_label().is_empty(),
			"Leaving/cancelling road boosts must clear their overlays"
		)
	# Game messages pop in only at the start of their life, and never stack on one line.
	check(
		(
			is_equal_approx(race.hud.fresh(1.1, 1.1), 1.0)
			and race.hud.fresh(0.5, 1.1) == 0.0
			and race.hud.fresh(1.1 - 0.09, 1.1) > 0.4
		),
		"A message must pop in during its first moments only"
	)
	check(
		(
			race.hud.BANNER_Y + race.hud.BANNER_STEP * 3 < race.hud.STATUS_Y + race.hud.STATUS_STEP * 2
			and race.hud.BANNER_STEP >= 40
			and race.hud.STATUS_STEP >= 34
		),
		"Banner and status messages must keep their own non-overlapping lanes"
	)
	race.queue_free()
	await tree.process_frame
	print(
		"Road boost overlay / pad versus lane labels / screen states / reduced motion: ",
		"PASS" if failures == 0 else "FAIL"
	)
	return failures
