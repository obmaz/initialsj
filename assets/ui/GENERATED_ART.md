# UI 이미지 출처

해안의 채도·방향광·입체 형상을 기준으로 제작합니다. 로딩 이미지는 실제 가상 차량 NIMORI·VELTRIX·IRONVALE의 렌더를 참고했습니다. 메인·차고 배경 위 차량은 주행과 같은 차량 팩토리의 캐시 렌더입니다. 코스 카드의 콘셉트 이미지와 실제 게임 캡처는 아래에서 구분합니다.

| 사용 에셋 | 원본·제작 방식 |
| --- | --- |
| [로딩·엔진 스플래시](coast-rush-splash.png) | 생성 원본 `exec-e1703f50-1054-4f9e-8e75-13ee0fa00d26.png` |
| [메인 해안](home-coast.png) | 생성 원본 `exec-83b2a747-ade7-4946-9dca-db44ebbc8894.png` |
| [차고](garage-bay.png) | 생성 원본 `exec-013bcb89-1cda-4f48-ab68-254e386b4aee.png` |
| [후지 코스 카드](course-fuji.png) | 콘셉트 생성 원본 `exec-8be49d29-fe68-4ee5-94d1-43c803ed3ae1.png` |
| [스피드웨이 코스 카드](course-speedway.png) | 콘셉트 생성 원본 `exec-80a07cec-f581-4b02-b13d-d7cb3c6984e7.png` |
| [야간 항만·리비에라·협곡 코스 카드](course-scenery-atlas.png) | 생성형 이미지 `exec-0e0791b7-8d8d-43c8-bf68-5826cc23d485.png`. 후지·스피드웨이 콘셉트 아트를 화풍 참고로 사용. 세 풍경을 AtlasTexture로 분리해 공유하며 차량·문구 없는 코스 일러스트로 통일 |

사용한 생성 PNG 원본은 로컬의 Git 제외 폴더 `generated_images/`에 보존합니다. 배포 사본은 이 문서 옆에 둡니다. 외부 사진·실존 제조사 로고·원본 아케이드 게임 에셋을 합성하지 않습니다. 제목·버튼·성능 막대·진행 표시는 모바일 가독성을 위해 UI 코드로 별도 렌더링하며 도로·미니맵도 게임이 생성합니다.

## 게임 로고

[initialsj-logo.svg](initialsj-logo.svg)는 [tools/bake_logo.py](../../tools/bake_logo.py)가 번들 Roboto Bold Italic 윤곽선으로 만드는 벡터 워드마크입니다. 글꼴은 Apache-2.0이며 [라이선스](../fonts/Roboto-LICENSE.txt)를 보존합니다. 아이보리·청록 글자와 주황색 사선, 작은 부제를 사용하며 시스템 글꼴에 의존하지 않습니다.

메인·로딩 화면이 같은 SVG를 사용합니다. 제작 도구는 `web/coast-rush-shell.html`의 `<!--logo:start-->` 구간에도 동일한 SVG를 삽입해 엔진 다운로드 전부터 표시합니다. 변경 후 `python3 tools/bake_logo.py`를 실행하고 SVG와 셸을 함께 커밋합니다. 실행에는 fontTools가 필요합니다.
