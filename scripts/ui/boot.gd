extends Node
# 무거운 씬을 읽기 전에 실제 스플래시를 먼저 그린다.
var loading: Control


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	loading = preload("res://scripts/ui/loading_card.gd").new()
	layer.add_child(loading)
	loading.begin("COAST RUSH", true)
	call_deferred("start")


func start() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	loading.advance(1, .2)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# 실행 스크립트의 최초 컴파일은 메인 스레드에서 수행한다.
	var packed: PackedScene = load("res://scenes/race.tscn")
	loading.advance(2, .55)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var game := packed.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	loading.advance(3, 1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	queue_free()
