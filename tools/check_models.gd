extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var category := ""
	var id := ""
	if not args.is_empty():
		if args.size() != 2 or args[0] not in ["--prop","--vehicle","--building"]:
			push_error("사용법: -- --prop ID | --vehicle ID | --building ID")
			quit(2)
			return
		category = {"--prop":"props","--vehicle":"vehicles","--building":"buildings"}[args[0]]
		id = args[1]
	var failures: int = await preload("res://tests/model_contract_checks.gd").new().run(self,category,id)
	quit(1 if failures else 0)
