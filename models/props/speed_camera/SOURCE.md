# speed_camera

높이6.3m의 실척 속도 카메라. 두 렌즈·차광 후드·제어함·콘크리트 기초·강재 사재를 갖습니다. +Z가 촬영 방향이고 가드레일 바깥의 지주에서 도로 쪽 −X로 뻗습니다.

Initial SJ 자체 제작. `tools/bake_roadside_models.py`로 오프라인 제작한 GLB이며 실행 중 정점을 생성하지 않습니다. 편집 원본은 `model_sources/props/speed_camera/model.glb`에 보존합니다. 기본 실행은 기존 원본을 덮어쓰지 않습니다. 의도한 재생성은 `--replace`로 요청하며 이전 바이트를 해시별로 먼저 백업합니다.
