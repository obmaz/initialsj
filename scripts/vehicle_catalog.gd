extends RefCounted
# Original fictional names and arcade tuning. Values are metres/seconds internally.
const ABILITY_KEYS := ["top_speed","acceleration","boost","handling"]
const ABILITY_LABELS := ["TOP SPEED","ACCELERATION","BOOST","HANDLING"]
const SPECS := [
	{"id":"nimori","tagline":"AGILE CORNERS. RECHARGE NITRO THROUGH DRIFTING.","role":"AGILE / GAUGE","name":"NIMORI H","class":"LIGHT HATCH","model":"hatch","paint":"f0f1ed","accent":"56dfff","mode":"gauge","nitro_title":"GAUGE / HOLD","nitro_help":"Drift to recharge. Release to save fuel.","description":"Light, agile and quick out of corners. Lower top speed; a long-lasting nitro gauge.","max_speed":72.0,"boost_speed":87.0,"overdrive_speed":87.0,"accel":16.1,"boost_accel":21.0,"brake":48.0,"grip":14.5,"drift_grip":30.0,"steer_speed":9.8,"drift_steer_speed":12.4,"steer_rate":9.0,"lateral_grip":40.0,"lateral_drift":22.0,"energy_start":85.0,"drain":15.0,"regen":2.4,"drift_regen":6.0,"charges":0,"burst_duration":0.0,"handling":10,"audio":{"engine":"res://assets/audio/vehicles/nimori-engine.ogg","boost":"res://assets/audio/vehicles/nimori-boost.ogg","boost_start":"res://assets/audio/vehicles/nimori-boost-start.wav","drift":"res://assets/audio/vehicles/nimori-drift.ogg","engine_pitch":0.9,"engine_span":0.36,"engine_gear":0.07,"engine_gain":1.0,"boost_gain":0.9,"boost_rise":0.18,"start_gain":0.8,"drift_gain":1.0,"drift_pitch":1.0}},
	{"id":"veltrix","tagline":"HIGH TOP SPEED. TIME YOUR POWERFUL NITRO SHOTS.","role":"TOP SPEED / SHOTS","name":"VELTRIX S","class":"WEDGE EXOTIC","model":"wedge","paint":"ed563b","accent":"c18aff","mode":"charges","nitro_title":"3 SHOTS / TAP","nitro_help":"2.4s per shot. Checkpoint restores one.","description":"Fastest top speed and strongest nitro shots. Slower launch; brake early for corners.","max_speed":92.0,"boost_speed":112.0,"overdrive_speed":112.0,"accel":14.4,"boost_accel":39.2,"brake":43.0,"grip":11.4,"drift_grip":22.5,"steer_speed":7.0,"drift_steer_speed":9.8,"steer_rate":5.8,"lateral_grip":30.0,"lateral_drift":16.0,"energy_start":0.0,"drain":0.0,"regen":0.0,"drift_regen":0.0,"charges":3,"burst_duration":2.4,"handling":6,"audio":{"engine":"res://assets/audio/vehicles/veltrix-engine.ogg","boost":"res://assets/audio/vehicles/veltrix-boost.ogg","boost_start":"res://assets/audio/vehicles/veltrix-boost-start.wav","drift":"res://assets/audio/vehicles/veltrix-drift.ogg","engine_pitch":0.82,"engine_span":0.44,"engine_gear":0.085,"engine_gain":1.0,"boost_gain":1.0,"boost_rise":0.3,"start_gain":1.0,"drift_gain":0.9,"drift_pitch":1.0}},
	{"id":"ironvale","tagline":"QUICK LAUNCH. COMBINE NITRO AND OVERDRIVE CELLS.","role":"POWER / HYBRID","name":"IRONVALE V8","class":"CLASSIC MUSCLE","model":"muscle","paint":"3476a4","accent":"ffbc59","mode":"hybrid","nitro_title":"GAUGE + 2 CELLS","nitro_help":"Hold NITRO. Tap CELL for overdrive.","description":"Strongest launch with a heavy steering feel. Combine the gauge with overdrive cells.","max_speed":83.2,"boost_speed":103.2,"overdrive_speed":111.2,"accel":23.2,"boost_accel":36.1,"brake":38.0,"grip":12.5,"drift_grip":30.0,"steer_speed":8.0,"drift_steer_speed":12.125,"steer_rate":5.625,"lateral_grip":30.0,"lateral_drift":16.25,"energy_start":55.0,"drain":24.0,"regen":1.2,"drift_regen":4.2,"charges":2,"burst_duration":1.6,"handling":5,"audio":{"engine":"res://assets/audio/vehicles/ironvale-engine.ogg","boost":"res://assets/audio/vehicles/ironvale-boost.ogg","boost_start":"res://assets/audio/vehicles/ironvale-boost-start.wav","drift":"res://assets/audio/vehicles/ironvale-drift.ogg","engine_pitch":0.78,"engine_span":0.34,"engine_gear":0.06,"engine_gain":1.05,"boost_gain":1.0,"boost_rise":0.12,"start_gain":1.0,"drift_gain":1.1,"drift_pitch":1.0}},
	{"id":"straud","tagline":"REAR-ENGINE TRACTION. BRAKE LATE, BOOST OFTEN.","role":"BALANCE / QUICK GAUGE","name":"STRAUD 6R","class":"REAR-ENGINE GT","model":"gt","paint":"2c5442","accent":"7fe3b4","mode":"gauge","nitro_title":"QUICK GAUGE / HOLD","nitro_help":"Fast recharge for short, frequent bursts.","description":"Rear-engine traction and the strongest brakes. Balanced speed; a short, fast-recharging nitro gauge.","max_speed":86.0,"boost_speed":101.0,"overdrive_speed":101.0,"accel":16.8,"boost_accel":28.0,"brake":52.0,"grip":13.2,"drift_grip":26.0,"steer_speed":8.4,"drift_steer_speed":11.0,"steer_rate":7.2,"lateral_grip":35.0,"lateral_drift":19.0,"energy_start":70.0,"drain":26.0,"regen":4.2,"drift_regen":5.4,"charges":0,"burst_duration":0.0,"handling":8,"audio":{"engine":"res://assets/audio/vehicles/straud-engine.ogg","boost":"res://assets/audio/vehicles/straud-boost.ogg","boost_start":"res://assets/audio/vehicles/straud-boost-start.wav","drift":"res://assets/audio/vehicles/straud-drift.ogg","engine_pitch":0.86,"engine_span":0.42,"engine_gear":0.075,"engine_gain":1.0,"boost_gain":0.95,"boost_rise":0.22,"start_gain":0.9,"drift_gain":1.0,"drift_pitch":1.0}}
]
static func spec(index: int) -> Dictionary:
	return SPECS[clampi(index,0,SPECS.size()-1)]
