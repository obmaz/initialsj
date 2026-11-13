extends Node
# 무거운 씬을 읽기 전에 실제 스플래시를 먼저 그린다.
var loading_overlay: Control


func _ready() -> void:
	preload("res://scripts/ui/menu_layout.gd").expand_menu(get_window(), true)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	loading_overlay = preload("res://scripts/ui/loading/loading_overlay.gd").new()
	layer.add_child(loading_overlay)
	loading_overlay.begin("COAST RUSH", true)
	call_deferred("start")


func start() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	loading_overlay.advance(1, .2)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# 실행 스크립트의 최초 컴파일은 메인 스레드에서 수행한다.
	var packed: PackedScene = load("res://scenes/race.tscn")
	loading_overlay.advance(2, .55)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	preload("res://scripts/ui/menu_layout.gd").expand_menu(get_window(), false)
	var game := packed.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	loading_overlay.advance(3, 1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	queue_free()
