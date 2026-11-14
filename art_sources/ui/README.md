# 시작 전 화면 이미지 가이드

현재 검토 후보는 **rev2**의 세 장입니다. Horizon Chase Turbo의 경쾌한 아케이드 레이싱 분위기와 rev1의 구성을 유지하면서 색의 강도를 완화했습니다. 단순한 면과 밝은 풍경은 유지하며, UI는 차분한 데님 블루·코럴·골드를 공유합니다. 흰 아이콘과 선택 표시는 배경에서 구분되도록 남깁니다.

| 화면 | 이미지 | 구성 |
| --- | --- | --- |
| 시작 | [start.png](reference/rev2/start.png) | 주인공 차량, 제목 자리, 큰 진입 버튼 두 개 |
| 트랙 선택 | [track_select.png](reference/rev2/track_select.png) | 큰 코스 카드 세 장을 넘기는 구성, 날씨·시간, 진행 버튼 |
| 차량 선택 | [car_select.png](reference/rev2/car_select.png) | 차량 미리보기, 성능, 차량 카드, 튜닝·출발 버튼 |

가로형 모바일 화면을 위한 **시안**이며 게임에는 아직 적용하지 않았습니다. 새 디자인을 검토할 때는 이 세 장을 함께 사용합니다. HUD·설정·튜닝샵의 새 디자인까지 정의한 자료는 아닙니다.

제목·차명·코스명·버튼 문구는 번역 가능한 실제 텍스트를 얹도록 비워 두었습니다. 이미지 속 차량·코스 그림·성능 막대는 시안용이며 실제 모델·수치·트랙 중심선을 대체하지 않습니다. 구현 단계에서는 휴대폰·폴드의 안전 영역, 긴 번역, 44px 이상의 터치 영역을 별도로 확인합니다.

생성 파일·크기·해시·화면 간 참조 관계는 [rev2/source.json](reference/rev2/source.json)에 기록합니다. rev1은 색상 비교용으로만 보존합니다: [시작](reference/rev1/start.png)·[트랙 선택](reference/rev1/track_select.png)·[차량 선택](reference/rev1/car_select.png). 서로 다른 리비전의 부품을 섞지 않습니다.

이 폴더의 시안은 Godot 임포트와 제품 내보내기에서 제외합니다. 현재 게임 아트의 재생성 원본은 [runtime_sources](runtime_sources/README.md)에 분리하며 새 디자인 참고로 사용하지 않습니다.
