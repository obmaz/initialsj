# 공통 코스 식생

이 폴더의 GLB·조립 씬·연결 JSON은 [편집 원본](../../../model_sources/README.md)에서 생성합니다. 배포 파일을 직접 수정하거나 원본으로 역복사하지 않습니다.

7종 식생은 기존 코스 GLB에 보존된 형상을 공통 원본으로 분리했습니다. 형상·실척·두 표면의 순서·법선·접선·UV를 보존합니다. 원 제작·라이선스는 [식생 출처](../foliage/SOURCE.md)와 [식생 모델 팩](../../vegetation/)의 각 `SOURCE.md`를 따릅니다. 코스에서 사용하는 줄기·잎 재질은 해당 코스 조립 씬이 소유합니다.

편집 위치는 `model_sources/shared/world_vegetation/<id>/model.glb`입니다. `references.json`은 기존 코스의 연결 노드 이름을 해당 공통 씬으로 해석하며, `generated.json`은 원본·도구·생성물 해시를 기록하는 검증 자료로 앱에는 넣지 않습니다.
