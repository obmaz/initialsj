extends RefCounted
const STAGES := 5
const FORK_COMMIT := 80.0
const CHECKPOINT_BONUS := 22.0
const START_TIME := 38.0
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
