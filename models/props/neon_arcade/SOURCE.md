# neon_arcade

편집 원본은 [원본 GLB](../../../model_sources/props/neon_arcade/model.glb)이며, 이 팩의 GLB는 재생성되는 배포 파일입니다. 원본을 삭제하거나 배포 GLB를 직접 수정하지 않습니다. 진입점은 [model.tscn](model.tscn)입니다. 치수·피벗·UV와 움직이는 부품의 연결점은 [모델 계약](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

이 프로젝트에서 오프라인으로 조립해 GLB로 내보낸 정적 모델입니다. 실행 중에는 `model.tscn`이 `model.glb`를 가져오며 빌더 스크립트·물리·광원을 포함하지 않습니다. 1단위=1m, 정면+Z, 피벗은 지면입니다.

건물 실척은23×12.83×24.1m이며 기단·입체 창틀·처마·코너 기둥·LED 띠·옥상 환기 장치를 포함합니다. STARCADE 아케이드와 VOLTWORKS 전자상가의 같은 형상·다른 외벽2종을 사용합니다.

생성형 전용 이미지와 공유 재질의 출처는 [환경 에셋](../../../assets/environment/README.md#네온-전자상가)을 따릅니다. UV·UV2·정점색을 GLB에 보존하며 외벽·발광 표시는 `material.tres`가 소유합니다. 실제 문·창·기단 위치를 바꿀 때는 GLB와 UV를 함께 수정합니다.
