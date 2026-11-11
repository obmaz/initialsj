# 모델 제작과 분업

오브젝트·차량·빌딩 하나를 다른 AI나 모델 제작 도구로 작업할 때의 공통 계약입니다. 모델마다 폴더를 소유하고 정의 파일을 자동 탐색하므로 중앙 등록표를 함께 수정하지 않습니다.

## 작업 단위

```text
models/
  model_definition.gd          공통 데이터 계약
  model_catalog.gd             정의 탐색·ID 조회
  shared/                      공통 기하·정적 씬 로더
  vehicles/hatch/              NIMORI 시각 모델
    definition.tres
    build.gd                   또는 차체 model.glb/model.tscn
    SOURCE.md
    textures/                  이 모델 전용 이미지
  props/convenience_store/     편의점 모델
    definition.tres
    build.gd                   또는 단일 메시 씬
    material.tres              전용 재질이 필요할 때
    SOURCE.md
  buildings/city_twin_tower/   도시 빌딩 한 종류
    definition.tres
    build.gd
    SOURCE.md
```

기존 선택 차량의 시각 ID는 `hatch`(NIMORI), `wedge`(VELTRIX), `muscle`(IRONVALE), `gt`(STRAUD)입니다. `sport`는 교통 차량용입니다. 소품은69종과 예외 처리용 `fallback`, 도시 빌딩은12종의 팩을 사용합니다. 네온 상가·입체 간판은 GLB를 가져오는 `.tscn` 팩이며 전용 외벽 이미지를 공유합니다.

**한 모델 작업의 기본 변경 범위는 해당 폴더 하나입니다.** 새 이미지·재질·메시·출처도 같은 폴더에 둡니다. 다른 모델의 `build.gd`를 가져다 참조하거나 공용 아틀라스를 덮어쓰지 않습니다. 공통 도우미는 `models/shared/`의 API를 사용하고 전용 표현은 팩 내부 파일로 만듭니다.

주행·오디오·선택 목록·코스 배치·공용 셰이더를 함께 바꿔야 하는 요청은 통합 작업으로 구분합니다. 시각 모델 팩만 추가한 커밋은 검사·미리보기 대상으로 자동 등록됩니다. 선택 가능한 새 차량의 능력·오디오나 새 소품의 코스 배치는 통합 담당이 별도로 연결합니다.

## 제작 의뢰에 포함할 정보

| 항목 | 전달할 내용 |
| --- | --- |
| 대상과 범위 | 모델 분류·ID·작업 기준 커밋·허용 폴더 |
| 외형 | 참고 이미지·색상·재료·디테일 우선순위, 정면·측면·후면 요구 |
| 실척 | 가로×높이×깊이(m), 원점과 정면 방향, 차량 대비 크기 |
| 동작 부품 | 휠·렌즈·브레이크등·배기구 연결 방식 |
| 텍스처 | 정면/측면 구분, UV·재질 슬롯, 원하는 생성형 이미지 |
| 예산 | 아래 메시·재질·이미지 기준과 대상 기기 |
| 제출 | 팩 파일·출처·검사 결과·미리보기·해당 폴더만 포함한 커밋 |

이미지 생성 도구는 재질·광고·참고 이미지를 만들고, 3D 제작 도구는 실제 부피·면·UV가 있는 모델을 제출합니다. 차량·건물의 문·창·로고는 전용 UV로 배치하고 큰 건물 이미지를 한 면에 무작정 늘리지 않습니다.

## 정의 파일

공통 스크립트는 [model_definition.gd](../models/model_definition.gd)입니다. 필드는 다음과 같습니다.

| 필드 | 계약 |
| --- | --- |
| `contract_version` | 현재1. 계약 변경은 통합 작업에서 수행 |
| `category`, `id` | `props`·`vehicles`·`buildings`, 폴더명과 같은 소문자 ID |
| `order` | 목록 순서. 기존 ID의 의미를 바꾸거나 다른 팩의 순서를 수정하지 않음 |
| `builder_path` | 팩 내부 `build.gd`. 공통 팔레트 변환기는 `models/shared/` 사용 |
| `scene_path` | 정적 `.glb`·`.gltf`·`.tscn`. 소품·차량에서 지원 |
| `source_mesh_path` | 원본 메시. CC0 팔레트 빌더의 입력 또는 단일 표면 메시 |
| `material_path` | 소품·빌딩 전용 재질. 비어 있으면 공통 재질 또는 메시 내장 재질 |
| `source_path` | 팩 내부 `SOURCE.md`. 제작 방법·원본·라이선스·변형 내용을 기록 |
| `metre_scale`, `target_height` | 소품의 단위 변환과 성목 높이. 신규 모델은 미터로 만들어 배율1을 우선 |
| `base_size`, `parameters` | 모델별 조립 치수·휠·림·렌즈·빌딩 범위 등 |
| `tags` | `tree`·`building`·`rural` 등 배치에 필요한 의미 |
| `visibility_range`, `placement_limits` | 표시 거리와 배치 스케일의 허용 범위 |

