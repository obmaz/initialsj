extends Resource
# 코스 GLB·주행 프로필에서 생성한 정적 충돌 자료. 형상 편집 원본이 아니다.
@export var ground: ConcavePolygonShape3D
@export var barriers: ConcavePolygonShape3D
@export var solids: ConcavePolygonShape3D
@export var solid_triangles := 0
@export var ground_triangles := 0
@export var barrier_triangles := 0
