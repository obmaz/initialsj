extends RefCounted
# Which of the selected vehicle's own sounds play, how loud and how pitched.
# racing_audio.gd plays the result on Web Audio or Godot players. The files and
# tuning live in vehicle_catalog.gd; docs/VEHICLE_AUDIO.md explains how to add a vehicle.
const RaceState = preload("res://scripts/race_state.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
# Linear gains at the baked A-weighted level (tools/bake_vehicle_audio.py). The
# per-vehicle *_gain values in the catalog scale these.
const ENGINE_LEVEL := 0.18
const ENGINE_LEVEL_BOOSTING := 0.21
const ENGINE_LEVEL_COUNTDOWN := 0.075
const BOOST_LEVEL := 0.17
const BOOST_PAD_SHARE := 0.55
const START_LEVEL := 0.25
const DRIFT_LEVEL := 0.038
const PUDDLE_SHARE := 0.47
const SPEED_FULL := 90.0

static func profile(index: int) -> Dictionary:
	return Catalog.audio(index)

# Web Audio loops are looked up by "<id>-engine", "<id>-boost" and "<id>-drift".
static func web_id(index: int) -> String:
	return str(Catalog.spec(index).id)

# Engine, boost and drift files are loops; the loop flag is set here so a new
# vehicle cannot forget it in an import sidecar.
static func load_loop(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis: stream.loop = true
	return stream

static func load_one_shot(path: String) -> AudioStream:
	return load(path)

static func mix(race: Node3D) -> Dictionary:
	var p := profile(race.selected_vehicle)
	var gear := maxi(1,race.gear_number())
	var rpm01 := clampf((race.engine_rpm()-900)/6400,0,1)
	var speed01 := clampf(race.speed/SPEED_FULL,0,1)
	var engine_level := ENGINE_LEVEL_COUNTDOWN if race.state == RaceState.COUNTDOWN else (ENGINE_LEVEL_BOOSTING if race.boosting else ENGINE_LEVEL)
	# Nitro shots and cells get the full roar; road boost pads and lanes a lighter one.
	var boost_share := 0.0
	if race.state == RaceState.RACING: boost_share = 1.0 if race.nitro_active else (BOOST_PAD_SHARE if race.pad_active else 0.0)
	var drift_share := 1.0 if race.drifting else (PUDDLE_SHARE if race.surface.wet_time > 0 else 0.0)
	return {
		"engine_pitch": float(p.engine_pitch)+rpm01*float(p.engine_span)+(gear-1)*float(p.engine_gear),
		"engine": engine_level*float(p.engine_gain),
		"boost": BOOST_LEVEL*boost_share*float(p.boost_gain),
		"boost_pitch": 1.0+float(p.boost_rise)*speed01,
		"drift": DRIFT_LEVEL*drift_share*float(p.drift_gain),
		"drift_pitch": float(p.drift_pitch)*(0.94+0.12*speed01),
	}

static func start_level(index: int) -> float:
	return START_LEVEL*float(profile(index).start_gain)
