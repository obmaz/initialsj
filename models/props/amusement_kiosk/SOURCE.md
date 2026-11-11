# 놀이공원 매점

현재 형상은 팩의 GLB 원본, 진입점은 [model.tscn](model.tscn)입니다. 치수·피벗·UV와 움직이는 부품의 연결점은 [모델 계약](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

프로젝트에서 직접 작성한 미터 기준 건축 모델입니다. 본체8×4×6.5m, 두께 있는 지붕·차양·지주·판매대·환기구를 포함합니다. 원점은 바닥, 출입·판매면은+Z입니다.

벽은 기존 생성형 전용 이미지 `assets/environment/building-front-elevations.png`와 `building-side-elevations.png`의 매표·매점 영역(번호8)을 사용합니다. 정면에는 판매창·창턱·차양이, 측면에는 벽 마감이 대응하며 다른 모델의 빌더에 의존하지 않습니다. 이미지 출처는 [환경 이미지 기록](../../../assets/environment/README.md), 제작 계약은 [모델 제작 지침](../../../docs/MODEL_PIPELINE.md)을 따릅니다.
