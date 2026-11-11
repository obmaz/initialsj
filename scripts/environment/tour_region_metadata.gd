extends RefCounted
# 각 지역의 기획·날씨·시간대·난이도 정본. 난이도는 설명용이며 차량 물리를 바꾸지 않는다.
const REGIONS := {
	"hawaii": {"concept": "열대 해안과 휴양지", "weather": "clear", "time_of_day": "day", "difficulty": 1},
	"jungle": {"concept": "양옆의 울창한 숲·덩굴과 지하 암석 터널", "weather": "clear", "time_of_day": "day", "difficulty": 2},
	"city": {"concept": "현대 도시 고가도로", "weather": "clear", "time_of_day": "day", "difficulty": 2},
	"pyramid": {"concept": "모래 언덕과 고대 유적", "weather": "clear", "time_of_day": "dawn", "difficulty": 3},
	"amusement": {"concept": "놀이기구·상점·광고가 있는 공원", "weather": "clear", "time_of_day": "day", "difficulty": 3},
	"jeju": {"concept": "섬 해안과 돌담 마을", "weather": "clear", "time_of_day": "day", "difficulty": 3},
	"ruins": {"concept": "드문 유적과 비에 젖은 외곽 숲", "weather": "rain", "time_of_day": "dawn", "difficulty": 4},
	"seoul": {"concept": "도심 간선도로와 상가", "weather": "clear", "time_of_day": "day", "difficulty": 4},
	"fuji": {"concept": "호수와 산기슭", "weather": "clear", "time_of_day": "day", "difficulty": 4},
	"neon": {"concept": "야간 전자상가·아케이드와 네온 간판 거리", "weather": "clear", "time_of_day": "night", "difficulty": 4},
	"canyon": {"concept": "넓은 협곡과 외딴 암벽", "weather": "rain", "time_of_day": "dawn", "difficulty": 5},
	"harbor": {"concept": "항만과 해운 물류 단지", "weather": "clear", "time_of_day": "day", "difficulty": 5},
	"bamboo": {"concept": "대나무 계곡과 침엽수 숲", "weather": "clear", "time_of_day": "day", "difficulty": 5},
	"snow": {"concept": "설산과 바람에 쌓인 눈", "weather": "snow", "time_of_day": "day", "difficulty": 5},
	"volcano": {"concept": "화산섬과 노을 해안", "weather": "clear", "time_of_day": "dusk", "difficulty": 5}
}


static func resolve(theme: String, previous_weather: String = "clear", seed: int = 0) -> Dictionary:
	var result: Dictionary = REGIONS[theme].duplicate(true)
	result.region = theme
	result.rain_candidate = result.weather == "rain"
	# 드문 오브젝트 지역 두 곳이 비 후보. 유적의 비는 여행별로 결정하고 협곡은 선행 비를 피한다.
	if result.weather == "rain" and (previous_weather == "rain" or (theme == "ruins" and posmod(seed, 100) >= 55)):
		result.weather = "clear"
	result.previous_weather = previous_weather
	return result
