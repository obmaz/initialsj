# GLB 모델과 씬 제작

모든 3D 시각 형상은 GLB와 `.tscn` 조립 씬을 사용합니다. 편집 원본은 [model_sources/](../model_sources/README.md)에 보존하고 `models/`의 GLB는 원본에서 생성합니다. 차량·건물·소품·식생과 도로·지형·다리·기믹·효과용 작은 형상도 같은 방식입니다. 런타임은 파일을 읽고 배치·재질·애니메이션·물리를 연결합니다.

## 모델 팩과 분업

```text
model_sources/vehicles/hatch/model.glb  편집 원본, 삭제·생성물 역복사 금지
models/                               배포 파일과 편집 가능한 조립 자료
  vehicles/hatch/         NIMORI 차량
    definition.tres      ID·치수·연결점
    model.glb            원본에서 생성한 차체·휠·가동 스포일러
    model.tscn           GLB 조립
    SOURCE.md            제작·이미지·라이선스
  props/neon_arcade/      네온 상가
    definition.tres
    model.glb
    model.tscn
    material.tres
    SOURCE.md
  buildings/city_twin_tower/  도시 빌딩 모듈
  vegetation/juniper/         줄기·잎 두 표면 식생
  world/track_0/             코스별 도로·지형·구조물
  shared/render_primitives/  공유 상자·파티클·타이어 자국 형상
```

차량5종, 소품84종과 예외용 `fallback`, 빌딩12종, 식생7종을 자동 탐색합니다. 선택 차량은 `hatch`·`wedge`·`muscle`·`gt`, `sport`는 교통 차량입니다. 모델 목록을 읽을 때는 경로 문자열만 읽습니다.

**독립 모델 작업은 해당 팩의 원본과 조립 자료를 수정합니다.** `model_sources/<분류>/<id>/`의 GLB, `models/<분류>/<id>/`의 전용 이미지·재질·씬·출처를 함께 제출하고 다른 모델의 파일은 수정하지 않습니다. 원본 해시 목록은 삭제 방지용이며 게임의 중앙 모델 등록표가 아닙니다. 주행 능력·음원·코스 배치·공용 셰이더 변경은 별도 통합 커밋으로 만듭니다.

## 외부 제작 의뢰 규격

| 항목 | 전달할 내용 |
| --- | --- |
| 범위 | 분류·ID·기준 커밋·허용 폴더 |
| 실척 | 가로×높이×깊이(m), 피벗·정면·노면 높이 |
| 외형 | 정면·측면·후면 참고, 재료·색·디테일 우선순위 |
| 움직임 | 휠 중심·회전축·스포일러·렌즈·배기구 연결점 |
| 텍스처 | UV·UV2·정점색 계약, 재질 슬롯, 전용 이미지 |
| 예산 | 삼각형·표면·이미지 크기와 대상 기기 |
| 제출 | GLB·씬·정의·출처·사이드카·검사·실척 미리보기 |

Blender 등에서 메시를 편집하거나 외부 AI로 제작할 수 있습니다. 모델을 교체하면서 ID·파일 위치·연결점 이름을 유지하면 경기 코드를 바꿀 필요가 없습니다. 실척·피벗·표면 수를 바꾸면 배치 여유와 충돌도 함께 검증합니다.

## 단위·축·정의

1단위=1m, 위쪽은 `+Y`입니다. 차량 정면은 `-Z`, 건물 출입면은 `+Z`, 지면 피벗은 아래쪽입니다. 차량 길이 약4.3~4.5m를 기준으로 제작합니다. GLB 내보내기 전에 단위·루트 회전·스케일과 소품 메시의 로컬 변환을 적용합니다. 런타임에서 정점을 변환하거나 단위를 다시 굽지 않습니다.

[model_definition.gd](../models/model_definition.gd)의 계약 버전은2입니다.

| 필드 | 계약 |
| --- | --- |
| `category`, `id`, `order` | 폴더와 일치하는 분류·ID, 목록 순서 |
| `scene_path` | 팩 내부 `.tscn`; GLB를 가져오는 단일 진입점 |
| `material_path` | 선택적인 팩 전용 재질 |
| `source_path` | 팩 내부 `SOURCE.md` |
| `parameters` | 차량 연결점·빌딩 모듈·재질 선택 등의 데이터 |
| `base_size` | 빌딩 모듈의 기준 치수 또는 소품의 치수 메타정보 |
| `tags`, `visibility_range`, `placement_limits` | 배치 의미·표시 거리·허용 스케일 |

