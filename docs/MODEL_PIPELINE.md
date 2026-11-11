# GLB 모델과 씬 제작

모든 3D 시각 형상은 GLB 원본과 `.tscn` 조립 씬을 사용합니다. 차량·건물·소품·식생과 도로·지형·다리·기믹·효과용 작은 형상도 같은 방식입니다. 런타임은 파일을 읽고 배치·재질·애니메이션·물리를 연결합니다.

## 모델 팩과 분업

```text
models/
  vehicles/hatch/         NIMORI 차량
    definition.tres      ID·치수·연결점
    model.glb            차체·휠·가동 스포일러
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

차량5종, 소품69종과 예외용 `fallback`, 빌딩12종, 식생7종을 자동 탐색합니다. 선택 차량은 `hatch`·`wedge`·`muscle`·`gt`, `sport`는 교통 차량입니다. 모델 목록을 읽을 때는 경로 문자열만 읽습니다.

**독립 모델 작업은 해당 팩 폴더 하나를 수정합니다.** GLB·전용 이미지·재질·씬·출처를 함께 제출하고 공용 아틀라스나 다른 모델의 파일을 수정하지 않습니다. 중앙 등록표를 추가할 필요가 없습니다. 주행 능력·음원·코스 배치·공용 셰이더 변경은 별도 통합 커밋으로 만듭니다.

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

공통 차체 셰이더의 정점 데이터는 COLOR=표면색, UV=금속성·거칠기, UV2=클리어코트·발광 강도입니다. 도장면의 COLOR.a=.5가 차량별 색 선택 마스크입니다. 이 데이터를 외부 도구가 일반 사진 UV로 덮어쓰지 않게 합니다. 별도 텍스처 셰이더를 도입하면 재질 어댑터와 검사를 함께 수정합니다.

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
| `mesh_ref` 메타정보 | `GLB 경로#메시 노드 경로`로 형상을 연결 |
| `scene_state` 메타정보 | 제어기가 사용할 노드 경로·배열·상태의 초기값 |

GLB의 메시 노드 이름을 유지하면 형상만 교체할 수 있습니다. `.tscn`의 반복 배치는 정점 복사 없이 같은 GLB 메시를 참조합니다. 편집기에서는 `GLBPreview`가 형상을 연결해 배치와 재질을 보여줍니다. [world_assets.gd](../scripts/rendering/world_assets.gd)는 게임에서 같은 자료를 프레임별로 읽고 [scene_state.gd](../models/shared/scene_state.gd)가 연결점을 복원합니다.

도로를 편집할 때는 GLB 노면과 `profile.tres`의 곡선·뱅킹·폭을 함께 맞춥니다. 붕괴 조각의 위치·이름·초기 위치 배열, 충돌체·균열·잔해·통과로도 함께 유지합니다. 일반 형상 교체가 이 초기 상태나 주행 규칙을 임의로 바꾸면 안 됩니다. 투어 팩은 원점(0,6,0)·진입 방향−π/2의 기준 좌표이며 배치 어댑터가 실제 분기 위치로 이동·회전합니다.

코스 하나의 작업은 해당 팩 폴더에서 완성합니다. 여러 모델의 공용 형상이나 게임 동작을 바꾸는 경우에만 어댑터·검사를 별도 통합합니다. 코스 전체를 개별 소품 수정 커밋에 섞지 않습니다.

## 검사·제출

```sh
./tools/godot --headless --path . --editor --import --quit
./tools/godot --headless --path . --script res://tools/check_models.gd
./tools/godot --headless --path . --script res://tools/check_world_assets.gd
./tools/godot --path . --script res://tools/preview_model.gd -- --vehicle hatch --output build/reports/hatch.png
python3 tools/verify_repository.py
```

`--prop convenience_store`, `--building city_twin_tower`로 모델을 골라 검사·미리보기 할 수 있습니다. 실척 격자에서 정면·측면·후면, 문·창·타이어·램프의 정렬을 확인합니다. 코스 변경은 실제 주행·분기·붕괴·낙석·복구 회귀 검사와 브라우저 렌더도 확인합니다. 변경한 GLB·씬·정의·재질·이미지·`.import`·`.uid`·출처만 커밋하고 보고서·캡처는 `build/reports/`에 둡니다. 라이선스와 원본의 출처는 유지합니다.
