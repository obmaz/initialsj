extends RefCounted
# A course rebuild freezes the frame, so the transition must show a loading card first.
const Card = preload("res://scripts/ui/loading_card.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

class Recorder extends CanvasLayer:
	var busy := false
	var race: Node3D
	var seen: Array[String] = []
	func play(action: Callable) -> void:
		seen.append(race.loading_title)
		race.loading_title = ""
		action.call()

func run(tree: SceneTree) -> int:
	var version_name = ProjectSettings.get_setting("application/config/version")
	var version_code = ProjectSettings.get_setting("application/config/build_number")
	var Version = preload("res://scripts/platform/app_version.gd")
	ProjectSettings.set_setting("application/config/version","1.0.12")
	ProjectSettings.set_setting("application/config/build_number",12)
	check(Version.label() == "v1.0.12 (12)","Android 표시에는 실제 versionName과 versionCode가 함께 있어야 한다")
	ProjectSettings.set_setting("application/config/version","0.1+abcdef0")
	ProjectSettings.set_setting("application/config/build_number",0)
	check(Version.label() == "v0.1+abcdef0","웹 표시는 웹 빌드 식별자를 유지하고 Android 번호를 섞지 않아야 한다")
	ProjectSettings.set_setting("application/config/version",version_name)
	ProjectSettings.set_setting("application/config/build_number",version_code)
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	r.set_physics_process(false)
	r.save_records = false
	check(r.mode_loading_title("tour") == "COAST TOUR" and r.mode_loading_title("track",0) == "FUJI LAKESIDE" and r.mode_loading_title("track",1) == "SUNCOAST SPEEDWAY","Each mode must name itself on the loading card")
	var recorder := Recorder.new()
	recorder.race = r
	r.screen_transition = recorder
	r.mode = "tour"
	r.navigate_to_mode("tour")
	await tree.process_frame
	check(recorder.seen.size() == 1 and recorder.seen[0] == "","Re-opening the current mode needs no loading card")
	r.navigate_to_mode("track",1)
	await tree.process_frame
	check(recorder.seen.size() == 2 and recorder.seen[1] == "SUNCOAST SPEEDWAY","Rebuilding a course must show its loading card")
	r.screen_transition = null
	recorder.free()
	r.navigate_to_mode("track",0)
	await tree.process_frame
	check(r.loading_title == "","Without a transition no stale loading title may remain")
	var card = Card.new()
	tree.root.add_child(card)
	check(not card.visible,"The loading card starts hidden")
	card.begin("FUJI LAKESIDE")
	check(card.visible and card.progress > 0 and card.progress < 0.2,"The card must open near the start of the bar")
	card.advance(2,0.7)
	check(is_equal_approx(card.progress,0.7) and card.step == 2,"The card must report each build step")
	card.advance(9,3.0)
	check(card.progress == 1.0 and card.step == card.STEPS.size()-1,"Progress and step must stay within range")
	card.finish()
	check(not card.visible,"The card must hide when loading ends")
	card.queue_free()
	r.queue_free()
	await tree.process_frame
	print("Loading card / mode loading titles / no stale titles: ","PASS" if failures == 0 else "FAIL")
	return failures
