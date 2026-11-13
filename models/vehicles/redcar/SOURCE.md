# redcar 모델

사용자가 Initial SJ에 사용하도록 제공한 `redcar.glb`가 원본입니다. 별도의 제작자·라이선스 정보는 제공되지 않았습니다.

- 업로드 원본: `model_sources/vehicles/redcar/uploaded.glb` — 수정·삭제 금지, 원본 전용 보호 목록에 포함합니다.
- 편집 원본: `model_sources/vehicles/redcar/model.glb` — 실척 1.92×1.42×4.65m, 정면−Z·지면 피벗.
- [제작 도구](../../../tools/author_imported_vehicles.py)는 UV를 보존해 형상을 단순화하고 사진 텍스처를 JPEG로 포장합니다. 투어 전용은1024px, 플레이어는2048px입니다.
- 모델 재생성은 업로드 원본을 입력으로 하며 기존 편집본은 해시별 `build/reports/model-backups/`에 먼저 보존합니다. 이후 공용 최적화 도구로 배포 파일을 생성합니다.
- 유저 차량은 네 휠을 회전 피벗으로 분리하고 도장·트림을 분리합니다. UV0는 사진, UV1은 리버리 좌표입니다. 이펙트2슬롯을 지원하며 오픈카 변형은 없습니다.

[플레이어 모델 편집 도구](../../../tools/refine_player_models.py)는 원본 UV·텍스처·형상을 유지하고 차체와 휠의 가중 법선만 다듬습니다. 업로드 원본은 변경하지 않습니다.
