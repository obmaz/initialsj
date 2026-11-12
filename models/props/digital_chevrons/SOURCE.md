# digital_chevrons

3m×1.5m LED 안내판 표시면. UV0는 화면 전체0~1이며 기존 안내판 케이스와 방향 변환을 유지합니다. 시간 기반 점등은 공통 야간 안내 셰이더에서 수행합니다.

Initial SJ 자체 제작. `tools/bake_roadside_models.py`로 오프라인 제작한 GLB이며 실행 중 정점을 생성하지 않습니다. 편집 원본은 `model_sources/props/digital_chevrons/model.glb`에 보존합니다. 기본 실행은 기존 원본을 덮어쓰지 않습니다. 의도한 재생성은 `--replace`로 요청하며 이전 바이트를 해시별로 먼저 백업합니다.
