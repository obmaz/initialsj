extends RefCounted
# Original fictional names and arcade tuning. Values are metres/seconds internally.
const ABILITY_KEYS := ["top_speed","acceleration","boost","handling"]
const ABILITY_LABELS := ["TOP SPEED","ACCELERATION","BOOST","HANDLING"]
const SPECS := [
	{"id":"nimori","name":"NIMORI H","class":"LIGHT HATCH","model":"hatch","paint":"f0f1ed","accent":"56dfff","mode":"gauge","nitro_title":"GAUGE / HOLD","nitro_help":"Drift to recharge. Release to save fuel.","description":"Agile handling and balanced acceleration. Hold nitro and recharge through drifting.","max_speed":76.0,"boost_speed":93.0,"overdrive_speed":93.0,"accel":24.0,"boost_accel":34.0,"brake":46.0,"grip":13.0,"drift_grip":27.0,"steer_speed":9.2,"drift_steer_speed":12.0,"steer_rate":8.0,"lateral_grip":38.0,"lateral_drift":21.0,"energy_start":75.0,"drain":19.0,"regen":3.0,"drift_regen":9.0,"charges":0,"burst_duration":0.0,"handling":9},
	{"id":"veltrix","name":"VELTRIX S","class":"WEDGE EXOTIC","model":"wedge","paint":"ed563b","accent":"c18aff","mode":"charges","nitro_title":"3 SHOTS / TAP","nitro_help":"2.4s per shot. Checkpoint restores one.","description":"Highest cruise and burst speed. Slower launch; plan your three nitro shots.","max_speed":85.0,"boost_speed":107.0,"overdrive_speed":107.0,"accel":20.0,"boost_accel":47.0,"brake":41.0,"grip":12.5,"drift_grip":23.0,"steer_speed":7.6,"drift_steer_speed":10.2,"steer_rate":6.0,"lateral_grip":32.0,"lateral_drift":16.0,"energy_start":0.0,"drain":0.0,"regen":0.0,"drift_regen":0.0,"charges":3,"burst_duration":2.4,"handling":7},
	{"id":"ironvale","name":"IRONVALE V8","class":"CLASSIC MUSCLE","model":"muscle","paint":"3476a4","accent":"ffbc59","mode":"hybrid","nitro_title":"GAUGE + 2 CELLS","nitro_help":"Hold nitro. E / CELL fires overdrive.","description":"Strong acceleration with heavy handling. Hold nitro; add cells for overdrive.","max_speed":79.0,"boost_speed":92.0,"overdrive_speed":102.0,"accel":29.0,"boost_accel":40.0,"brake":39.0,"grip":10.8,"drift_grip":25.0,"steer_speed":7.0,"drift_steer_speed":10.5,"steer_rate":5.0,"lateral_grip":25.0,"lateral_drift":14.0,"energy_start":55.0,"drain":24.0,"regen":2.0,"drift_regen":7.0,"charges":2,"burst_duration":1.6,"handling":5}
]
static func spec(index: int) -> Dictionary:
	return SPECS[clampi(index,0,SPECS.size()-1)]
static func record_key(index: int) -> String:
	return "best_time_"+str(spec(index).id)

# A shared ten-point scale: 90 m/s cruise, 32 m/s² launch, 50 m/s² boost.
# Speed/acceleration/boost ratings come from the actual driving parameters.
static func abilities(index: int) -> Dictionary:
	var v := spec(index)
	return {
		"top_speed":clampf(v.max_speed/9.0,0,10),
		"acceleration":clampf(v.accel/3.2,0,10),
		"boost":clampf(v.boost_accel/5.0,0,10),
		"handling":float(v.handling)
	}
