extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var failures: int = await preload("res://tests/modes_checks.gd").new().run(self)
	quit(1 if failures else 0)
