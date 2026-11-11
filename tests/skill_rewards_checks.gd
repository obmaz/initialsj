extends RefCounted
const Rewards = preload("res://scripts/race/driving_rewards.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func slide(rewards: RefCounted, curve: float, key: String) -> void:
	for i in range(60):
		rewards.drift_step(1.0 / 60, true, 0.3, 40, 40.0 / 60, curve, true, key)


func run(_tree: SceneTree) -> int:
	var rewards := Rewards.new()
	slide(rewards, 0.008, "corner")
	check(rewards.drift_step(.016, false, .05, 40, .64, 0, true, "exit") > 0, "빠른 실제 코너의 깨끗한 탈출을 보상한다")
	check(rewards.exit_boost > 0 and rewards.clean_exits == 1, "짧은 탈출 부스트와 성공 수를 기록한다")
	slide(rewards, .008, "corner")
	check(rewards.drift_step(.016, false, .05, 40, .64, 0, true, "exit") == 0, "같은 코너를 오가며 보상을 반복할 수 없다")
	slide(rewards, 0, "straight")
	check(rewards.drift_step(.016, false, .05, 40, .64, 0, true, "exit") == 0, "직선 버튼 반복은 코너 성공으로 세지 않는다")
	slide(rewards, .008, "crash")
	rewards.drift_step(.016, false, .05, 40, .64, 0, false, "exit")
	check(rewards.exit_boost == 0 and rewards.clean_exits == 1, "충돌·보호·이탈 후 드리프트는 보상을 취소한다")
	rewards.reset()
	check(rewards.clean_exits == 0 and rewards.rewarded_corners.is_empty(), "재시작은 성공 이력과 보상을 함께 비운다")
	check(not rewards.observe_traffic(10, 10, 3, 0, true), "앞차를 발견한 것만으로 보상을 주지 않는다")
	check(rewards.observe_traffic(10, -2, 3, 0, true), "가까운 옆 간격으로 실제 추월한 순간을 보상한다")
	check(not rewards.observe_traffic(10, -3, 3, 0, true), "같은 차량은 한 번만 보상한다")
	check(not rewards.observe_traffic(11, -2, 3, 0, true), "처음부터 뒤에 있던 차는 추월로 세지 않는다")
	rewards.observe_traffic(12, 8, 3, 0, true)
	check(rewards.observe_traffic(12, -1, 3, 0, true) and rewards.pass_chain == 2, "5초 안의 다음 근접 추월은 연속 보상을 높인다")
	rewards.observe_traffic(13, 8, 3, 0, true)
	check(not rewards.observe_traffic(13, -1, 3, 0, false), "충돌·보호 중 추월은 보상하지 않는다")
	rewards.tick(6)
	check(rewards.pass_chain == 0 and rewards.max_pass_chain == 2, "연속 추월 제한 시간과 경기 최고 연속 횟수를 구분한다")
	print("드리프트 탈출 / 실제 코너·속도 / 중복·충돌 보상 방지: ", "PASS" if failures == 0 else "FAIL")
	return failures
