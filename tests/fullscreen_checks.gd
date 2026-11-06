extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	if DisplayServer.get_name() == "headless":
		check(not race.is_fullscreen() and race.fullscreen_label() == "ENTER FULLSCREEN","Headless adapter must not invent a fullscreen window")
		race.open_settings()
		race.sync_fullscreen_button(Rect2(365,388,550,78))
		race.toggle_fullscreen()
		check(race.state == "settings","Fullscreen control must preserve the settings screen")
	for active_state in ["racing","countdown"]:
		race.state = active_state
		race._on_web_fullscreen([true,true])
		race._on_web_fullscreen([false,false])
		check(race.state == "paused" and race.resume_state == active_state,"Browser fullscreen exit must pause "+active_state)
		race.navigate_back()
		check(race.state == "paused","One Back gesture producing both exit and popstate must not immediately resume")
		race.web_back_after_fullscreen_until = 0
		race.navigate_back()
		check(race.state == active_state,"A later Back must still resume normally")
	race.state = "racing"
	race._on_web_fullscreen([true,true])
	race.pause_tour()
	race._on_web_fullscreen([true,false])
	race.navigate_back()
	check(race.state == "paused","PWA DOM-fullscreen exit must remain paused even if app mode is still fullscreen and focus-out arrived first")
	race.open_settings()
	race._on_web_fullscreen([true,true])
	race._on_web_fullscreen([false,false])
	check(race.state == "settings","Settings EXIT FULLSCREEN must remain in settings")
	race.queue_free()
	await tree.process_frame
	print("Fullscreen exit / race pause / Back event coalescing / settings checks: ","PASS" if failures == 0 else "FAIL")
	return failures
