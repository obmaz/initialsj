extends RefCounted
# Which of the selected vehicle's own sounds play, how loud and how pitched.
# racing_audio.gd plays the result on Web Audio or Godot players. The files and
# tuning live in vehicle_catalog.gd; docs/VEHICLE_AUDIO.md explains how to add a vehicle.
const RaceState = preload("res://scripts/race/race_state.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
# Linear gains at the baked A-weighted level (tools/bake_vehicle_audio.py). The
# per-vehicle *_gain values in the catalog scale these.
const ENGINE_LEVEL := 0.18
const ENGINE_LEVEL_BOOSTING := 0.21
const ENGINE_LEVEL_COUNTDOWN := 0.075
const BOOST_LEVEL := 0.17
const BOOST_PAD_SHARE := 0.55
const START_LEVEL := 0.25
const DRIFT_LEVEL := 0.038
const SPEED_FULL := 90.0
const GRAVEL := "res://assets/audio/road-gravel.ogg"
const WET := "res://assets/audio/road-wet.ogg"


static func profile(index: int) -> Dictionary:
	return Catalog.audio(index)


# Web Audio loops are looked up by "<id>-engine", "<id>-boost" and "<id>-drift".
static func web_id(index: int) -> String:
	return str(Catalog.spec(index).id)


# Engine, boost and drift files are loops; the loop flag is set here so a new
# vehicle cannot forget it in an import sidecar.
static func load_loop(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream


static func load_one_shot(path: String) -> AudioStream:
	return load(path)


static func mix(race: Node3D) -> Dictionary:
	var p := profile(race.selected_vehicle)
	var gear: int = race.sound_state.gear if race.sound_state.gear > 0 else maxi(1, race.gear_number())
	var band: float = race.vehicle.max_speed / 5.8
	var rpm01 := clampf((race.speed - (gear - 1) * band) / band, 0, 1)
	var speed01 := clampf(race.speed / SPEED_FULL, 0, 1)
	var engine_level := (
		ENGINE_LEVEL_COUNTDOWN
		if race.state == RaceState.COUNTDOWN
		else (ENGINE_LEVEL_BOOSTING if race.boosting else ENGINE_LEVEL)
	)
	var load_amount: float = .4 if race.state == RaceState.COUNTDOWN else race.sound_state.load_amount
	# 클린 탈출·스킬 점프도 실제 가속이 유효한 동안 기존 부스트 층을 함께 쓴다.
	var boost_share := 0.0
	if race.state == RaceState.RACING:
		boost_share = (
			1.0 if race.nitro_active else (BOOST_PAD_SHARE if race.pad_active or race.reward_boost_active() else 0.0)
		)
	var contact: bool = not race.air.active and not race.crash.active
	if (
		race.state == RaceState.RACING
		and race.throttling
		and not race.braking
		and not race.drifting
		and not race.air.active
		and not race.crash.active
		and race.protection_left <= 0
		and race.impact < .15
	):
		boost_share = maxf(boost_share, race.driving_feedback.boost_envelope * .55)
	var demand := 0.0
	if race.world_race != null:
		var body: CharacterBody3D = race.world_race.player_body
		contact = contact and body.grounded
		demand = body.corner_demand / maxf(body.corner_grip, 1)
	var rolling := smoothstep(2, 25, race.speed) if contact and race.state == RaceState.RACING else 0.0
	var slip := smoothstep(.035, .25, absf(race.slip_angle))
	var edge := smoothstep(.62, 1.15, demand) * .55
	var braking := smoothstep(12, 32, race.speed) * .55 if race.braking else 0.0
	var drift_share := maxf(slip, maxf(edge, braking))
	# 드리프트 버튼만 눌렀다고 스킬이 나지 않는다. 실제 회전·속도가 필요하다.
	var gravel := 0.0
	if race.track != null:
		var section: Node3D = race.track.active
		if preload("res://scripts/track/harbor_corridor.gd").contains(section, race.distance):
			gravel = preload("res://scripts/track/harbor_corridor.gd").weight(fposmod(race.distance, section.length))
		gravel = maxf(gravel, race.offroad_amount)
	var wet: float = race.surface.wetness
	if race.mode == "tour" and race.track != null:
		if (
			race.track.active.region_metadata.get("weather", "clear") == "rain"
			and not race.track.active.in_tunnel(race.distance)
		):
			wet = 1.0
	var road_pitch := .7 + speed01 * .65
	return {
		"engine_pitch":
		maxf(
			.4,
			(
				float(p.engine_pitch)
				+ rpm01 * float(p.engine_span)
				+ (gear - 1) * float(p.engine_gear)
				- race.sound_state.shift * .13
			)
		),
		"engine": engine_level * float(p.engine_gain) * sqrt(load_amount),
		"coast": engine_level * .72 * float(p.engine_gain) * sqrt(1 - load_amount),
		"boost": BOOST_LEVEL * boost_share * float(p.boost_gain),
		"boost_pitch": 1.0 + float(p.boost_rise) * speed01,
		"drift": DRIFT_LEVEL * rolling * drift_share * float(p.drift_gain) * lerpf(1, .4, gravel),
		"drift_pitch": float(p.drift_pitch) * (0.94 + 0.12 * speed01),
		"gravel": .052 * rolling * gravel,
		"wet": .044 * rolling * wet,
		"road_pitch": road_pitch,
	}


static func start_level(index: int) -> float:
	return START_LEVEL * float(profile(index).start_gain)
