# 배경음악

트랙은 `turbo_circuit.ogg`·`turbo_sprint.ogg`, 투어는 `neon_velocity.ogg`·`midnight_cruise.ogg`를 사용합니다. 사용자가 제공한 OGG 원본은 이름만 정리하고 바이트를 유지합니다. 출처는 [음원 목록](../assets/audio/LICENSE.txt)에 기록합니다.

## 곡 추가

1. 음원을 `assets/audio/music/`에 소문자 `snake_case.ogg`로 넣습니다.
2. [catalog.json](../assets/audio/music/catalog.json)의 `track` 또는 `tour` 배열에 전체 리소스 경로를 추가합니다. 파일명 접두부로 실행 중 용도를 추측하지 않으므로 다른 이름의 곡도 추가할 수 있습니다.
3. Godot 임포트를 실행하고 `.import`와 출처를 함께 커밋합니다. `loop=false`를 유지해야 곡 종료 후 다음 곡으로 넘어갑니다.
4. [음악 검사](../tests/background_music_checks.gd), 저장소 검사와 실제 웹 음악 재생 검사를 실행합니다.

[재생 제어기](../scripts/audio/background_music.gd)는 각 모드의 곡을 섞은 묶음으로 사용합니다. 한 묶음의 모든 곡을 들은 뒤 다시 섞으며 묶음 경계에서도 직전 곡은 피합니다. 새 경기에서는 다음 곡을 고르고, 투어 지역 전환 중에는 곡을 바꾸지 않습니다. 한 곡만 있는 목록도 지원합니다.

## 수명과 설정

설정의 `MUSIC`은 기본 ON이고 효과음 `SOUND`와 독립적으로 저장됩니다. 카운트다운·주행·결과에서 음악을 재생하며 결과에서는 음량을 낮춥니다. 일시정지·설정·앱 포커스 상실·로딩 중에는 멈추고 메뉴·차량 선택 복귀 시 음원 참조를 해제합니다. OFF 상태에서 출발하면 곡을 로드하지 않습니다.

긴 곡 전체를 PCM으로 미리 디코딩하거나 모든 곡을 캐시하지 않습니다. 네이티브는 선택한 OGG 한 곡을 비동기 로드해 스트리밍합니다. 웹은 [미디어 어댑터](../web/background_music.js)의 `HTMLAudioElement` 하나로 재생합니다. 내보내기 플러그인이 해당 OGG 원본을 PCK에 보관하므로 별도 외부 다운로드·도메인·오프라인 파일 목록은 필요하지 않습니다. 곡 교체·종료 시 Blob URL과 입력 리스너를 해제합니다. 브라우저의 자동 재생 제한에 걸리면 다음 사용자 입력 때 다시 시도합니다.