형상 진입점은 빌더·정적 씬·원본 메시 중 하나입니다. 팔레트 빌더는 원본 메시 경로를 함께 사용합니다. 정의에는 리소스 경로를 문자열로 저장해 목록 조회만으로 모든 텍스처·메시를 메모리에 올리지 않습니다.

## 좌표와 크기

- 공통 단위는 **1 Godot 단위=1m**, 위쪽은 `+Y`입니다. 루트 회전·스케일은 적용해 내보냅니다.
- 차량 앞쪽은 `-Z`, 차체 중심의 노면 기준은 원점입니다. 차체 길이 약4.3m를 기준으로 제작하고 기존 충돌체·주행 파라미터를 시각 작업에서 변경하지 않습니다.
- 일반 건물의 출입면은 `+Z`, 지면 기준 피벗은 아래쪽입니다. 바닥 부지·처마·간판 등 돌출부를 실제 메시와 AABB에 포함합니다.
- 소품 모델의 `base_size`와 배율을 함께 확인하고 최종 미터 치수는 미리보기의 AABB로 확인합니다. 기존 모델은 템플릿 치수와 배율이 나뉘어 있을 수 있습니다.
- 편의점·주유소는 차량 여러 대가 들어가는 부지, 성목은 수종에 맞는 수고로 만듭니다. 보기 좋게 배치하려고 모델 자체를 임의로 축소하지 않습니다.

## 형상 인터페이스

| 분류 | `build.gd` 진입점 | 출력 |
| --- | --- | --- |
| 소품 | `static func build(definition: Resource) -> ArrayMesh` | 실제 미터 치수로 변환할 단일 표면 메시 |
| 차량 | `static func build(car: Node3D) -> void` | `car.body` 아래의 차체, 공통 효과 연결 |
| 빌딩 | `static func build(definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]` | `position`·`size`가 있는 유한한 양의 크기 파츠 |

차량 빌더는 `car.mat()`·`block()`·`wedge()`·`add_headlight()`·`add_boost_jet()`·`add_active_aero()`와 `models/shared/vehicle_geometry.gd`를 사용합니다. 브레이크 재질은 `car.brake_lights`에 등록합니다. `parameters`의 휠 반경·반트랙·반휠베이스·두께·림 배율·`ride_offset`·스포크 수·림 색을 함께 맞춥니다. 이 값은 시각 모델의 제원이며 물리 능력치는 [vehicle_catalog.gd](../scripts/vehicles/vehicle_catalog.gd)가 소유합니다.

가동 스포일러는 `car.add_active_aero(parts, pivot, drop, pitch)`에 `Array[MeshInstance3D]`, 차체 로컬 피벗(m), 하강량(m), 회전각(rad)을 전달합니다. 부품은 불투명 `StandardMaterial3D`와 단일 표면을 사용합니다. 어댑터가 한 메시로 묶고 정적 차체 병합에서 제외합니다. 교통 차량은 기존 정적 차체에 합쳐 효과 방출기와 가동 부품을 따로 만들지 않습니다. 부스트 유지 시간과 복원은 공통 효과 어댑터가 소유하고 모델 팩에는 프레임 처리·파티클·주행 능력 변경을 넣지 않습니다.

소품 정적 씬은 메시 하나·표면 하나로 내보내고 UV·법선·재질을 포함합니다. 차량 정적 씬은 차체만 넣으면 공통 휠을 사용합니다. 자체 휠을 쓰면 `parameters.scene_wheels=true`와 MeshInstance3D 이름 `wheel_fl`, `wheel_rl`, `wheel_fr`, `wheel_rr`을 제공합니다. 휠의 로컬 `+Y`가 회전축이며 휠 노드 원점이 회전 중심이어야 합니다. 렌즈·배기구 좌표는 정의의 `headlamp_positions`·`headlight_position`·`exhaust_positions`로 연결합니다.

