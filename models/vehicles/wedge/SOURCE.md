# wedge (VELTRIX S)

편집 원본은 [원본 GLB](../../../model_sources/vehicles/wedge/model.glb)이며, 이 팩의 GLB는 재생성되는 배포 파일입니다. 원본을 삭제하거나 배포 GLB를 직접 수정하지 않습니다. 진입점은 [model.tscn](model.tscn)입니다. 치수·피벗·UV와 움직이는 부품의 연결점은 [모델 계약](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

Lamborghini Huracán Super Trofeo Evo 실사 스타일 모델을 기반으로 최적화하여 제작된 미드십 슈퍼 레이스카 모델입니다.

후면의 거대한 카본 GT 레이싱 윙은 ActiveRearAero 노드로 가동되며 가속·제동에 반응합니다. 유지 시간·복원은 공통 차량 효과 어댑터가 담당하며 실제 차량 능력치는 변경하지 않습니다.

도장면은 원본 차체 외판을 PaintShell로 분리했습니다. 형상·법선·비도장 UV를 보존하며 전용 UV0는 livery-uv.json의 종방향·단면 원통 전개를 사용합니다. 리버리 이미지는 models/shared/vehicle_liveries/SOURCE.md를 따릅니다.

기존 BodyShell 전체 메시도 투어 교통 차량의 이전 연결 경로를 위해 읽기 전용으로 보존합니다. 플레이어 표시에는 PaintShell+TrimShell만 사용하고 전체 메시를 중복해서 그리지 않습니다.
