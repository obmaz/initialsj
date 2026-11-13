# bike 모델

사용자가 Initial SJ에 사용하도록 제공한 `bike.glb`가 원본입니다. 별도의 제작자·라이선스 정보는 제공되지 않았습니다.

- 업로드 원본: `model_sources/props/bike/uploaded.glb` — 수정·삭제 금지, 원본 전용 보호 목록에 포함합니다.
- 편집 원본: `model_sources/props/bike/model.glb` — 실척 0.85×1.44×2.05m, 정면−Z·지면 피벗.
- [제작 도구](../../../tools/author_imported_vehicles.py)는 UV를 보존해 형상을 단순화하고 사진 텍스처를 JPEG로 포장합니다. 투어 전용은1024px, 플레이어는2048px입니다.
- 모델 재생성은 업로드 원본을 입력으로 하며 기존 편집본은 해시별 `build/reports/model-backups/`에 먼저 보존합니다. 이후 공용 최적화 도구로 배포 파일을 생성합니다.
- 투어 전용 정적 외형입니다. 바퀴는 차체에 포함하며 주행·접지·충돌은 공통 교통 차체가 처리합니다.
