# Initial SJ — Coast Rush

[게임 실행](https://obmaz.github.io/initialsj/) · [게임 규칙](docs/GAMEPLAY.md) · [개발·검사·배포](docs/DEVELOPMENT.md) · [아키텍처](docs/ARCHITECTURE.md) · [모델 제작](docs/MODEL_PIPELINE.md)

Godot **4.7.2 / GL Compatibility** 기반의 가로 화면 3D 아케이드 레이싱 게임입니다. 프로젝트 진입점은 [project.godot](project.godot)입니다.

| 모드 | 구성 |
| --- | --- |
| TOUR | 15개 테마·16개 경로의 5구간 단독 타임어택. 실제 분기 도로와 제한시간 |
| TRACK01 / FUJI LAKESIDE | 호수·마을·고가 교차·뱅킹, 8대·3랩 |
| TRACK02 / SUNCOAST SPEEDWAY | 16대 분산 롤링 스타트, 완주 상위3개와 차량별 베스트 전광판 |
| TRACK03 / MIDNIGHT HARBOR | 야간 항만·연속 드리프트·컨테이너 야적장, 8대·3랩 |
| TRACK04 / AZURE RIVIERA | 해안·시골 마을·협곡·아치 붕괴·하트 드리프트, 8대·3랩 |
| TRACK05 / SCARLET GORGE | 노을·현수교·점프·상판 붕괴·주회별 낙석, 8대·3랩 |

주행은 모든 모드에서 같은 실제 3D 차체·노면·가드레일 물리를 사용합니다. 선택 차량은 NIMORI H, VELTRIX S, IRONVALE V8, STRAUD 6R이며 차량별 능력과 니트로·음원이 다릅니다. 모델의 치수는 도로와 같은 미터 단위를 사용합니다. 도로·지형·구조물·차량·식생을 포함한 3D 형상은 GLB 원본과 `.tscn` 조립 씬으로 관리합니다.

## 실행

```sh
./tools/setup_env.sh
./tools/godot --path .
```

키보드는 W/S 또는 ↑/↓로 가속·제동, A/D 또는 ←/→로 조향, Space로 드리프트, Shift로 니트로, E로 오버드라이브 셀, P/Esc로 일시정지합니다. 터치와 게임패드 조작·화면 동작은 [게임 규칙](docs/GAMEPLAY.md)을 참고합니다.

## 작업별 문서

| 작업 | 기준 문서 |
| --- | --- |
| 코딩 컨벤션·폴더·헬퍼·주석 | [CODING_STYLE.md](docs/CODING_STYLE.md) |
| 환경 구성·검사·웹 배포 | [DEVELOPMENT.md](docs/DEVELOPMENT.md) |
| 코드 책임·주행과 시각 모델 경계·메모리 수명 | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| 특정 오브젝트·차량·빌딩만 제작·검사·커밋 | [MODEL_PIPELINE.md](docs/MODEL_PIPELINE.md), [모델 제작 스킬](.agents/skills/model-authoring/SKILL.md) |
| 차량별 음원 제작·재생 | [VEHICLE_AUDIO.md](docs/VEHICLE_AUDIO.md) |
| 출처·라이선스 | [ASSET_LICENSES.md](docs/ASSET_LICENSES.md) |
| 요청받은 APK 빌드·Dropbox 전달 | [ANDROID.md](docs/ANDROID.md), [APK 전달 스킬](.agents/skills/dropbox-apk/SKILL.md) |

`main` 푸시는 검사만 실행합니다. “배포” 요청은 APK를 로컬 빌드해 Dropbox 플러그인으로 전달하는 뜻이며, 웹·GitHub Pages는 명시 요청 시에만 게시합니다. 검사 결과·미리보기·내보내기는 Git에서 제외한 `build/`에 보관합니다.

GLB 편집 원본은 [model_sources](model_sources/README.md)에 보존합니다. 원본은 미사용 리소스 정리 대상에서 제외하며 배포 파일은 `python3 tools/optimize_models.py`로 재생성합니다.
