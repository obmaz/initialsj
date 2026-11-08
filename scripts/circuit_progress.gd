extends RefCounted
# Telemetry only: world-space vehicle motion is never moved onto this curve.
const SEARCH_WINDOW := 160.0
const CACHE_SPACING := 4.0
const GATE_COUNT := 12
const MAX_PROGRESS_SPEED := 160.0
var section: Node3D
var distance := 80.0
var lane := 0.0
var laps := 0
var start_distance := 80.0
var gates_passed := 0
var next_gate := 0.0
var spacing := 4.0
var centers := PackedVector3Array()
var forwards := PackedVector3Array()
var rights := PackedVector3Array()
var widths := PackedFloat32Array()
var banks := PackedFloat32Array()
var previous_world := Vector3.ZERO
var has_previous_world := false
var previous_trackable := false
var last_valid_world := Vector3.ZERO
var fast_updates := 0
var full_searches := 0

func configure(road: Node3D) -> void:
	section = road
	centers.clear()
	forwards.clear()
	rights.clear()
	widths.clear()
	banks.clear()
	var count := maxi(8,ceili(float(section.length)/CACHE_SPACING))
	spacing = float(section.length)/count
	for i in range(count):
		var d := i*spacing
		var f: Vector3 = section.point(d+1)-section.point(d-1)
		f.y = 0
		f = f.normalized()
		centers.append(section.point(d))
		forwards.append(f)
		rights.append(Vector3(-f.z,0,f.x))
		widths.append(section.half_width(d))
		banks.append(tan(float(section.bank_at(d))))
	reset()

func reset(at_distance: float = 80.0) -> void:
	distance = at_distance
	start_distance = at_distance
	lane = 0
	laps = 0
	gates_passed = 0
	next_gate = at_distance+float(section.length)/GATE_COUNT if is_instance_valid(section) else at_distance
	has_previous_world = false
	previous_trackable = false
	fast_updates = 0
	full_searches = 0
	last_valid_world = section.point(at_distance) if is_instance_valid(section) else Vector3.ZERO

func reposition(at_distance: float) -> void:
	# A physical rescue may move back to a safe point without starting a new
	# race or erasing already crossed gates. The caller moves the body itself.
	distance = at_distance
	lane = 0
	has_previous_world = false
	previous_trackable = false
	last_valid_world = section.point(at_distance) if is_instance_valid(section) else Vector3.ZERO

func _score(offset: Vector3, forward: Vector3, right: Vector3, width: float, bank: float, d: float, hint: float) -> float:
	var lateral := offset.dot(right)
	var vertical := offset.y-lateral*bank
	var outside := maxf(0,absf(lateral)-width-4)
	return pow(offset.dot(forward),2)+vertical*vertical+outside*outside*4+lateral*lateral*0.012+pow(d-hint,2)*0.00005

func _at(world: Vector3, d: float, hint: float) -> Dictionary:
	var center: Vector3 = section.point(d)
	var forward: Vector3 = section.point(d+1)-section.point(d-1)
	forward.y = 0
	forward = forward.normalized()
	var right := Vector3(-forward.z,0,forward.x)
	var offset := world-center
	var lateral := offset.dot(right)
	var ground: Vector3 = section.point(d,lateral)
	var vertical := world.y-ground.y
	var width: float = section.half_width(d)
	var gate_margin := 4.0
	var tracking_margin := 4.0
	if section.has_method("rail_setback"):
		var setback: float = section.rail_setback(d,signf(lateral))
		# Dirt inside the real barrier is drivable track, including at lap gates.
		# Follow the flat runoff a little farther for telemetry, without allowing
		# an outside-barrier shortcut to earn gates or move the physical chassis.
		gate_margin = setback+0.25
		tracking_margin = maxf(4,setback+1.3)
	var right_height := vertical >= -2.0 and vertical <= 6.0
	return {"distance":d,"lane":lateral,"ground_height":ground.y,"vertical_error":vertical,"valid":absf(lateral) <= width+gate_margin and right_height,"trackable":absf(lateral) <= width+tracking_margin and right_height,"score":_score(offset,forward,right,width,tan(float(section.bank_at(d))),d,hint)}

