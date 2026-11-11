# 에셋 출처와 라이선스

현재 배포에 사용하는 에셋의 기준 문서입니다. 제작 방식·배열·원본 식별자는 각 폴더의 출처 문서를 따르고, 법적 라이선스 원문은 파일 옆에 보존합니다.

## 시각 모델과 이미지

| 에셋 | 출처 | 권리·라이선스 |
| --- | --- | --- |
| `models/vehicles/`, `models/buildings/`, 소품 GLB 팩 | 프로젝트에서 작성한 가상 차량·건축·형상 | 프로젝트 소유. 팩별 `SOURCE.md` 참조 |
| Quaternius 자연 모델14종 | [Ultimate Nature Pack](https://quaternius.com/packs/ultimatenature.html) | CC0 1.0. [원본·라이선스](../assets/environment/props/README.md) 보존 |
| 도로·가드레일·터널·기믹 구조 | 프로젝트의 GLB 코스 팩 | 프로젝트 소유 |
| 메뉴·차고·코스 카드·HUD 이미지 | 프로젝트용 생성 이미지와 자체 게임 캡처 | [UI 출처](../assets/ui/GENERATED_ART.md) 참조 |
| 노면·지면·파노라마·능선·외벽·트럭·컨테이너·광고 이미지 | 프로젝트용 생성 이미지 | [환경 출처](../assets/environment/README.md)와 아래 제작 기록 참조 |
| 게임 워드마크 | `tools/bake_logo.py`, 번들 Roboto 윤곽 | 프로젝트 소유. 글꼴 라이선스 함께 적용 |

모델 팩의 전용 이미지·메시·재질 출처는 해당 `SOURCE.md`에 기록합니다. 외부 모델은 원본 URL·제작자·허용 조건·실제 라이선스 원문을 함께 보존합니다. 생성 이미지도 사용한 도구의 상업 이용 조건과 입력 자료의 권리를 확인합니다. 실존 제조사 로고·외부 게임 원본 에셋을 배포 자료로 사용하지 않습니다.

## 환경 이미지 제작 기록

- [환경 README](../assets/environment/README.md): 도로·암석·구조물·건물 정면/측면·도시 외벽·하늘·컨테이너의 원본과 배열.
- [시골 마을](../assets/environment/rural-village-source.md): 집·가게10종의 정면·측면, 실제 프롬프트·원본 식별자·해시.
- [프로젝트 홍보](../assets/environment/project-promo-source.md): 사용자 소유 SJRPG·킹왕짱 홍보6종, 참고 자료·프롬프트·해시.
- [상품 광고](../assets/environment/product-ad-source.md): 가상 상품 광고30종의 원본 식별자·프롬프트·해시.

생성형 원본의 식별자·해시·실제 참조 자료는 출처 증빙이므로 보존합니다. 대체안·검토 캡처·사용하지 않는 디자인 연구는 현행 문서의 에셋 목록에 포함하지 않습니다.

## 오디오

| 파일 | 출처 | 라이선스 |
| --- | --- | --- |
| 차량별 엔진·부스터·점화·드리프트16파일 | `tools/bake_vehicle_audio.py`로 직접 합성. 외부 샘플 입력 없음 | 프로젝트 소유 |
| `web-loops.json` | 같은 합성 루프의 웹용 인코딩 | 프로젝트 소유 |
| 카운트다운·출발·보상·랩 효과음 | `tools/bake_cues.py`로 합성 | 프로젝트 소유 |
| `impact.wav` | [Godot Truck Town](https://github.com/godotengine/godot-demo-projects/tree/master/3d/truck_town/vehicles)의 `impact_1.wav`를 필터·리샘플·편집 | MIT, [원문](../assets/audio/GODOT-LICENSE.txt) 포함 |

세부 파일 적용 범위는 [오디오 라이선스](../assets/audio/LICENSE.txt), 제작·독립 소유 규칙은 [VEHICLE_AUDIO.md](VEHICLE_AUDIO.md)를 따릅니다. 배경 음악·음성은 사용하지 않습니다.

## 글꼴과 엔진

| 구성 | 라이선스 |
| --- | --- |
| Roboto Bold Italic·Black Italic | Apache License 2.0, [원문](../assets/fonts/Roboto-LICENSE.txt) |
| Liberation Sans Bold Italic | SIL Open Font License, [원문](../assets/fonts/LICENSE.txt) |
| Godot Engine4.7.2 | MIT |

라이선스 원문은 내보내기 프리셋에 포함합니다. 모델 추가 시 출처·원문을 해당 팩에 기록하고 [모델 검사](MODEL_PIPELINE.md)를 실행합니다.

SJRPG 식생7종과 생성형 수피·잎은 사용자 소유 프로젝트에서 복사했습니다. 원본 해시·제작 기록은 [식생 출처](../models/shared/foliage/SOURCE.md) 및 각 팩의 SOURCE.md를 따릅니다. 투어 도착지 파노라마5장과 바다 표면1장의 새 생성형 이미지는 [환경 출처](../assets/environment/README.md)에 기록합니다.
