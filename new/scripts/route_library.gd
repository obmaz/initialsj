extends RefCounted
const STAGES := 5
const FORK_COMMIT := 80.0
const CHECKPOINT_BONUS := 60.0
const START_TIME := 70.0
const THEMES := [
	["hawaii"],
	["desert", "city"],
	["pyramid", "amusement", "jeju"],
	["ruins", "seoul", "city", "hawaii"],
	["pyramid", "jeju", "amusement", "seoul", "ruins"]
]
const TITLES := {"hawaii":"PALM COAST", "desert":"DUNE HIGHWAY", "city":"SKYLINE DRIVE", "amusement":"NEON CARNIVAL", "ruins":"LOST CITY", "pyramid":"GOLDEN PYRAMIDS", "jeju":"JEJU COAST", "seoul":"SEOUL EXPRESS"}
const PALETTES := {"hawaii":"74a865", "desert":"d7ae71", "city":"74857f", "amusement":"79a364", "ruins":"a19a7b", "pyramid":"d9ba76", "jeju":"75a269", "seoul":"71877d"}
static func theme(stage: int, node: int) -> String:
	return THEMES[clampi(stage,0,4)][clampi(node,0,stage)]
static func title(stage: int, node: int) -> String:
	return TITLES[theme(stage,node)]
static func next_titles(stage: int, node: int) -> Array[String]:
	if stage >= STAGES - 1:
		return ["GOAL", "GOAL"]
	return [title(stage + 1,node), title(stage + 1,node + 1)]

# The node is the number of right forks taken: each right choice adds lasting risk.
static func section_length(stage: int, node: int) -> float:
	return 3000.0 + stage * 180.0 + node * 160.0
static func checkpoint_bonus(node: int) -> float:
	return CHECKPOINT_BONUS - node * 2.0
static func canopy_span(stage: int, node: int) -> Vector2:
	if stage == 2 and node == 1: return Vector2(760,856)
	if stage == 4 and node == 1: return Vector2(1180,1264)
	return Vector2.ZERO
static func tunnel_span(stage: int, node: int) -> Vector2:
	match theme(stage,node):
		"city": return Vector2(1420,2370)
		"seoul": return Vector2(1500,2600)
		"ruins": return Vector2(1750,2210)
		"jeju": return Vector2(1850,2250)
		"pyramid": return Vector2(1980,2240)
	return Vector2.ZERO
