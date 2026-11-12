# speed_display

높이15m·폭21.9m의 대형 LED 전광판 구조물. 도로 위 통과 높이8.7m 이상을 확보하고 두꺼운 강재 지주·트러스·점검 발판을 갖습니다. Screen은 +Z를 향하는 표시 원점입니다. 폭은 배치 어댑터가 실제 도로·갓길 폭에 맞추며 기록 표시는 Label3D가 소유합니다.

Initial SJ 자체 제작. `tools/bake_roadside_models.py`로 오프라인 제작한 GLB이며 실행 중 정점을 생성하지 않습니다. 편집 원본은 `model_sources/props/speed_display/model.glb`에 보존합니다. 기본 실행은 기존 원본을 덮어쓰지 않습니다. 의도한 재생성은 `--replace`로 요청하며 이전 바이트를 해시별로 먼저 백업합니다.
