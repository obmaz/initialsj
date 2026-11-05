extends SceneTree
# Independent world-space polygon intersections verify collision resolution on bends.
const Contact = preload("res://scripts/car_contact.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func footprint(race: Node3D, distance: float, lane: float, yaw: float) -> PackedVector2Array:
	var center: Vector3 = race.track.point(distance,lane)
	var basis := Basis(Vector3.UP,race.track.heading(distance)+yaw)
	var polygon := PackedVector2Array()
	for corner in [Vector2(-1.1,-2.2),Vector2(1.1,-2.2),Vector2(1.1,2.2),Vector2(-1.1,2.2)]:
		var p: Vector3 = center+basis*Vector3(corner.x,0,corner.y)
		polygon.append(Vector2(p.x,p.z))
	return polygon
func overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var area := 0.0
	for polygon in Geometry2D.intersect_polygons(a,b):
		var sum := 0.0
		for i in range(polygon.size()): sum += polygon[i].cross(polygon[(i+1)%polygon.size()])
		area += absf(sum)*0.5
	return area
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.state = "racing"
	var other: Dictionary = race.rivals[0]
	var cases := 0
	var worst := 0.0
	for d in [80.0,450.0,850.0,1300.0]:
		for lane in [-7.5,0.0,7.5]:
			for yaw in [-0.5,0.0,0.5]:
				for gap in [-2.8,2.8]:
					for other_yaw in [-0.12,0.12]:
						race.distance = d
						race.lane = lane
						race.slip_angle = yaw
						other.distance = d+gap
						other.lane = lane+0.6
						other.visual_yaw = other_yaw
						other.route_side = 0
						var contact: Dictionary = race.contact_with(other)
						if contact.is_empty(): continue
						race.resolve_contact(other,contact)
						var area := overlap_area(footprint(race,race.distance,race.lane,race.slip_angle),footprint(race,other.distance,other.lane,other.visual_yaw))
						worst = maxf(worst,area)
						cases += 1
						if area > 0.03:
							failures += 1
							push_error("Unresolved body overlap: %.3f m² at %.0fm / yaw %.2f" % [area,d,yaw])
	print(JSON.stringify({"resolved_cases":cases,"maximum_overlap_m2":snappedf(worst,0.0001),"failures":failures}))
	race.queue_free()
	await process_frame
	quit(1 if failures else 0)
