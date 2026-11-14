# rev3 UI 에셋과 HTML 조립 검증

디자인 정본은 [UI 이미지 가이드](../../README.md)입니다. 이 폴더는 해당 원화를 분리한 제작 자료와 검증 도구이며 새 디자인 기준을 추가하지 않습니다. 현재 게임 UI는 이 팩에서 설치한 부품과 실제 컨트롤을 사용합니다. 3D 모델·경기·저장은 기존 게임의 실제 데이터를 따릅니다.

## 바로 확인하기

[index.html](index.html)을 열면 원화 대신 분리한 PNG와 아이콘 아틀라스를 조립합니다. 왼쪽 화면 안 버튼으로 메뉴를 이동하고, 오른쪽 목록에서 부품을 숨겨 뒤의 패널과 배경을 확인할 수 있습니다. 글자는 기본적으로 숨겨 원화와 비교하고 한국어·영어를 켜면 실제 글꼴로 별도 렌더링합니다.

파일 URL에서 브라우저가 글꼴이나 픽셀 읽기를 제한하면 저장소 루트에서 다음 로컬 서버를 실행합니다. 외부 게시·웹 배포는 하지 않습니다.

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

브라우저에서 `http://127.0.0.1:8765/art_sources/ui/kit/rev3/index.html`을 엽니다.

| 위치 | 용도 |
| --- | --- |
| [portable/manifest.json](portable/manifest.json) | 파일·해시·화면 좌표·부품 계층·기능 ID·9슬라이스·아틀라스 UV의 공통 계약 |
| [portable/sprites/](portable/sprites/) | 원화에서 자른 패널·버튼 바탕·아이콘·사진·상태 표시 PNG |
| [portable/atlases/](portable/atlases/) | 작은 아이콘을 묶은 아틀라스, 사방 2px 가장자리 복제 여백 |
| [portable/godot/](portable/godot/) | Godot 4 `AtlasTexture`·`StyleBoxTexture` 템플릿 |
| [portable/backgrounds/](portable/backgrounds/) | UI가 없는 공용 배경. 가려진 부분을 생성형으로 복원 |
| [portable/fonts/](portable/fonts/) | 한국어·영문 검증에 공통 사용하는 Noto Sans KR와 OFL 라이선스 |
| [layouts.json](layouts.json) | 편집하는 화면 분리 영역·동작·텍스트 자리의 정본 |
| [inputs/source.json](inputs/source.json) | 생성형 복원 배경의 출처와 원본 해시 |
| [preview/](preview/) | HTML 검증 코드와 원화 좌표 비교에 사용하는 배경 자료 |

원화 29장과 주행 상태 비교표에서 따로 떼어 낸 네 순간을 합쳐 33개 조립 화면을 제공합니다. 비교표 자체는 `reference_only`이며 하나의 게임 HUD로 사용하지 않습니다. 부품 파일은 내용 해시로 중복을 제거하고 화면·기능에 연결하는 이름은 매니페스트의 `id`로 유지합니다.

## 두 종류의 비교

**원화 재조립 비교**는 원화의 보이는 풍경을 보존한 비교용 배경과 분리 PNG를 같은 좌표로 합칩니다. 버튼·패널·그림·아이콘을 개별 DOM 요소로 그리고 작은 아이콘은 실제 아틀라스를 사용합니다. 원화 통이미지를 화면 배경으로 다시 띄우지 않습니다. 원화 파일은 겹쳐 보기와 차이 계산에서만 읽습니다.

**복원한 게임용 배경**은 원화에 가려져 있던 구역까지 생성형으로 복원한 공용 배경 위에 같은 부품을 올립니다. 가려진 풍경은 원화에 정보가 없으므로 새로운 복원 결과입니다. 비교용 배경의 국소 복원 경계를 게임 배경으로 사용하지 않습니다. 투명도·다른 배경 모드로 UI의 알파 가장자리와 배경 의존 여부도 확인합니다.

`preview/backdrops/`와 원화는 좌표 재현 검증 자료입니다. 게임 배경은 `background.clean_plate`를 사용합니다. `world_preview_only` 배경, `vehicle_placeholder` 차량 그림, 노드·코스 선 그림은 주행·GLB 미리보기·실제 지도 데이터를 대체하지 않습니다. 특히 주행·결과 화면에서는 PNG 풍경 대신 게임 월드 위에 UI만 얹습니다.

## 게임으로 가져가는 계약