정적 씬에는 Node3D·MeshInstance3D·Marker3D만 둡니다. 주행 스크립트·카메라·광원·물리·입력·애니메이션 플레이어는 공통 런타임에서 관리합니다. 차량의 텍스처·ShaderMaterial·다중 표면은 무텍스처 부품 병합 대상에서 제외합니다.

## 렌더 예산과 재질

- 일반 소품: 단일 표면, **3200삼각형 미만**. 차량: 공통 휠·효과 메시를 포함해 **2만 삼각형 미만**. 빌딩: 조립 파츠32개 이하.
- 이미지 기본 크기는1024~2048px를 우선하고 필요한 경우에만 확대합니다. 반복 표면·외벽은 GPU 압축(`compress/mode=2`)과 밉맵을 사용합니다.
- 반복 재질은 미터 기준 UV 밀도를 맞추고, 자연 지형의 삼면 투영은 이음새·샘플 비용을 검토해 선택합니다. 투명·양면 재질과 재질 슬롯은 필요한 면에만 사용합니다.
- 같은 형상의 공통 도시 외벽은3스킨, 일반 전면·측면 아틀라스는2스킨을 지원합니다. 일반 배치의 `skin: 0|1`은 정면·측면과 입체 처마색을 함께 선택하며 메시·실척은 유지합니다. 이 계약은 [facade_variants.gd](../scripts/environment/facade_variants.gd)가 소유합니다. 공용 스킨 확장은 통합 작업이며 독립 모델 작업에서는 다른 팩의 이미지나 공용 셰이더를 수정하지 않습니다.

전용 재질·이미지는 팩 내부에 둡니다. 공통 정면·측면 아틀라스는 현재 모델들이 공유하므로 독립 작업에서는 해당 이미지를 직접 덮어쓰지 않고 `material_path`로 전용 재질을 연결합니다.
- 모델마다 프레임 처리·타이머·새 광원·충돌체를 추가하지 않습니다. 배치·LOD·메시/재질 캐시·해제는 공통 어댑터가 담당합니다.

## 검사·제출

```sh
./tools/godot --headless --path . --editor --import --quit
./tools/godot --headless --path . --script res://tools/check_models.gd -- --vehicle hatch
./tools/godot --path . --script res://tools/preview_model.gd -- --vehicle hatch --output build/reports/hatch.png
python3 tools/verify_repository.py
```

`--prop convenience_store`, `--building city_twin_tower`로 대상만 바꿉니다. 모델 검사에서 ID·출처·진입점·치수·휠·표면·메시 예산·리소스 존재를 확인합니다. 실제 정면·측면·후면과1m 격자도 확인합니다. 출력물은 `build/reports/`에 두고 커밋에는 넣지 않습니다.

커밋에는 해당 모델 폴더의 정의·형상·전용 재질·텍스처·`.uid`·`.import`·출처만 포함합니다. 사용하지 않는 대안·원본 복사본·검토 캡처는 제외합니다. 원본과 라이선스 중 재배포에 필요한 파일은 보존합니다.

통합 전 최신 `main`에 리베이스하고 모델 검사·전체 검사·웹 내보내기를 실행합니다. 다른 모델과 공통 파일의 변경은 모델 커밋에서 분리하고, 공통 계약 수정이 필요하면 그 이유와 필요한 API를 명시한 통합 커밋으로 처리합니다. 커밋 작성자·커미터는 저장소의 [AGENTS.md](../AGENTS.md)를 따릅니다.

## 다중 표면 식생

`models/vegetation/<id>/`는 SJRPG의 원본 GLB·Mesh를 보존합니다. 일반 소품과 달리 두 표면(줄기·잎)과 최대4358삼각형을 허용합니다. [tour_vegetation.gd](../scripts/environment/tour_vegetation.gd)가 원본 다중 표면·생성된 LOD를 보존한 메시와 재질을 한 번 만들고120m 셀·최대12개씩 공유하며, 모델 정의의 미터 높이를 적용합니다. 공통 생성형 잎·수피의 출처는 `models/shared/foliage/SOURCE.md`에 기록합니다. 검사는 전체 모델 검사에 포함합니다.
