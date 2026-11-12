extends RefCounted
const STAGES := 5
const ENTRY_RUNUP := 120.0
const FORK_COMMIT := 200.0
const FORK_RECONSIDER := 270.0
# 분기 연결부120m를 포함해 최고 부스터 속도에서도 선택할 주행 거리를 확보한다.
const CHECKPOINT_RUNUP := 210.0
const CHECKPOINT_BONUS := 52.0
const START_TIME := 62.0
const THEMES := [
	["hawaii"],
	["jungle", "city"],
	["pyramid", "amusement", "jeju"],
	["ruins", "seoul", "fuji", "neon"],
	["canyon", "harbor", "bamboo", "snow", "volcano"]
]
const TITLES := {
	"hawaii": "PALM COAST",
	"jungle": "JUNGLE CANOPY",
	"city": "SKYLINE DRIVE",
	"amusement": "NEON CARNIVAL",
	"ruins": "LOST CITY",
	"pyramid": "GOLDEN PYRAMIDS",
	"jeju": "JEJU COAST",
	"seoul": "SEOUL EXPRESS",
	"fuji": "FUJI LAKESIDE",
	"neon": "NEON DISTRICT",
	"canyon": "RED CANYON",
	"harbor": "CONTAINER PORT",
	"bamboo": "BAMBOO PASS",
	"snow": "SNOW PASS",
	"volcano": "VOLCANIC COAST"
}
const PALETTES := {
	"hawaii": "74a865",
	"jungle": "416c43",
	"city": "74857f",
	"amusement": "79a364",
	"ruins": "a19a7b",
	"pyramid": "d9ba76",
	"jeju": "75a269",
	"seoul": "71877d",
	"fuji": "6b9270",
	"neon": "34424c",
	"canyon": "b96f43",
	"harbor": "79868b",
	"bamboo": "4c7949",
	"snow": "d5e0e6",
	"volcano": "524942"
}


static func theme(stage: int, node: int) -> String:
	return THEMES[clampi(stage, 0, 4)][clampi(node, 0, stage)]


static func title(stage: int, node: int) -> String:
	return TITLES[theme(stage, node)]


static func next_titles(stage: int, node: int) -> Array[String]:
	if stage >= STAGES - 1:
		return ["GOAL", "GOAL"]
	return [title(stage + 1, node), title(stage + 1, node + 1)]


# The node is the number of right forks taken: each right choice adds lasting risk.
static func section_length(stage: int, node: int) -> float:
	return 3000.0 + stage * 180.0 + node * 160.0 + (ENTRY_RUNUP if stage > 0 else 0.0)


static func checkpoint_bonus(node: int) -> float:
	return CHECKPOINT_BONUS - node * 2.0


static func canopy_span(stage: int, node: int) -> Vector2:
	if stage == 2 and node == 1:
		return Vector2(760, 1080) + Vector2.ONE * ENTRY_RUNUP
	if stage == 4 and node == 1:
		return Vector2(1180, 1264) + Vector2.ONE * ENTRY_RUNUP
	return Vector2.ZERO


static func tunnel_span(stage: int, node: int) -> Vector2:
	match theme(stage, node):
		"jungle":
			return Vector2(1080, 1300) + Vector2.ONE * ENTRY_RUNUP
		"city":
			return Vector2(1640, 1960) + Vector2.ONE * ENTRY_RUNUP
		"bamboo":
			return Vector2(1760, 1980) + Vector2.ONE * ENTRY_RUNUP
		"canyon":
			return Vector2(1820, 2080) + Vector2.ONE * ENTRY_RUNUP
		"seoul":
			return Vector2(1680, 2060) + Vector2.ONE * ENTRY_RUNUP
		"snow":
			return Vector2(1900, 2120) + Vector2.ONE * ENTRY_RUNUP
	return Vector2.ZERO


static func coastal(theme_id: String) -> bool:
	return theme_id in ["hawaii", "jeju", "fuji", "harbor"]
