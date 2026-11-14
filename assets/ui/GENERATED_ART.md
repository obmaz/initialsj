# 실행 UI 이미지 출처

현재 게임은 승인된 [rev3 가이드](../../art_sources/ui/README.md)의 UI를 사용합니다. 원화와 HTML 비교 자료는 게임 실행 에셋과 분리합니다.

| 실행 에셋 | 원본·제작 경로 |
| --- | --- |
| [rev3 배경·카드·패널·아이콘](rev3/SOURCE.md) | OpenAI image_gen 원화, [분리·HTML 검증 자료](../../art_sources/ui/kit/rev3/README.md), [실행 설치 도구](../../tools/install_rev3_ui.py). 비교 전용 배경과 예시 차량·월드 스냅샷은 사용하지 않습니다. |
| rev3 글꼴 | Noto Sans KR 가변 글꼴·굵기 650. [OFL](rev3/fonts/OFL.txt)을 함께 보존합니다. |
| [슬라이더 노브](controls/slider_knob.svg) | rev3의 흰색·골드 팔레트로 그린 벡터 조작 부품입니다. |
| 웹 워드마크 | [SVG 제작 원본](../../art_sources/ui/runtime_sources/branding/initialsj_logo.svg), [제작 도구](../../tools/bake_logo.py). 번들 Roboto Bold Italic 윤곽과 [라이선스](../fonts/Roboto-LICENSE.txt)를 유지합니다. |

워드마크 도구는 웹 시작 셸의 로고 구간도 함께 갱신합니다. 게임 UI 제목·버튼·성능·진행 정보는 번역 가능한 텍스트와 컨트롤이며, 실제 차량은 선택한 GLB 모델을 사용합니다. 외부 게임 이미지·로고를 실행 에셋에 합성하지 않습니다.