1. 필요한 부품을 `portable/`에서 게임의 `assets/ui/rev3/`로 가져오고 Godot 임포트 자료를 생성합니다. 현재 [설치 도구](../../../../tools/install_rev3_ui.py)와 [실행 UI](../../../../docs/MOBILE_UI.md)가 이 계약을 연결합니다.
2. 좌표와 자식 좌표는 모두 해당 원화의 전역 픽셀입니다. 부모 아래에 둘 때만 부모 원점을 뺍니다. `size`에 기록된 실제 크기를 사용하며 1671px 너비 원화도 임의로 늘리지 않습니다.
3. OS 안전 영역에서 `scale = min(safe_width / source_width, safe_height / source_height)`를 구하고 원점·크기·터치에 같은 변환을 적용합니다. 조립 HTML은 휴대폰·폴드 비율과 안전 영역을 이 방식으로 확인합니다.
4. `button`은 실제 `TextureButton`/`Button`, `slider`·`progress`는 실제 Range 상태, `glyph`는 독립 텍스처로 연결합니다. `action`은 연결할 기능 ID이며 HTML의 메뉴 이동 예제가 실제 경기·저장 로직을 구현한 것은 아닙니다.
5. 큰 패널·버튼은 `nine_slice`와 `StyleBoxTexture`로 모서리 두께를 보존합니다. 아이콘은 `AtlasTexture.region`과 `filter_clip`을 사용합니다. 흰색 아이콘의 알파와 미세한 원화 색을 보존하며 3D용 조명·톤 매핑을 UI에 적용하지 않습니다.
6. 제목·이름·시간·기어·속도·볼륨·해금 문구는 실제 번역 가능한 Label로 그립니다. `text_slots`는 HTML에서 읽는 예제 배치이고 기록 값은 예시입니다. 실제 카탈로그·경기 결과·옵션 저장값을 연결합니다.
7. 이펙트 슬롯 수·미지원 항목·모달 입력 차단·뒤로가기·최소 터치 영역을 게임 컨트롤에서도 적용합니다. HTML은 화면 단위로 로드하며, 게임도 모든 화면의 텍스처를 한꺼번에 유지하지 않습니다.

Godot 템플릿의 리소스 접두부는 `res://assets/ui/rev3/`입니다. 다른 위치로 가져오면 함께 바꿉니다. 템플릿은 독립적인 가져오기 자료입니다. 실제 앱은 공통 좌표 조립기와 네이티브 입력을 사용하며, Godot 렌더 검증은 별도로 수행합니다.

현재 앱의 메뉴 설계 공간은 1280×720입니다. 이식할 때 원화 좌표를 해당 공간으로 변환한 뒤 기존 `MenuLayout`의 안전 영역 변환을 한 번만 적용하거나, 원화 좌표를 직접 다루는 새 컨트롤에서 같은 안전 영역 계약을 구현합니다. 기존 메뉴의 터치 상수에 새 이미지만 바꾸어 끼우지 않습니다.

## HTML 검증이 확인하는 범위

HTML은 에셋 분리·좌표·크기·여백·알파·아틀라스 UV·문자 길이·입력 위치를 빠르게 반복 확인하기에 적합합니다. 같은 PNG와 좌표 계약을 사용하면 Godot에서도 같은 2D UI를 재현할 수 있습니다.

HTML의 일치는 Godot 화면의 최종 합격을 뜻하지 않습니다. Godot의 텍스처 필터·글꼴 메트릭·Canvas 스케일·안전 영역·모달 포커스·모바일 터치, 실제 GLB와 월드, 비동기 로딩·메모리는 엔진에서 별도로 확인합니다. HTML을 게임 안에 넣거나 HTML 버튼 로직을 경기 로직으로 옮기는 방식이 아닙니다.

## 재생성과 확인

UI 전용 도구의 선택 의존성은 [requirements-ui.txt](../../../../tools/requirements-ui.txt)에 고정합니다. Pillow·numpy·scipy와 Chromium 검증용 Playwright를 사용합니다. 기본 CI 검사나 자동 배포에 이 렌더 검사를 추가하지 않습니다.

```sh
python3 tools/bake_rev3_ui.py
python3 tools/check_rev3_ui.py
```

한 화면의 분리 영역을 고친 뒤에는 해당 화면만 먼저 재생성할 수 있습니다. 이후 검증기는 전체 화면을 다시 확인합니다.

```sh
python3 tools/bake_rev3_ui.py --screens settings,tour_hud
python3 tools/check_rev3_ui.py --chromium /usr/bin/chromium
```

검증기는 원화 보존·PNG 해시·아틀라스 영역을 확인하고, 실제 Chromium 캡처를 원화와 픽셀 비교합니다. 대표 화면의 휴대폰·폴드·가로 화면 조합, 44px 터치 목표, 한국어·긴 영어, 메뉴 이동·슬라이더 입력을 확인합니다. 원화 비교 중 원화 `<img>`를 렌더링하지 않았는지도 검사합니다. 캡처·JSON 측정 결과는 Git에서 제외한 `build/reports/rev3-ui-kit/`에 둡니다.

`reference/rev3/`와 `inputs/`는 보존하는 편집 원본입니다. `portable/fonts/`의 글꼴과 라이선스도 보존합니다. 부품을 바꾸려면 분리 영역이나 원본을 수정하고 생성하며 이 폴더들을 미사용 리소스로 삭제하지 않습니다. 생성 PNG의 파일명은 해시에 따라 바뀔 수 있으므로 개별 파일명 대신 매니페스트의 기능 ID를 사용합니다. 도구는 이전 매니페스트가 소유하고 해시까지 일치하는 교체 생성물만 정리합니다.
