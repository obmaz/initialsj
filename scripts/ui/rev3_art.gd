extends RefCounted
# 원화의 전역 좌표를 실제 안전 영역에 배치하고 현재 화면 텍스처만 보유한다.
const CATALOG := "res://assets/ui/rev3/catalog.json"
const FONT = preload("res://assets/ui/rev3/fonts/interface_font.tres")
const DESIGN := Vector2(1280, 720)
const BLUE := Color("355d77")
const CORAL := Color("bd6e58")
const GOLD := Color("dfbd69")
const WHITE := Color("f8fafb")
static var catalog: Dictionary = {}
var current := ""
var textures: Dictionary = {}
var retired: Array[Texture2D] = []
var indices: Dictionary = {}


static func data() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return catalog


static func screen_size(screen: String) -> Vector2:
	var dimensions: Array = data().screens[screen].size
	return Vector2(dimensions[0], dimensions[1])


func begin(screen: String) -> void:
	if current == screen:
		return
	retired.assign(textures.values())
	textures.clear()
	current = screen
	call_deferred("release_retired")


func release_retired() -> void:
	retired.clear()


func release() -> void:
	textures.clear()
	retired.clear()
	current = ""


func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]


func index(screen: String) -> Dictionary:
	if not indices.has(screen):
		var result := {}
		for root in data().screens[screen].layers:
			index_layer(root, root.id, result)
		indices[screen] = result
	return indices[screen]


func index_layer(item: Dictionary, root: String, result: Dictionary) -> void:
	result[item.id] = {"layer": item, "root": root}
	for child in item.children:
		index_layer(child, root, result)


func source_rect(screen: String, id: String) -> Rect2:
	var values: Array = index(screen)[id].layer.rect
	var factor := DESIGN / screen_size(screen)
	return Rect2(Vector2(values[0], values[1]) * factor, Vector2(values[2], values[3]) * factor)


func rect(screen: String, id: String, area: Rect2 = Rect2(Vector2.ZERO, DESIGN)) -> Rect2:
	if not index(screen).has(id):
		return Rect2()
	var entry: Dictionary = index(screen)[id]
	var original := source_rect(screen, id)
	var root := source_rect(screen, entry.root)
	var mapped := map_root(screen, entry.root, root, area)
	if id == entry.root:
		return mapped
	var offset := original.position - root.position
	# 헤더·푸터를 넓혀도 아이콘 크기는 늘리지 않는다.
	if original.get_center().x > root.get_center().x and mapped.size.x != root.size.x:
		offset.x += mapped.size.x - root.size.x
	return Rect2(mapped.position + offset, original.size)


static func map_root(screen: String, id: String, source: Rect2, area: Rect2) -> Rect2:
	var result := source
	var extra := area.size - DESIGN
	if screen == "tour_passport" and id.begins_with("reward_") and id.trim_prefix("reward_").is_valid_int():
		result.position += Vector2(
			area.position.x + extra.x * id.trim_prefix("reward_").to_int() / 5, area.end.y - DESIGN.y
		)
		result.size.x += extra.x / 5
		return result
	if screen == "tour_hud" and id in ["route_left", "route_right"]:
		result.position.y += area.position.y
		return result
	if id == "result_panel":
		result.position.x += area.end.x - DESIGN.x
		return result
	var third := {"weather": 0.0, "time": 1.0, "continue": 2.0}
	if screen in ["track_select", "track_select_more", "track_conditions"] and id in third:
		result.position += Vector2(area.position.x + extra.x * third[id] / 3, area.end.y - DESIGN.y)
		result.size.x += extra.x / 3
		return result
	var quarter := {"cancel": 0.0, "reset": .25, "apply": .5}
	if screen.begins_with("tuning_") and id in quarter:
		result.position += Vector2(area.position.x + extra.x * quarter[id], area.end.y - DESIGN.y)
		result.size.x += extra.x * (.5 if id == "apply" else .25)
		return result
	if id in ["header", "brand_header"]:
		result.position += area.position
		result.size.x += extra.x
	elif id in ["settings", "passport", "passport_progress"] and source.position.y < 150:
		result.position += Vector2(area.end.x - DESIGN.x, area.position.y)
	elif (
		(source.position.y >= 580 or screen in ["start", "start_passport"] and id in ["tour", "track"])
		and not screen.begins_with("driving_")
	):
		result.position.y += area.end.y - DESIGN.y
		if source.size.x > 390:
			var column := 0.0 if source.get_center().x < DESIGN.x * .5 else .5
			result.position.x += area.position.x + extra.x * column
			result.size.x += extra.x * .5
		elif source.position.x < DESIGN.x * .5:
			result.position.x += area.position.x
		else:
			result.position.x += area.end.x - DESIGN.x
	return result


func background(target: CanvasItem, screen: String, area: Rect2) -> void:
	begin(screen)
	var path: String = data().screens[screen].background
	if path.is_empty():
		return
	var image := texture(path)
	var source := Rect2(Vector2.ZERO, image.get_size())
	var ratio := minf(source.size.x / area.size.x, source.size.y / area.size.y)
	var cropped := area.size * ratio
	source.position = (source.size - cropped) * .5
	source.size = cropped
	target.draw_texture_rect_region(image, area, source)


func draw_screen(target: CanvasItem, screen: String, area: Rect2, skip: Array[String] = []) -> void:
	begin(screen)
	for item in data().screens[screen].layers:
		draw_layer(target, screen, item, area, skip)


