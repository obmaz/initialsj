# 실행 UI 이미지 출처

이 문서는 현재 게임에서 사용하는 파일의 출처와 재생성 경로만 기록합니다. 신규 화면의 시안은 [이미지 가이드](../../art_sources/ui/README.md)에 있으며 아직 게임에 반영하지 않았습니다.

| 실행 에셋 | 원본·제작 경로 |
| --- | --- |
| `pre_race/`의 화면 프레임·환경판·공통 부품 | [제작 원본과 해시](../../art_sources/ui/runtime_sources/pre_race/layout.json), [재생성 도구](../../tools/bake_pre_race_art.py). OpenAI 이미지 생성 결과를 재단·조립한 파일입니다. 원본은 [runtime_sources](../../art_sources/ui/runtime_sources/README.md)에 보존합니다. |
| [튜닝샵 배경](backgrounds/tuning_bay.png) | OpenAI 생성 원본 `exec-cb9f33a4-843a-48c2-96d1-352dc9734c42.png`. 실행 중 차량·문구·버튼은 별도 UI가 표시합니다. |
| [코스 카드 아틀라스](courses/menu_scenery.png) | OpenAI 생성 원본 `exec-b936d9c1-ce5d-48ee-8c61-76c2615c76b0.png`. 1536×1024 이미지의 여섯 508×508 영역을 `.tres`에서 공유합니다. |
| 웹 워드마크 | [SVG 제작 원본](../../art_sources/ui/runtime_sources/branding/initialsj_logo.svg), [제작 도구](../../tools/bake_logo.py). 번들 Roboto Bold Italic 윤곽을 사용하며 [글꼴 라이선스](../fonts/Roboto-LICENSE.txt)를 유지합니다. |

워드마크 제작 도구는 `web/coast-rush-shell.html`의 `<!--logo:start-->` 구간도 함께 갱신합니다. 실제 메뉴의 제목·버튼·성능·진행 정보는 번역 가능한 텍스트와 컨트롤이며, 차량 미리보기는 실제 선택 모델을 사용합니다. 외부 게임의 이미지·로고를 실행 에셋에 합성하지 않습니다.
