extends RefCounted
# Original fictional names and arcade tuning. Values are metres/seconds internally.
const ABILITY_KEYS := ["top_speed","acceleration","boost","handling"]
const ABILITY_LABELS := ["TOP SPEED","ACCELERATION","BOOST","HANDLING"]
const SPECS := [
	{"id":"nimori","name":"NIMORI H","class":"LIGHT HATCH","model":"hatch","paint":"f0f1ed","accent":"56dfff","mode":"gauge","nitro_title":"GAUGE / HOLD","nitro_help":"Drift to recharge. Release to save fuel.","description":"Light, agile and quick out of corners. Lower top speed; a long-lasting nitro gauge.","max_speed":72.0,"boost_speed":87.0,"overdrive_speed":87.0,"accel":28.0,"boost_accel":30.0,"brake":48.0,"grip":14.5,"drift_grip":30.0,"steer_speed":9.8,"drift_steer_speed":12.4,"steer_rate":9.0,"lateral_grip":40.0,"lateral_drift":22.0,"energy_start":85.0,"drain":15.0,"regen":4.0,"drift_regen":10.0,"charges":0,"burst_duration":0.0,"handling":10},
	{"id":"veltrix","name":"VELTRIX S","class":"WEDGE EXOTIC","model":"wedge","paint":"ed563b","accent":"c18aff","mode":"charges","nitro_title":"3 SHOTS / TAP","nitro_help":"2.4s per shot. Checkpoint restores one.","description":"Fastest top speed and strongest nitro shots. Slower launch; brake early for corners.","max_speed":92.0,"boost_speed":112.0,"overdrive_speed":112.0,"accel":17.0,"boost_accel":56.0,"brake":43.0,"grip":11.4,"drift_grip":22.5,"steer_speed":7.0,"drift_steer_speed":9.8,"steer_rate":5.8,"lateral_grip":30.0,"lateral_drift":16.0,"energy_start":0.0,"drain":0.0,"regen":0.0,"drift_regen":0.0,"charges":3,"burst_duration":2.4,"handling":6},
	{"id":"ironvale","name":"IRONVALE V8","class":"CLASSIC MUSCLE","model":"muscle","paint":"3476a4","accent":"ffbc59","mode":"hybrid","nitro_title":"GAUGE + 2 CELLS","nitro_help":"Hold nitro. E / CELL fires overdrive.","description":"Strongest launch with a heavy steering feel. Combine the gauge with overdrive cells.","max_speed":80.0,"boost_speed":100.0,"overdrive_speed":108.0,"accel":34.0,"boost_accel":43.0,"brake":38.0,"grip":10.0,"drift_grip":24.0,"steer_speed":6.4,"drift_steer_speed":9.7,"steer_rate":4.5,"lateral_grip":24.0,"lateral_drift":13.0,"energy_start":55.0,"drain":24.0,"regen":2.0,"drift_regen":7.0,"charges":2,"burst_duration":1.6,"handling":4}
]
static func spec(index: int) -> Dictionary:
	return SPECS[clampi(index,0,SPECS.size()-1)]
static func record_key(index: int, mode: String = "tour") -> String:
	return ("track_best_time_" if mode == "track" else "best_time_")+str(spec(index).id)

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
