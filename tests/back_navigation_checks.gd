extends RefCounted
var failures := 0
class BusyTransition extends CanvasLayer:
	var busy := true
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	check(not race.navigate_back() and race.state == "menu","Main-menu Back must allow normal browser exit")
	race.open_courses()
	check(race.navigate_back() and race.state == "menu","Course-selection Back must return to the main menu")
	race.choose_mode("track",1)
	check(race.navigate_back() and race.state == "courses","Track garage Back must return to circuit selection")
	race.choose_mode("tour")
	check(race.navigate_back() and race.state == "menu","Tour garage Back must return to the main menu")
	race.open_settings()
	check(race.navigate_back() and race.state == "menu","Settings Back must return to the screen that opened it")
	race.open_garage()
	race.open_settings()
	check(race.navigate_back() and race.state == "ready","Settings must also return to the garage when opened there")
	for active_state in ["countdown","racing"]:
		race.state = active_state
		race.speed = 60
		race.distance = 400
		race.hud.fingers[0] = "gas"
		check(race.navigate_back() and race.state == "paused","Hardware Back must pause "+active_state)
		check(race.hud.fingers.is_empty(),"Back-pause must release driving touch inputs")
		check(race.resume_state == active_state and race.speed == 60 and race.distance == 400,"Back-pause must preserve race progress")
		check(race.navigate_back() and race.state == active_state,"Back on the pause dialog must resume its original state")
	for result in ["finished","failed"]:
		race.state = result
		check(race.navigate_back() and race.state == "ready","Result Back must return to vehicle selection")
	race.state = "racing"
	race.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(race.state == "paused","Native Android back notification must use the same pause action")
	race.shell.on_back([])
	check(race.state == "racing","The JavaScript back callback must reach the shared state handler")
	race.state = "courses"
	var transition := BusyTransition.new()
	race.screen_transition = transition
	for attempt in range(8):
		check(race.navigate_back() and race.state == "courses","Rapid Back must be consumed while a screen transition is busy")
	race.screen_transition = null
	transition.free()
	# A transition that finishes after the device rotated must not run unseen
	# behind the rotate guide; it waits paused until landscape returns.
	race.shell.portrait = true
	race.restart()
	check(race.state == "paused" and race.resume_state == "countdown","A race started while portrait must wait paused instead of counting down under the rotate guide")
	race.resume_tour()
	check(race.state == "paused","Resume must stay blocked while portrait")
	race.shell.portrait = false
	race.resume_tour()
	check(race.state == "countdown","Rotating back to landscape must allow the manual resume")
	race.queue_free()
	await tree.process_frame
	print("Hardware Back / screen history / pause / repeated input checks: ","PASS" if failures == 0 else "FAIL")
	return failures
