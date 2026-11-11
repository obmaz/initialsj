# basalt

편집 원본은 [원본 GLB](../../../model_sources/props/basalt/model.glb)이며, 이 팩의 GLB는 재생성되는 배포 파일입니다. 원본을 삭제하거나 배포 GLB를 직접 수정하지 않습니다. 진입점은 [model.tscn](model.tscn)입니다. 치수·피벗·UV와 움직이는 부품의 연결점은 [모델 계약](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

프로젝트에서 직접 제작해 GLB로 저장한 형상입니다. 단위와 제작 인터페이스는 [모델 제작 지침](../../../docs/MODEL_PIPELINE.md)을 따릅니다.

공통 생성형 암석 이미지 `assets/environment/generated-rock-variants.png`를 이 팩의 `material.tres`에서 참조합니다. 출처는 [환경 이미지 기록](../../../assets/environment/README.md#지질구조물-재질-변형)을 따릅니다. 사암은 원본 층리색을 유지하고 현무암은 낮은 채도·어두운 청회색으로 재질을 구분합니다. 표면 법선·거칠기·음영은 공통 암석 셰이더가 담당합니다.