소품은 메시1개·표면1개·3200삼각형 미만으로 제출합니다. 정적 모델 씬에는 Node3D·MeshInstance3D·Marker3D만 둡니다. 물리·카메라·광원·입력·게임 스크립트는 공통 런타임이 소유합니다. 전용 재질은 `material_path` 또는 GLB 내장 재질로 지정합니다. `parameters.vertex_facade=true`인 기존 공용 외벽 팩은 GLB의 중립 재질 대신 공용 외벽 셰이더를 연결합니다.

## 차량 연결

GLB는 차체·타이어·림·가동 부품을 소유합니다. 네 휠은 `wheel_fl`, `wheel_rl`, `wheel_fr`, `wheel_rr` 이름을 사용하고 노드 원점을 회전 중심에 둡니다. 휠의 로컬 `+Y`가 회전축입니다. `BodyShell`은 차체, `BrakeLights`로 시작하는 노드는 독립 발광 부품, `ActiveRearAero`는 가동 스포일러입니다. 부품을 수정할 때 이름과 피벗을 유지합니다.

도장면 분리·호환 메시·교체 부품·새 UV 계약은 [튜닝샵](TUNING_SHOP.md#도장면리버리-계약)을 따릅니다. 일반 차체 셰이더의 정점 데이터는 COLOR=표면색, UV=금속성·거칠기, UV2=클리어코트·발광 강도입니다. 전용 `PaintShell`만 UV0를 리버리 좌표로 사용합니다. 일반 차체 도장면의 COLOR.a=.5가 차량별 색 선택 마스크입니다. 이 데이터를 외부 도구가 일반 사진 UV로 덮어쓰지 않게 합니다. 별도 텍스처 셰이더를 도입하면 재질 어댑터와 검사를 함께 수정합니다.

`parameters`의 휠 반경·반트랙·반휠베이스·`ride_offset`, `headlamp_positions`, `headlight_position`, `exhausts`, `aero_drop`, `aero_pitch`를 형상에 맞춥니다. 브레이크 재질과 도장 유니폼은 차량별로 독립적입니다. 셰이더의 `vec4` 도장 유니폼에는 `Vector4`를 전달해 재질 복제 시 자료형과 값을 유지합니다. 부스트·연기·전조등·휠 회전은 [car.gd](../scripts/vehicles/car.gd)가, 능력치는 [vehicle_catalog.gd](../scripts/vehicles/vehicle_catalog.gd)가 소유합니다. 차량 전체 예산은2만 삼각형 미만입니다.

## 빌딩·식생·재질

빌딩은 GLB의 조립 파츠32개 이하를 사용합니다. 기준 치수는 `base_size`, 고정 높이의 층 띠는 `parameters.module_fixed_heights`에 기록합니다. 파츠 수·순서를 바꾸면 이 자료도 함께 맞춥니다. 도시의 실제 배치는 코스 씬에 저장됩니다.

식생은 줄기·잎 두 표면과 최대4358삼각형을 허용합니다. SJRPG에서 가져온 형상·UV와 출처를 유지하고 GLB 임포터의 LOD를 사용합니다. [tour_vegetation.gd](../scripts/environment/tour_vegetation.gd)는 생성형 잎·수피 재질을 연결해 공유하며 미터 높이를 적용합니다.

도시 외벽은3스킨, 일반 건물의 정면·측면은2스킨을 지원합니다. [facade_variants.gd](../scripts/environment/facade_variants.gd)가 같은 개체의 앞·옆 스킨을 맞추고 메시와 배치를 공유합니다. 사진은 실제 문·창·간판 위치의 UV에 연결합니다. 이미지 기본 크기는1024~2048px, 반복 재질은 VRAM 압축과 밉맵을 사용합니다.

## 코스 팩

`models/world/track_0`부터 `track_4`까지5개 서킷과 `tour_<stage>_<route>_<side>`43개 투어 진입 변형을 사용합니다. `stage`·`route`는0부터, `side`는0=왼쪽 진입, 1=중립, 2=오른쪽 진입입니다. 첫 지역은 중립 하나이며 이후14개 지역은 세 진입 형상을 갖습니다.

| 파일·자료 | 역할 |
| --- | --- |
| `geometry.glb` | 도로·지형·구조물·붕괴 조각의 실제 정점·법선·UV |
| `model.tscn` | 노드 배치·MultiMesh 버퍼·재질·광원·제어기·연결점 |
| `profile.tres` | 주행 곡선·길이·뱅킹·여유 폭·기믹과 읽기 의존성 |
| `collision.res` | 같은 노면·장벽 삼각형에서 생성한 압축 충돌 자료 |
| `collision.sources.json` | 충돌 자료의 입력·출력 해시와 삼각형 수, 빌드 검사 전용 |
| `mesh_ref` 메타정보 | `GLB 경로#메시 노드 경로`로 형상을 연결 |
| `scene_state` 메타정보 | 제어기가 사용할 노드 경로·배열·상태의 초기값 |

원본 GLB의 메시 노드 이름을 유지하면 형상만 교체할 수 있습니다. `.tscn`의 반복 배치는 정점 복사 없이 같은 GLB 메시를 참조합니다. 공통 식생은 [연결 어댑터](../models/shared/world_geometry_map.gd)가 생성된 `references.json`으로 해석합니다. 코스 `.tscn`은 기존 논리 노드 이름을 유지하고, 실제 공통 형상은 `models/shared/world_vegetation/<id>/`에서 읽습니다. 재질 슬롯의 내용이 같을 때만 바인딩 메시를 공유하고, 마지막 게임 씬이 나가면 캐시를 해제합니다. 바인딩된 공유 재질은 읽기 전용입니다. 개체별 변형은 별도 재질이나 인스턴스 자료로 표현하며 공유 재질을 나중에 직접 변경하지 않습니다.

편집기에서는 `GLBPreview`가 같은 연결 자료로 형상과 배치를 보여줍니다. [world_assets.gd](../scripts/rendering/world_assets.gd)는 게임에서 같은 자료를 프레임별로 읽고 [scene_state.gd](../models/shared/scene_state.gd)가 연결점을 복원합니다. `profile.tres`의 원래 의존성은 유지하며 어댑터가 공통 식생 씬의 비동기 미리 읽기 의존성으로 확장합니다.

도로를 편집할 때는 GLB 노면과 `profile.tres`의 곡선·뱅킹·폭을 함께 맞춥니다. 붕괴 조각의 위치·이름·초기 위치 배열, 충돌체·균열·잔해·통과로도 함께 유지합니다. 일반 형상 교체가 이 초기 상태나 주행 규칙을 임의로 바꾸면 안 됩니다. 투어 팩은 원점(0,6,0)·진입 방향−π/2의 기준 좌표이며 배치 어댑터가 실제 분기 위치로 이동·회전합니다.

코스 하나의 작업은 해당 팩 폴더에서 완성합니다. 여러 모델의 공용 형상이나 게임 동작을 바꾸는 경우에만 어댑터·검사를 별도 통합합니다. 코스 전체를 개별 소품 수정 커밋에 섞지 않습니다.

정적 충돌 자료는 편집 원본이 아닌 재생성 가능한 캐시입니다. 원본 GLB·조립 씬·주행 프로필이나 공통 충돌 코드를 바꾸면 아래 순서로 다시 생성하고 해당 팩의 두 파일을 함께 커밋합니다. 생성기는 입력과 출력 해시가 같은 팩은 다시 쓰지 않으며 `model_sources/`와 GLB를 수정하지 않습니다. 임포트가 오래된 GLB는 생성을 거부합니다. 입력 해시는 공통 생성 코드도 포함하므로 공통 코드 변경은 여러 팩을 갱신할 수 있습니다. 충돌 생성에 새 헬퍼를 도입하면 생성기의 `INPUTS`에도 추가합니다. 독립 검사기는 같은 목록과 각 코스의 필수 씬·프로필을 요구하므로 다른 코스의 캐시를 복사해 대신할 수 없습니다.

```sh
./tools/godot --headless --path . --editor --import --quit
./tools/godot --headless --path . --script res://tools/bake_world_collisions.gd
python3 tools/check_world_collisions.py
```

런타임은 다음 구간의 `collision.res`를 다른 의존성과 함께 미리 읽고, 같은 두 형상을 공유하는 물리 노드만 연결합니다. 엔진 내부 가속 구조 자체를 저장하는 방식은 아니므로 첫 물리 연결 비용은 남습니다. 노면·장벽 연결을 서로 다른 생성 단계로 나누고, 준비가 끝난 뒤 구간을 공개합니다. 저장된 삼각형과 기존 생성기의 위치·회전·충돌층 일치는 회귀 검사로 확인합니다. `collision.sources.json`은 APK·웹 내보내기에서 제외하며, 저장소 검사와 Android 빌드는 오래된 충돌 자료를 거부합니다.

### 곡률 캐시 계약

곡률의 원본은 코스 팩 `profile.tres`의 `Curve3D`와 길이입니다. [곡률 표](../scripts/track/circuit_curvature.gd)는 실행 중 생성하는 파생 자료이며 원본 GLB·프로필 대신 편집하지 않습니다. 새 서킷도 [CircuitTrack.reset()](../scripts/track/circuit_track.gd)에서 **프로필 적용 → 곡률 표 생성 → 주행 공개** 순서를 사용합니다. 코스별 빌더에서 공통 생성 단계를 우회하거나 코스 ID만 같은 다른 곡선을 오래된 표와 연결하지 않습니다.

| 변경 | 곡률 표 처리 |
| --- | --- |
| 새 코스 추가·프로필 다시 로드 | 공통 `reset()` 경로에서 새 표 생성 |
| 곡선 포인트·in/out 제어점·굽기 간격·길이 변경 | 변경한 곡선과 길이로 재생성. 높이만 바뀌는 포인트도 포함 |
| 다리 붕괴·낙석 등 중심선을 유지하는 변화 | 표 유지. 현재 통행 가능 여부는 별도 기믹·충돌·AI 판단에 반영 |
| 중심선과 길이가 같은 폭·뱅킹·외장 이미지 변경 | 수평 곡률 표 유지. 노면·장벽·폭·뱅킹의 정합성은 별도 검사 |

현재는 주행 중 `Curve3D.changed`나 길이 변경을 감지해 자동 갱신하지 않습니다. 런타임 도로 변형을 추가할 때는 중심선·길이를 직접 수정한 뒤 오래된 표를 계속 사용하면 안 됩니다. 새 곡선·표·노면·충돌 자료를 일관된 묶음으로 준비하고 공개 전에 교체하는 경로를 함께 구현합니다. 생성 비용은 로딩이나 분할 준비 단계에서 처리하고 매 물리 틱에 표 전체를 다시 만들지 않습니다. 표는 해당 코스 인스턴스와 함께 해제하며 지난 코스·옛 형상별 자료를 계속 쌓지 않습니다.

곡선·길이를 수정하거나 코스를 추가하면 [곡률 정합성 검사](../tests/circuit_curvature_checks.gd)에 해당 코스를 포함합니다. 원래 계산 대비 오차, 급커브·랩 경계·음수 거리·여러 바퀴 조회와 메모리 상한을 확인합니다. 노면을 바꾸면 위의 정적 충돌 자료도 재생성하고 실제 차체의 주행·접촉·게이트를 검사합니다.

투어는 아직 곡률 표를 사용하지 않습니다. 추후 도입 시 구간 인스턴스와 진입 형상별로 소유하고, 열린 도로의 이전 구간·두 갈림길·분기 재선택을 보존해야 합니다. 현재 곡률은 질의 거리의 앞뒤14m까지 참조하므로 구간 경계는 이웃 구간을 포함해 다시 계산하거나 기존 직접 계산을 유지합니다. 닫힌 코스의 반복 거리 조회를 열린 도로에 그대로 적용하지 않습니다.

## 검사·제출

```sh
python3 tools/optimize_models.py --accept-source-changes  # 의도한 원본 편집 후
python3 tools/optimize_models.py --check
./tools/godot --headless --path . --editor --import --quit
./tools/godot --headless --path . --script res://tools/check_models.gd
./tools/godot --headless --path . --script res://tools/check_world_assets.gd
./tools/godot --path . --script res://tools/preview_model.gd -- --vehicle hatch --output build/reports/hatch.png
python3 tools/verify_repository.py
```

`--prop convenience_store`, `--building city_twin_tower`로 모델을 골라 검사·미리보기 할 수 있습니다. 실척 격자에서 정면·측면·후면, 문·창·타이어·램프의 정렬을 확인합니다. 코스 변경은 실제 주행·분기·붕괴·낙석·복구 회귀 검사와 브라우저 렌더도 확인합니다. 해당 원본·해시 목록·생성물 무결성 기록·GLB·씬·정의·재질·이미지·`.import`·`.uid`·출처를 함께 커밋하고 보고서·캡처는 `build/reports/`에 둡니다. 라이선스와 원본의 출처는 유지합니다. 원본은 실행 참조가 없다는 이유로 정리하지 않습니다.

서울 익스프레스의 숭례문·남산 타워·금빛63타워와 네온 카니발의 유리 회랑은 `models/props/`의 독립 팩입니다. [오프라인 배치 도구](../tools/author_tour_landmarks.gd)가 모든 진입 형상에 동일 거리로 연결합니다. 고가 하부 교대는 노면 위 통과 공간을 유지하고 하부 횡진입만 막습니다. [나무 크기 도구](../tools/vary_world_tree_sizes.py)는 코스 MultiMesh의 위치·공유 GLB를 유지하며180m 구역별 저장 스케일을 바꿉니다. 이미 적용한 파일은 중복 확대하지 않습니다. 날씨·시간대의 현재 적용 범위는 [환경 설정 문서](TRACK_WEATHER.md)를 따릅니다. 서울의63타워는3200m, 남산 타워는3440m에 배치하며 [서울 배치 도구](../tools/refine_seoul_scene.gd)가3진입 변형을 함께 갱신합니다. 숭례문의 전용 석재·기와·단청 UV와 재질은 [팩 출처](../models/props/sungnyemun_gate/SOURCE.md)를 따릅니다.

[서울 형상 제작 도구](../tools/bake_seoul_landmarks.py)는 기존 원본이 있으면 기본적으로 중단합니다. 의도적인 자체 제작 형상 재생성은 `--replace-generated`로 이전 원본을 SHA-256별 `build/reports/model-backups/`에 먼저 보존합니다. 새 팩의 최초 Godot 임포트 뒤 `--configure-imports`를 실행하고 다시 임포트하면 정점색·유리 투명 재질을 GLB 재질에 연결합니다. 기존 `.import`의 UID와 다른 옵션은 보존합니다.

## 큰 조립 씬의 분할 준비

투어43진입 변형은 `model.tscn`이 노드 연결 상태와 조립 목록을 소유하고, 같은 팩의 `assembly/resources.tres`가 공유 재질·MultiMesh를, `assembly/part_*.tscn`이24개 이하의 저장 노드를 소유합니다. [분할 도구](../tools/split_world_scene.py)는 기존 조립 씬을 백업하고 부모 경로·이름·좌표·자원 참조를 유지해 분리합니다. GLB나 노면을 수정하지 않습니다. `python3 tools/split_world_scene.py --tour`로 전체 투어를 처리하며 이미 분할한 씬은 다시 분할하지 않습니다.

`WorldAssets`는 프레임 예산 안에서 작은 씬을 하나씩 원래 부모에 연결한 뒤 메시·상태·물리를 복원합니다. 큰 GLB의 `SceneState` 속성 순회도24노드·0.5ms 단위로 이어 가며 재정의된 메시와 공용 인스턴스 경로를 유지합니다. 기하 바인딩·월드 메타정보 연결은4노드, 저장 상태 디코딩은1노드씩 처리합니다. 저장 씬의 인자 없는 생성자는 기본 투어 프로필을 중복 초기화하지 않으며 트리 밖에서 프로필을 쓸 생성자는 단계를 지정하거나 명시적으로 `WorldAssets.profile()`을 호출합니다. 편집할 때는 해당 노드가 있는 `assembly/part_*.tscn` 또는 공유 자원을 수정하며 원본 GLB는 기존 위치에서 편집합니다. 새 조립 단위를 추가하면 루트의 `assembly_parts`와 프로필 읽기 의존성을 함께 갱신합니다. 충돌 검사·생성기는 모든 조립 파일과 공유 자원의 해시를 포함합니다. 직접 형상을 검사하는 `WorldAssets.geometry()`도 같은 조립 목록을 즉시 복원합니다. 도중 취소는 부분 조립 루트와 미리 읽기를 모두 해제합니다.


## 투어 진입 연결부와 서울 랜드마크

투어의 `RouteLibrary.ENTRY_RUNUP` 기본값은0으로 지역 앞의 추가 직진 연결부를 사용하지 않습니다. [프로필 제작 도구](../tools/author_tour_entry.gd)는0일 때 조립 씬에 보존된 원래 곡선을 복구하고, 이전에 늘어난 거리만큼 기믹·터널·프로필 의존성을 되돌립니다. 같은 명령을 다시 실행해도 거리를 다시 빼지 않습니다. [공용 GLB 진입부](../models/shared/tour_entry/SOURCE.md)의 편집 원본은 보존하며 현행 프로필에서는 읽지 않습니다. `inventory.json`의 `source_only`에 남겨 원본 해시·존재 검사를 유지하고 사용하지 않는 배포용 씬·GLB·재질은 제거합니다.

연결부를 다시 저작할 경우 `entry_buffer_length`, `entry_content_transform`, `entry_scene_path`로 원래 콘텐츠와 진입 길이를 구분합니다. 기존 world GLB와 조립 씬의 좌표·거리는 원래 콘텐츠 기준을 보존하며, 프로필 도구는 기존 오프셋과 새 길이의 차이만 적용합니다. 중심선·길이를 변경하면 곡률 표와 충돌 캐시를 재생성합니다. 원래 콘텐츠 거리로 배치하는 도구는 `WorldAssets.source_pose()`를 사용합니다. 노면은 배치 전 곡선을 샘플링한 뒤 월드 변환을 적용해 먼 좌표의 재베이크 누적 오차를 피합니다. 투어 기록·고스트는 현행 중심선의 `tour_routes_v3` 키로 구분하며 차량 해금·투어 여권은 유지합니다.

숭례문은 [전용 모델 팩](../models/props/sungnyemun_gate/SOURCE.md)에64×49×24m의 중층 지붕·홍예·단청을 보관합니다. 서울의 콘텐츠 거리620m에 놓이며 현재 추가 연결부가 없어 실제 주행 거리도620m입니다. 남산타워는 콘텐츠3440m·우측330m,63빌딩은3200m·좌측300m에 배치합니다. 서울만 카메라 원경을3000m로 늘리고 모델별 가시거리 제한은 유지합니다. 사용자가 폐기를 요청한 롯데 모티브 `seoul_sky_tower`는 원본·배포 팩·참조·원본 목록에서 함께 제거했습니다. 그 외 편집 원본은 계속 보존합니다.

야간 가로등·광고 투광등은 [오프라인 제작 도구](../tools/author_night_fixtures.py)의 GLB 원본을 최적화해 사용합니다. [코스 배치 도구](../tools/author_course_lighting.gd)가 코스별 `night_lighting.tscn`과 실제 노면 조명 위치 조회 텍스처를 만듭니다. 형상과 배치는 정적 자료이며 런타임은 제한된 실제 광원 풀과 발광 파라미터만 갱신합니다.

## 정적 조립 소품

`parameters.scene_only = true`인 소품은 여러 메시와 전용 재질을 보존하는 정적 씬입니다. 일반 단일 메시 소품 풀 대신 `SceneSource.instantiate_static()`으로 조립하며5000삼각형 이하·모든 표면 UV·각 메시 재질을 검사합니다. 모델 검사와 미리보기는 같은 분기를 사용합니다. 벚꽃처럼 줄기와 수관을 구분해야 하는 경우에 사용하고, 코스 반복 배치는 같은 메시·재질을 공유하는 구간별 MultiMesh로 나눕니다.
