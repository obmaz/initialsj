extends RefCounted
# 외벽 스킨의 경로·선택 계약. 메시·충돌·배치 크기는 바꾸지 않는다.
const URBAN_COUNT := 3
const PROP_COUNT := 2
const URBAN_A := "res://assets/environment/urban-facades-limestone.png"
const URBAN_B := "res://assets/environment/urban-facades-clinker.png"
const PROP_FRONT := "res://assets/environment/building-front-alternate.png"
const PROP_SIDE := "res://assets/environment/building-side-alternate.png"


# 같은 형상은 목록을 한 번 순환할 때마다 다른 스킨이 된다. 12종과 3세트의 배수 중복을 피한다.
static func city_skin(instance: int, model_count: int, route: int) -> int:
	return posmod(instance / maxi(1, model_count) + instance % maxi(1, model_count) + route, URBAN_COUNT)


static func encode_city(skin: int, variation: float) -> float:
	return (clampi(skin, 0, URBAN_COUNT - 1) + clampf(variation, .05, .95)) / URBAN_COUNT


static func prop_skin(position: Vector3, kind: String) -> int:
	var seed := floori(position.x / 11) * 73856093 ^ floori(position.z / 11) * 19349663 ^ kind.hash()
	seed ^= seed >> 13
	return posmod(seed, PROP_COUNT)
