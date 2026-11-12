# GLB 편집 원본 — 삭제 금지

이 폴더는 재생성의 입력이며 Git으로 보존합니다. `.gdignore`와 내보내기 제외 설정 때문에 게임이 직접 읽지 않지만, **미사용·중복·임시 리소스가 아닙니다.** 용량 정리나 리소스 참조 검색 결과만으로 원본을 삭제하지 않습니다. 런타임 배포 파일은 [models/](../models/), 제작 계약은 [MODEL_PIPELINE.md](../docs/MODEL_PIPELINE.md)입니다.

## 폴더와 편집 위치

```text
model_sources/                           편집 원본, 내보내기 제외
  inventory.json                         보호할 GLB 경로·SHA-256 목록
  world-vegetation.json                   코스 노드 → 공통 식생 연결 규칙
  world/track_0/geometry.glb              도로·지형·구조물 원본
  vehicles/hatch/model.glb                차량 원본
  props/convenience_store/model.glb       소품 원본
  buildings/city_round_tower/model.glb    건물 원본
  vegetation/juniper/model.glb            독립 식생 모델 팩 원본
  shared/world_vegetation/juniper/model.glb  모든 코스가 공유하는 식생 원본

models/                                  배포용 GLB와 조립·게임 연결
  world/track_0/geometry.glb              자동 생성, 직접 편집 금지
  world/track_0/model.tscn                편집 가능한 배치·재질·제어기
  world/track_0/profile.tres              편집 가능한 주행 프로필
  shared/world_vegetation/<id>/          자동 생성 공통 GLB·조립 씬
```

원본·생성물의 상대 경로는 동일합니다. 차량·소품·빌딩·독립 식생은 원본 바이트를 그대로 전달하고, 코스와 공통 코스 식생은 모든 표면 속성이 같은 정점만 병합합니다. LOD·그림자·삼각형 수를 줄이지 않습니다.

공통 코스 식생의 ID는 `town_oak_0`, `town_oak_1`, `dark_fir`, `black_pine`, `spire_cypress`, `juniper`, `thorn_bramble`입니다. 해당 전용 원본을 수정하면 모든 연결 코스에 반영됩니다. 독립 모델 팩의 식생과 코스 식생은 현재 단위·임포트 이력이 다르므로 별도 원본입니다. 두 형상을 같은 것으로 추정해 덮어쓰지 않습니다. 양쪽을 변경하려면 각각의 실척·UV를 확인합니다.

코스 원본에 남아 있는 공통 식생 형상은 최초 코스를 복구할 수 있는 스냅샷입니다. 이 형상을 삭제하지 않으며, 공용 나무를 수정할 때 이 스냅샷을 편집하지 않습니다. 생성기는 연결된 스냅샷을 배포 GLB에서 제외하고 공용 원본을 참조합니다. 코스 하나에 별도 나무가 필요하면 새 공용 변형 원본과 ID를 만들거나 해당 연결을 명시적으로 해제하고 지역 형상으로 관리합니다. 정리 도구가 임의로 연결을 바꾸면 안 됩니다.

## 편집·재생성

```sh
# 원본을 바꾸지 않은 재생성. 입력 해시가 다르면 중단한다.
python3 tools/optimize_models.py

# 의도한 GLB 수정·추가 후, 입력 해시를 갱신하고 생성한다.
python3 tools/optimize_models.py --accept-source-changes

# 아무 파일도 쓰지 않는 원본·생성물 무결성 검사
python3 tools/optimize_models.py --check
```

도구는 Python 표준 라이브러리만 사용합니다. `inventory.json`에 등록된 원본이 하나라도 없으면 `--accept-source-changes`에서도 중단합니다. 이 옵션은 원본 삭제 승인이나 목록 축소 옵션이 아닙니다. 원본 누락 시 Git에서 해당 파일을 복원합니다. 등록 경로를 수동으로 지우거나 새 목록으로 덮어써서 검사를 우회하지 않습니다.

Git은 GLB를 바이너리로 취급하고 검사 대상 Python·JSON·씬 파일의 줄바꿈을 LF로 고정합니다. Windows와 Linux 사이에서 체크아웃할 때 줄바꿈만 달라져 생성물 해시가 바뀌는 일을 방지합니다. GLB 충돌은 텍스트 병합하지 않고 원본 편집을 먼저 해결한 뒤 배포 파일을 재생성합니다.

`models/`의 GLB를 직접 편집하면 무결성 검사가 실패합니다. 필요한 변경은 원본에 반영하고 재생성합니다. 생성기는 출력 경로를 `models/`로 제한하고 원본 해시를 다시 확인한 뒤 임시 파일을 원자적으로 교체합니다. 원본을 복사해 생성물로 덮어쓰거나, 생성물을 원본으로 역복사하지 않습니다.

로컬 저장소 검사·Android 빌드·수동 웹 배포와 [공통 CI의 무결성 단계](../.github/workflows/godot-checks.yml)가 같은 검사를 실행합니다. `python3 tools/check.py --static`은 원본 누락·생성물 변조·충돌 캐시의 신선도를 검사하며 앱을 빌드하거나 게시하지 않습니다. 재생성 후에는 Godot 임포트를 완료하고 실행 중인 게임을 다시 시작해 공통 모델 캐시를 새로 읽습니다.

원본 경로는 공개 제작 계약입니다. 단순 정리를 위해 이름·폴더를 바꾸지 않습니다. 이동이 필요하면 기존 파일을 먼저 보존하고 모든 연결·해시 목록·출처·검사를 함께 갱신하는 명시적인 마이그레이션으로 처리합니다. 파일·노드 이름에는 소문자 `snake_case`를 사용하되 기존 코스 연결 노드 이름은 보존합니다. `new`, `final2`, 날짜·버전별 복제 폴더를 만들지 않습니다.

## 연결·검증·제출

공통 식생 GLB의 `Visual` 노드, 줄기·잎 두 표면, 원점·실척을 유지하고 내보내기 전에 노드 변환을 형상에 적용합니다. 생성기가 `Model/Visual` 계층을 고정해 임포터의 단일 메시 루트 처리 차이를 없앱니다. 모델의 `.tscn` 연결과 배치는 유지되므로 원본에서 노드 이름·피벗을 바꾸면 연결 규칙도 검토해야 합니다. 도로를 바꾸면 주행 프로필·충돌·붕괴 경계도 검사합니다. 공용 나무를 바꾸면 사용하는 모든 코스에서 보일 크기·가지 방향·재질을 확인합니다.

변경한 원본, `inventory.json`, 생성된 GLB와 `.import`, `models/shared/world_vegetation/generated.json`을 함께 커밋합니다. 연결 규칙을 바꿨다면 `world-vegetation.json`과 생성된 `references.json`도 포함합니다. 보고서·측정 복사본은 Git에서 제외한 `build/reports/`에 둡니다. 원본의 제작·라이선스 출처는 각 모델 팩의 `SOURCE.md`와 [공통 식생 출처](../models/shared/foliage/SOURCE.md)에 유지합니다.
