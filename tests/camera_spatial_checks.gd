extends RefCounted
const CameraState = preload("res://scripts/effects/chase_camera_state.gd")
const Nearby = preload("res://scripts/audio/proximity_audio_state.gd")
const SpatialPlayer = preload("res://scripts/audio/spatial_driving_audio.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func position_body(body: CharacterBody3D, feet: Vector3, forward: Vector3, velocity: Vector3) -> void:
	body.reset_pose(feet, forward)
	body.grounded = true
	body.velocity = velocity


func run(tree: SceneTree) -> int:
	var camera := CameraState.new()
	var before := 0.0
	for frame in range(120):
		camera.advance(1.0 / 60, 60, 1.0, 30, true, false)
		check(
			camera.look_yaw >= before and camera.look_yaw <= CameraState.MAX_LOOK + .0001, "코너 시선은 오버슈트 없이 제한 각도에 수렴한다"
		)
		before = camera.look_yaw
	check(camera.look_yaw > .19 and camera.pullback <= .32, "고속·가속 시선과 거리를 작은 범위로 유지한다")
	for frame in range(10):
		camera.advance(.5, 80, -1.0, -30, true, false)
	check(is_finite(camera.look_yaw) and absf(camera.look_yaw) <= CameraState.MAX_LOOK, "낮은 프레임에서도 카메라 스프링은 발산하지 않는다")
	camera.advance(.016, 80, .5, 30, true, true)
	check(camera.look_yaw == 0 and camera.pullback == 0, "동작 줄이기는 추가 시선 회전과 가감속 거리 변화를 해제한다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 1)
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	var corner := 300.0
	for d in range(400, 1600, 40):
		if absf(race.track.curvature(d)) > absf(race.track.curvature(corner)):
			corner = d
	race.world_race.teleport(0, corner, 0)
	var player: CharacterBody3D = race.world_race.player_body
	var forward: Vector3 = player.forward_direction()
	var right: Vector3 = player.global_basis.x
	player.grounded = true
	player.velocity = forward * 50
	race.speed = 50
	race.place_cars()
	race.update_camera(1)
	var expected: float = race.world_race.camera_state.preview_angle(race, forward)
	check(absf(expected) > .01, "실제 곡선 구간으로 시선 예고를 검사한다")
	for frame in range(60):
		race.update_camera(1.0 / 60)
	check(
		absf(race.world_race.camera_state.look_yaw) <= .2 and race.world_race.camera_state.look_yaw * expected >= 0,
		"실제 도로 곡선과 같은 쪽을 바라본다"
	)
	var frozen: Transform3D = race.camera.global_transform
	race.state = "paused"
	race.update_camera(1)
	check(race.camera.global_transform == frozen, "일시정지하면 카메라를 그대로 유지한다")
	race.state = "racing"
	race.world_race.teleport(0, 300, 0)
	forward = player.forward_direction()
	right = player.global_basis.x
	player.grounded = true
	player.velocity = forward * 50
	race.speed = 50
	race.place_cars()
	race.update_camera(1)
	var other: CharacterBody3D = race.world_race.bodies[1]
	race.rivals[0].active = true
	var origin: Vector3 = player.feet_position()
	position_body(other, origin + forward * 1.2 + right * 3, forward, forward * 20)
	race.proximity_audio.update(race, .05)
	var serial: int = race.proximity_audio.serial
	position_body(other, origin - forward * .3 + right * 3, forward, forward * 20)
	race.proximity_audio.update(race, .05)
	check(
		(
			race.proximity_audio.serial == serial + 1
			and race.proximity_audio.pass_level > .01
			and race.proximity_audio.pass_pan > 0
		),
		"실제 우측 근접 추월은 오른쪽 통과음을 한 번 만든다"
	)
	serial = race.proximity_audio.serial
	race.proximity_audio.update(race, .05)
	check(race.proximity_audio.serial == serial, "같은 추월 순간을 연속 프레임에서 반복 재생하지 않는다")
	var buses := AudioServer.bus_count
	var audio := SpatialPlayer.new()
	race.add_child(audio)
	audio.update(race.proximity_audio, true)
	check(
		AudioServer.bus_count == buses + 2 and audio.get_child_count() == 2 and audio.pass_sound.playing,
		"네이티브는 두 보이스·두 패닝 버스만 사용한다"
	)
	check(audio.panners[0].pan > 0, "웹과 네이티브가 같은 우측 패닝 값을 사용한다")
	race.proximity_audio.draft_level = .03
	audio.update(race.proximity_audio, true)
	check(audio.draft_sound.playing and audio.draft_sound.max_polyphony == 1, "후류 보이스도 하나만 반복 재생한다")
	audio.update(race.proximity_audio, false)
	check(not audio.draft_sound.playing and not audio.pass_sound.playing, "음소거·일시정지에서는 공간 음향 두 층을 모두 멈춘다")
	audio.update(race.proximity_audio, true)
	check(not audio.pass_sound.playing, "재개해도 이미 지난 통과음을 다시 재생하지 않는다")
	audio.free()
	check(AudioServer.bus_count == buses, "음향 노드 해제 시 자신이 만든 패닝 버스도 해제한다")
	race.proximity_audio.reset()
	position_body(other, origin + forward * 20, forward, forward * 20)
	race.drafting = true
	race.throttling = true
	race.draft_charge = 1
	for frame in range(60):
		race.proximity_audio.update(race, 1.0 / 60)
	check(
		race.proximity_audio.draft_level > .05 and absf(race.proximity_audio.draft_pan) < .3,
		"실제 앞차의 후류 안에서만 방향성 바람이 커진다"
	)
	position_body(other, origin + forward * 20 + Vector3.UP * 10, forward, forward * 20)
	for frame in range(60):
		race.proximity_audio.update(race, 1.0 / 60)
	check(
		race.proximity_audio.draft_level < .001 and race.proximity_audio.observations.is_empty(),
		"위쪽 다른 도로의 차량은 후류·추월 대상으로 잡지 않는다"
	)
	race.proximity_audio.reset()
	position_body(other, origin - forward * 20 + right * 3, forward, forward * 20)
	race.proximity_audio.update(race, .016)
	serial = race.proximity_audio.serial
	position_body(other, origin + forward * 20 + right * 3, forward, forward * 20)
	race.proximity_audio.update(race, .016)
	check(race.proximity_audio.serial == serial, "상대의 순간이동은 근접 통과로 오인하지 않는다")
	var bounded := Nearby.new()
	for id in range(200):
		bounded.observe(id, 30, 3, 20, -.7, .016)
	check(bounded.observations.size() == Nearby.MAX_OBSERVATIONS, "관측 캐시는 경기 길이나 교통량에 비례해 늘지 않는다")
	race.world_race.teleport(0, 400)
	check(
		race.world_race.camera_state.look_yaw == 0 and race.proximity_audio.observations.is_empty(),
		"리스폰은 카메라와 공간 음향의 이전 관측을 지운다"
	)
	race.choose_mode("tour")
	race.state = "racing"
	race.world_race.teleport(0, race.track.active.length - 2)
	check(
		race.world_race.camera_state.preview_angle(race, race.world_race.player_body.forward_direction()) == 0,
		"투어 분기 직전에는 미선택 도로를 미리 바라보지 않는다"
	)
	var traffic: Array = tree.get_nodes_in_group("tour_road_traffic")
	var checked_traffic := false
	for car in traffic:
		if car.clock != race or car.road != race.track.active:
			continue
		car.set_physics_process(false)
		car.activated = true
		race.world_race.teleport(0, 200, 0)
		player = race.world_race.player_body
		forward = player.forward_direction()
		right = player.global_basis.x
		player.grounded = true
		player.velocity = forward * 50
		race.speed = 50
		origin = player.feet_position()
		position_body(car, origin + forward * 1.2 - right * 3, forward, forward * 20)
		race.proximity_audio.update(race, .05)
		serial = race.proximity_audio.serial
		position_body(car, origin - forward * .3 - right * 3, forward, forward * 20)
		race.proximity_audio.update(race, .05)
		check(
			race.proximity_audio.serial == serial + 1 and race.proximity_audio.pass_pan < 0,
			"일반 투어 차량에도 실제 좌측 근접 통과음을 적용한다"
		)
		checked_traffic = true
		break
	check(checked_traffic, "활성 투어 구간의 일반 교통 차량으로 실제 통과음을 검사한다")
	race.free()
	await tree.process_frame
	print("코너 예고 카메라 / 분기·일시정지·복구 / 실제 좌우 추월·후류 / 음향 풀·버스 해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