func sample(world: Vector3, hint_distance: float) -> Dictionary:
	assert(is_instance_valid(section) and not centers.is_empty(),"Configure a circuit before projecting vehicle telemetry")
	full_searches += 1
	var best_score := INF
	var chosen := hint_distance
	var first := floori((hint_distance-SEARCH_WINDOW)/spacing)
	var last := ceili((hint_distance+SEARCH_WINDOW)/spacing)
	for i in range(first,last+1):
		var index := posmod(i,centers.size())
		var d := i*spacing
		var score := _score(world-centers[index],forwards[index],rights[index],widths[index],banks[index],d,hint_distance)
		if score < best_score:
			best_score = score
			chosen = d
	var best := _at(world,chosen,hint_distance)
	# Refine only the chosen local branch; never consult the global nearest
	# offset, which can jump between bridge decks or nearby switchbacks.
	for i in range(-8,9):
		var result := _at(world,chosen+i*spacing/8.0,hint_distance)
		if float(result.score) < float(best.score): best = result
	var center_d: float = best.distance
	for i in range(-4,5):
		var result := _at(world,center_d+i*0.0625,hint_distance)
		if float(result.score) < float(best.score): best = result
	best.erase("score")
	return best

func _nearby(world: Vector3, hint: float, radius: float) -> Dictionary:
	var best_score := INF
	var chosen := hint
	var first := floori((hint-radius)/spacing)
	var last := ceili((hint+radius)/spacing)
	for i in range(first,last+1):
		var index := posmod(i,centers.size())
		var d := i*spacing
		var score := _score(world-centers[index],forwards[index],rights[index],widths[index],banks[index],d,hint)
		if score < best_score:
			best_score = score
			chosen = d
	# Once the correct nearby branch is known, horizontal tangent projection
	# converges without rebuilding dozens of candidate dictionaries. The world
	# height remains a validity check, so a falling car cannot switch decks.
	var residual := INF
	for iteration in range(3):
		var center: Vector3 = section.point(chosen)
		var direction: Vector3 = section.point(chosen+1)-section.point(chosen-1)
		direction.y = 0
		var right := Vector3(-direction.z,0,direction.x).normalized()
		residual = (world-center).dot(direction.normalized())
		# Lateral offsets travel different arc lengths on the inside/outside of
		# a corner. Estimate that Jacobian from the cached neighboring tangents.
		var index := posmod(roundi(chosen/spacing),centers.size())
		var before := forwards[posmod(index-1,forwards.size())]
		var after := forwards[(index+1)%forwards.size()]
		var curvature := atan2(before.cross(after).y,before.dot(after))/(spacing*2)
		var lateral := (world-center).dot(right)
		var horizontal_scale := direction.length()/2
		var jacobian := maxf(0.45,horizontal_scale*(1+lateral*curvature))
		chosen += clampf(residual/jacobian,-spacing,spacing)
		if absf(chosen-hint) > radius-2: return {}
	var result := _at(world,chosen,hint)
	if not result.trackable or absf(residual) > 0.3: return {}
	result.erase("score")
	return result

func update(world_feet: Vector3, delta: float = 1.0/60) -> Dictionary:
	var projected := {}
	var radius := clampf(maxf(0,delta)*MAX_PROGRESS_SPEED+6,12,24)
	if has_previous_world and previous_trackable and world_feet.distance_to(previous_world) < radius*0.65:
		projected = _nearby(world_feet,distance,radius)
	if projected.is_empty(): projected = sample(world_feet,distance)
	else: fast_updates += 1
	var candidate: float = projected.distance
	var advance := candidate-distance
	var max_advance := minf(SEARCH_WINDOW*0.75,maxf(2.0,maxf(0,delta)*MAX_PROGRESS_SPEED+1.5))
	var plausible := absf(advance) <= max_advance
	if has_previous_world:
		var moved := world_feet.distance_to(previous_world)
		plausible = plausible and moved <= maxf(4.0,maxf(0,delta)*200+2.0)
		plausible = plausible and absf(advance) <= moved*1.6+2.0
	previous_world = world_feet
	has_previous_world = true
	lane = float(projected.lane)
	var valid := bool(projected.valid) and plausible and delta > 0
	var trackable := bool(projected.trackable) and plausible and delta > 0
	previous_trackable = trackable
	if trackable:
		var before := distance
		distance = candidate
		if valid: last_valid_world = world_feet
		while distance > before and before < next_gate and distance >= next_gate:
			if valid:
				gates_passed += 1
				laps = floori(float(gates_passed)/GATE_COUNT)
				next_gate += float(section.length)/GATE_COUNT
			else:
				# A continuous excursion beyond the barrier cannot earn this gate.
				# Keep its identity and retry at the next physical circuit crossing
				# instead of leaving an unreachable absolute offset behind the car.
				next_gate += float(section.length)
	projected["projection_distance"] = candidate
	projected["distance"] = distance
	projected["valid"] = valid
	projected["trackable"] = trackable
	projected["finished_laps"] = laps
	return projected