func draw_layer(target: CanvasItem, screen: String, item: Dictionary, area: Rect2, skip: Array[String]) -> void:
	if item.id in skip:
		return
	draw_part(target, screen, item.id, rect(screen, item.id, area))
	for child in item.children:
		draw_layer(target, screen, child, area, skip)


func draw_part(target: CanvasItem, screen: String, id: String, destination: Rect2, tint: Color = Color.WHITE) -> void:
	if not index(screen).has(id) or not destination.has_area():
		return
	var item: Dictionary = index(screen)[id].layer
	if not item.has("asset"):
		return
	var asset: Dictionary = data().assets[item.asset]
	var values: Array = asset.region
	var source := Rect2(values[0], values[1], values[2], values[3])
	var image := texture(asset.path)
	var normal := source_rect(screen, id)
	if item.has("nine_slice") and not destination.size.is_equal_approx(normal.size):
		nine_slice(target, image, source, destination, item.nine_slice, DESIGN / screen_size(screen), tint)
	elif id in ["header", "brand_header"] and not destination.size.is_equal_approx(normal.size):
		nine_slice(target, image, source, destination, [330, 0, 180, 0], DESIGN / screen_size(screen), tint)
	else:
		target.draw_texture_rect_region(image, destination, source, tint)


static func nine_slice(
	target: CanvasItem,
	image: Texture2D,
	source: Rect2,
	destination: Rect2,
	margins: Array,
	factor: Vector2,
	tint: Color
) -> void:
	var left: float = margins[0]
	var top: float = margins[1]
	var right: float = margins[2]
	var bottom: float = margins[3]
	var sx := [0.0, left, source.size.x - right, source.size.x]
	var sy := [0.0, top, source.size.y - bottom, source.size.y]
	var dx := [0.0, left * factor.x, destination.size.x - right * factor.x, destination.size.x]
	var dy := [0.0, top * factor.y, destination.size.y - bottom * factor.y, destination.size.y]
	for row in range(3):
		for column in range(3):
			var size_px := Vector2(sx[column + 1] - sx[column], sy[row + 1] - sy[row])
			if size_px.x <= 0 or size_px.y <= 0:
				continue
			var region := Rect2(source.position + Vector2(sx[column], sy[row]), size_px)
			var bounds := Rect2(
				destination.position + Vector2(dx[column], dy[row]),
				Vector2(dx[column + 1] - dx[column], dy[row + 1] - dy[row])
			)
			target.draw_texture_rect_region(image, bounds, region, tint)


func draw_fragment(target: CanvasItem, screen: String, id: String, crop: Rect2, destination: Rect2) -> void:
	var item: Dictionary = index(screen)[id].layer
	var asset: Dictionary = data().assets[item.asset]
	var values: Array = asset.region
	var region := Rect2(Vector2(values[0], values[1]) + crop.position, crop.size)
	target.draw_texture_rect_region(texture(asset.path), destination, region)


func style(screen: String, id: String) -> StyleBoxTexture:
	var item: Dictionary = index(screen)[id].layer
	var asset: Dictionary = data().assets[item.asset]
	var values: Array = asset.region
	var atlas := AtlasTexture.new()
	atlas.atlas = texture(asset.path)
	atlas.region = Rect2(values[0], values[1], values[2], values[3])
	var result := StyleBoxTexture.new()
	result.texture = atlas
	var margins: Array = item.get("nine_slice", [24, 24, 24, 24])
	for side in range(4):
		result.set_texture_margin(side, margins[side])
		result.set_content_margin(side, 10)
	return result


static func draw_panel(target: CanvasItem, bounds: Rect2, coral: bool = false, radius: float = 18) -> void:
	# 원화의 빈 패널에서 생긴 제거 자국은 재현하지 않는다. 같은 색·곡률의 연속 면으로 대체한다.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	radius = minf(radius, minf(bounds.size.x, bounds.size.y) * .5)
	var corners := [
		bounds.position + Vector2(bounds.size.x - radius, radius),
		bounds.end - Vector2.ONE * radius,
		bounds.position + Vector2(radius, bounds.size.y - radius),
		bounds.position + Vector2.ONE * radius
	]
	for corner in range(4):
		for step in range(9):
			var angle := -PI * .5 + corner * PI * .5 + step / 8.0 * PI * .5
			var point: Vector2 = corners[corner] + Vector2.from_angle(angle) * radius
			if not points.is_empty() and point.distance_squared_to(points[-1]) < .000001:
				continue
			points.append(point)
			var amount := clampf(
				(
					(point.x - bounds.position.x) / maxf(1, bounds.size.x) * .65
					+ (bounds.end.y - point.y) / maxf(1, bounds.size.y) * .35
				),
				0,
				1
			)
			colors.append(
				(
					Color("d98265").lerp(Color("bb654e"), amount)
					if coral
					else Color("3b6a85").lerp(Color("24475e"), amount)
				)
			)
	if points.size() > 2 and points[0].distance_squared_to(points[-1]) < .000001:
		points.resize(points.size() - 1)
		colors.resize(colors.size() - 1)
	target.draw_polygon(points, colors)


func icon(screen: String, id: String, crop_width: float = 0) -> AtlasTexture:
	var item: Dictionary = index(screen)[id].layer
	var asset: Dictionary = data().assets[item.asset]
	var values: Array = asset.region
	var result := AtlasTexture.new()
	result.atlas = texture(asset.path)
	result.region = Rect2(values[0], values[1], minf(values[2], crop_width) if crop_width > 0 else values[2], values[3])
	return result
