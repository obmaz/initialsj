# 벚꽃나무

편집 원본은 [model.glb](../../../model_sources/props/cherry_blossom_tree/model.glb)입니다. 기존 원본을 덮어쓰지 않고 [공통 참나무 원본](../../../model_sources/shared/world_vegetation/town_oak_0/model.glb)에서 넓고 낮은 벚꽃 수형을 파생했습니다. [저작 도구](../../../tools/author_cherry_model.py)는 기존 벚꽃 원본도 자동 덮어쓰지 않습니다. 줄기와 꽃 메시를 구분하며 조립 씬에서 실제 높이 약11.7m, 수관 폭 약18m로 사용합니다.

원형은 사용자 소유 obmaz/sjrpg의 town-oak-0.glb입니다. 원 출처와 기준 커밋은 [참나무 출처](../../vegetation/town_oak_0/SOURCE.md), 공유 나무 이미지의 조건은 [식생 출처](../../shared/foliage/SOURCE.md)를 따릅니다.

`blossoms.png`는2026-11-12 생성형 이미지로 만든 연분홍·아이보리 벚꽃 군집 전용 텍스처입니다. 기존 잎 이미지의 투명도만 별도로 사용하여 수관 외곽의 모양을 유지합니다. 바람·충돌·도로 배치는 모델에 포함하지 않습니다. 일반 소품 단일 메시 풀 대신 정적 씬으로 조립하는 `scene_only` 팩입니다.
