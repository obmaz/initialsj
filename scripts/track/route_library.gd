extends RefCounted
const STAGES := 5
const FORK_COMMIT := 80.0
# About a second and a half at the fastest pad speed: the straight to the fork is short.
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
	return 3000.0 + stage * 180.0 + node * 160.0


static func checkpoint_bonus(node: int) -> float:
	return CHECKPOINT_BONUS - node * 2.0


static func canopy_span(stage: int, node: int) -> Vector2:
	if stage == 2 and node == 1:
		return Vector2(760, 856)
	if stage == 4 and node == 1:
		return Vector2(1180, 1264)
	return Vector2.ZERO


static func tunnel_span(stage: int, node: int) -> Vector2:
	match theme(stage, node):
		"city", "neon":
			return Vector2(1420, 2370)
		"hawaii":
			return Vector2(1500, 1900)
		"amusement":
			return Vector2(1900, 2300)
		"bamboo":
			return Vector2(1700, 2150)
		"canyon":
			return Vector2(1800, 2250)
		"harbor":
			return Vector2(1500, 2050)
		"seoul":
			return Vector2(1500, 2600)
		"ruins":
			return Vector2(1750, 2210)
		"jeju", "snow":
			return Vector2(1850, 2250)
		"pyramid", "volcano":
			return Vector2(1980, 2240)
	return Vector2.ZERO


static func coastal(theme_id: String) -> bool:
	return theme_id in ["hawaii", "jeju", "fuji", "harbor"]