# Per-vehicle sound profile: audio file paths and mixing numbers (docs/VEHICLE_AUDIO.md).
static func audio(index: int) -> Dictionary:
	return spec(index).get("audio",{})

static func record_key(index: int, mode: String = "tour", course: int = 0) -> String:
	if mode == "track" and course == 4: return "track_gorge_v5_best_time_"+str(spec(index).id)
	if mode == "track" and course == 3: return "track_riviera_v3_best_time_"+str(spec(index).id)
	if mode == "track" and course == 2: return "track_midnight_scrub_v2_best_time_"+str(spec(index).id)
	if mode == "track" and course == 1: return "track_suncoast_rolling_v6_best_time_"+str(spec(index).id)
	return ("track_fuji_scrub_v4_best_time_" if mode == "track" else "tour_world_v2_best_time_")+str(spec(index).id)

# Shared ten-point ranges: 60–92 m/s cruise, 0–36 m/s² launch, 0–60 m/s² boost.
# Speed/acceleration/boost ratings come from the actual driving parameters.
static func abilities(index: int) -> Dictionary:
	var v := spec(index)
	return {
		"top_speed":clampf((v.max_speed-60.0)/3.2,0,10),
		"acceleration":clampf(v.accel/3.6,0,10),
		"boost":clampf(v.boost_accel/6.0,0,10),
		"handling":float(v.handling)
	}
