extends RefCounted
# 트랙2만 16대를 두 줄, 약344m 길이로 분산해 실제 바퀴로 굴려 출발한다.
const SPEED := 35.0
const START_LINE := 80.0
const DURATION := 5.0
const RUNUP := SPEED * DURATION
const PLAYER_SLOT := 9
const ROW_SPACING := 48.0
const ROW_STAGGER := 8.0
const LANE_OFFSET := 3.2


static func grid_offset(slot: int) -> float:
	return floori(slot / 2.0) * ROW_SPACING + (slot % 2) * ROW_STAGGER


static func grid_lane(slot: int) -> float:
	return -LANE_OFFSET if slot % 2 == 0 else LANE_OFFSET


static func begin(race: Node3D) -> void:
	race.countdown = DURATION
	for i in range(race.world_race.bodies.size()):
		# 선두를 0으로 세어 플레이어를 9번 칸에 두고 상대 차량은 나머지 칸을 앞에서부터 채운다.
		var slot := PLAYER_SLOT if i == 0 else (i - 1 if i <= PLAYER_SLOT else i)
		var lane := grid_lane(slot)
		var d: float = START_LINE - RUNUP + grid_offset(PLAYER_SLOT) - grid_offset(slot)
		race.world_race.teleport(i, d, lane)
		var body: CharacterBody3D = race.world_race.bodies[i]
		body.velocity = body.forward_direction() * SPEED
		var tracker: RefCounted = race.world_race.trackers[i]
		tracker.start_distance = START_LINE
		tracker.next_gate = START_LINE + race.track.length / tracker.GATE_COUNT
		if i > 0:
			race.rivals[i - 1].target_lane = lane
			race.rivals[i - 1].speed = SPEED
	race.speed = SPEED


static func advance(race: Node3D, delta: float) -> void:
	for i in range(race.world_race.bodies.size()):
		var body: CharacterBody3D = race.world_race.bodies[i]
		var tracker: RefCounted = race.world_race.trackers[i]
		var lane := grid_lane(PLAYER_SLOT) if i == 0 else float(race.rivals[i - 1].target_lane)
		var forward: Vector3 = body.forward_direction()
		var right := Vector3(-forward.z, 0, forward.x).normalized()
		var aim: Vector3 = race.track.point(tracker.distance + 28, lane) - body.feet_position()
		var angle := atan2(aim.dot(right), aim.dot(forward))
		var spec: Dictionary = race.vehicle if i == 0 else race.rivals[i - 1].specification
		var wheel: float = (.46 + float(spec.handling) * .007) / (1 + SPEED * .035) * body.steering_scale(SPEED)
		body.advance(delta, clampf(atan(5.4 * sin(angle) / 28) / wheel, -1, 1), SPEED, false)
		var data: Dictionary = tracker.update(body.feet_position(), delta)
		if i == 0:
			race.distance = data.distance
			race.lane = data.lane
			race.speed = race.world_race.speed_of(body)
		else:
			race.rivals[i - 1].distance = data.distance
			race.rivals[i - 1].lane = data.lane
			race.rivals[i - 1].speed = race.world_race.speed_of(body)


static func release(race: Node3D) -> void:
	for tracker in race.world_race.trackers:
		var d: float = tracker.distance
		var lane: float = tracker.lane
		tracker.reset(d)
		tracker.lane = lane
		tracker.start_distance = START_LINE
		tracker.next_gate = START_LINE + race.track.length / tracker.GATE_COUNT
	race.world_race.safe_distance = race.distance
	race.world_race.safe_lane = race.lane
