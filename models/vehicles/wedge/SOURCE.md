# wedge

편집 원본은 [원본 GLB](../../../model_sources/vehicles/wedge/model.glb)이며, 이 팩의 GLB는 재생성되는 배포 파일입니다. 원본을 삭제하거나 배포 GLB를 직접 수정하지 않습니다. 진입점은 [model.tscn](model.tscn)입니다. 치수·피벗·UV와 움직이는 부품의 연결점은 [모델 계약](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

프로젝트에서 직접 제작해 GLB로 저장한 형상입니다. 단위와 제작 인터페이스는 [모델 제작 지침](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

후면 윙·엔드플레이트·상부 피스톤을 한 가동 메시로 묶습니다. 고정 하우징 안으로17cm 내려가며7도 회전합니다. 유지 시간·복원은 공통 차량 효과 어댑터가 담당하며 실제 차량 능력치는 변경하지 않습니다.

도장면은 원본 BodyShell의 기존 면만 PaintShell로 분리했습니다. 형상·법선·비도장 UV를 보존하며 전용 UV0는 livery-uv.json의 종방향·단면 원통 전개을 사용합니다. 리버리 이미지는 models/shared/vehicle_liveries/SOURCE.md를 따릅니다.

기존 BodyShell 전체 메시도 투어 교통 차량의 이전 연결 경로를 위해 읽기 전용으로 보존합니다. 플레이어 표시에는 PaintShell+TrimShell만 사용하고 전체 메시를 중복해서 그리지 않습니다.
