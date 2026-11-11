extends RefCounted
const Library = preload("res://scripts/track/route_library.gd")
const Metadata = preload("res://scripts/environment/tour_region_metadata.gd")
const Features = preload("res://scripts/track/road_features.gd")


# 도착지가 같아도 분기 순서가 다르면 길이·주행 조건이 다르다.
static func route_id(history: Array) -> String:
	var result := ""
	for side in history:
		result += "L" if int(side) == 0 else "R"
	return result if not result.is_empty() else "START"


static func score_multiplier(history: Array) -> float:
	var rights := 0
	for side in history:
		rights += int(side)
	return 1.0 + rights * 0.14


static func route_length(history: Array) -> float:
	var length := Library.section_length(0, 0)
	var node := 0
	for stage in range(1, 5):
		node += int(history[stage - 1]) if history.size() >= stage else 0
		length += Library.section_length(stage, node)
	return length


static func medal(seconds: float, history: Array, max_speed: float) -> int:
	if seconds <= 0:
		return 0
	var target := route_length(history) / maxf(30, max_speed * 0.86) + 12
	return 3 if seconds <= target else (2 if seconds <= target * 1.16 else 1)


static func medal_label(value: int) -> String:
	return ["--", "BRONZE", "SILVER", "GOLD"][clampi(value, 0, 3)]


static func choice(race: Node3D, side: int) -> Dictionary:
	var stage: int = mini(4, race.stage_index + 1)
	var node: int = mini(stage, race.route_node + side)
	var theme := Library.theme(stage, node)
	var metadata: Dictionary = Metadata.resolve(
		theme, race.track.active.region_metadata.weather, race.track.weather_seed
	)
	var history: Array = race.track.history.duplicate()
	history.append(side)
	var feel: String = Features.THEME_FEEL[theme].label
	var style := feel.split(" ")[0]
	if metadata.weather in ["rain", "snow"]:
		style = str(metadata.weather).to_upper()
	elif metadata.time_of_day == "night":
		style = "NIGHT"
	return {
		"title": Library.title(stage, node),
		"difficulty": metadata.difficulty,
		"weather": metadata.weather,
		"style": style,
		"multiplier": score_multiplier(history),
		"hint": "D%d / %s / SCORE x%.2f" % [metadata.difficulty, style, score_multiplier(history)]
	}
