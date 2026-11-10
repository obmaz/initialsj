extends Resource
# 모델 팩의 데이터 계약. 경로 문자열만 보관해 목록 조회가 메시·텍스처를 로드하지 않게 한다.
@export var contract_version: int = 1
@export var id: String = ""
@export var category: String = "props"
@export var order: int = 0
@export_file("*.gd") var builder_path: String = ""
@export_file("*.tscn", "*.glb", "*.gltf") var scene_path: String = ""
@export_file var source_mesh_path: String = ""
@export_file("*.tres", "*.res") var material_path: String = ""
@export_file("*.md") var source_path: String = ""
@export var tags: Array[String] = []
@export var parameters: Dictionary = {}
@export var base_size: Vector3 = Vector3.ZERO
@export var metre_scale: Vector3 = Vector3.ONE
@export var target_height: float = 0.0
@export var visibility_range: float = 310.0
@export var placement_limits: Vector2 = Vector2.ZERO
