# muscle

편집 원본은 [원본 GLB](../../../model_sources/vehicles/muscle/model.glb)이며, 이 팩의 GLB는 재생성되는 배포 파일입니다. 원본을 삭제하거나 배포 GLB를 직접 수정하지 않습니다. 진입점은 [model.tscn](model.tscn)입니다. 치수·피벗·UV와 움직이는 부품의 연결점은 [모델 계약](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

프로젝트에서 직접 제작해 GLB로 저장한 형상입니다. 단위와 제작 인터페이스는 [모델 제작 지침](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

트렁크 뒤의 두꺼운 립 스포일러는8cm 하강·6도 회전합니다. 유지 시간·복원은 공통 차량 효과 어댑터가 담당하며 실제 차량 능력치는 변경하지 않습니다.

도장면은 원본 BodyShell의 기존 면만 PaintShell로 분리했습니다. 형상·법선·비도장 UV를 보존하며 전용 UV0는 livery-uv.json의 종방향·단면 원통 전개을 사용합니다. 리버리 이미지는 models/shared/vehicle_liveries/SOURCE.md를 따릅니다.

기존 BodyShell 전체 메시도 투어 교통 차량의 이전 연결 경로를 위해 읽기 전용으로 보존합니다. 플레이어 표시에는 PaintShell+TrimShell만 사용하고 전체 메시를 중복해서 그리지 않습니다.

차체 판면의 모서리 반경·후드 곡면과 휠 법선은 [전용 편집 도구](../../../tools/refine_player_models.py)로 다듬습니다. 최초 편집 전 GLB는 해시별 `build/reports/model-backups/`에 보존하며, 이미 처리된 편집본은 중복 가공하지 않습니다. 도장 마스크·실척·부품 피벗·자식 순서를 유지합니다.
