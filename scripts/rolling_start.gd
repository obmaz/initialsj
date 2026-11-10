extends RefCounted
# 트랙2만 16대를 두 줄, 약180m 길이로 분산해 실제 바퀴로 굴려 출발한다.
const SPEED := 35.0
const START_LINE := 80.0
const RUNUP := SPEED*3.0

static func begin(race: Node3D) -> void:
	for i in range(race.world_race.bodies.size()):
		var offset: float = 0.0 if i == 0 else 18.0+floor((i-1)/2.0)*22.0
		var lane := -3.2 if i == 0 else (-3.2 if i%2 == 0 else 3.2)
		var d: float = START_LINE-RUNUP+offset
		race.world_race.teleport(i,d,lane)
		var body: CharacterBody3D = race.world_race.bodies[i]
		body.velocity = body.forward_direction()*SPEED
		var tracker: RefCounted = race.world_race.trackers[i]
		tracker.start_distance = START_LINE
		tracker.next_gate = START_LINE+race.track.length/tracker.GATE_COUNT
		if i > 0:
			race.rivals[i-1].target_lane = lane
			race.rivals[i-1].speed = SPEED
	race.speed = SPEED

static func advance(race: Node3D, delta: float) -> void:
	for i in range(race.world_race.bodies.size()):
		var body: CharacterBody3D = race.world_race.bodies[i]
		var tracker: RefCounted = race.world_race.trackers[i]
		var lane := -3.2 if i == 0 else float(race.rivals[i-1].target_lane)
		var forward: Vector3 = body.forward_direction()
		var right := Vector3(-forward.z,0,forward.x).normalized()
		var aim: Vector3 = race.track.point(tracker.distance+28,lane)-body.feet_position()
		var angle := atan2(aim.dot(right),aim.dot(forward))
		var wheel: float = (.46+race.vehicle.handling*.007)/(1+SPEED*.035)*body.steering_scale(SPEED)
		body.advance(delta,clampf(atan(5.4*sin(angle)/28)/wheel,-1,1),SPEED,false)
		var data: Dictionary = tracker.update(body.feet_position(),delta)
		if i == 0:
			race.distance = data.distance
			race.lane = data.lane
			race.speed = race.world_race.speed_of(body)
		else:
			race.rivals[i-1].distance = data.distance
			race.rivals[i-1].lane = data.lane
			race.rivals[i-1].speed = race.world_race.speed_of(body)

static func release(race: Node3D) -> void:
	for tracker in race.world_race.trackers:
		var d: float = tracker.distance
		var lane: float = tracker.lane
		tracker.reset(d)
		tracker.lane = lane
		tracker.start_distance = START_LINE
		tracker.next_gate = START_LINE+race.track.length/tracker.GATE_COUNT
	race.world_race.safe_distance = race.distance
	race.world_race.safe_lane = race.lane
