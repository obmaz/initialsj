#!/usr/bin/env python3
"""내보내기 플러그인이 관리 워커와 같은 버전의 셸·완전한 파일 목록을 생성했는지 검사한다."""
import argparse
import json
from pathlib import Path
import re


def verify(index):
    index = Path(index)
    stem = index.stem
    html = index.read_text(encoding="utf-8")
    worker = index.with_name(stem + ".service.worker.js").read_text(encoding="utf-8")
    match = re.search(r"^const CONFIG = (.+);$", worker, re.M)
    if not match:
        raise ValueError("관리 워커가 생성되지 않았습니다")
    config = json.loads(match[1])
    version = config.get("version", "")
    if not re.fullmatch(r"[a-f0-9]{64}", version) or f'window.INITIALSJ_OFFLINE_VERSION = "{version}";' not in html:
        raise ValueError("셸·워커의 내용 버전이 일치하지 않습니다")
    if "/*offline-bridge*/" in html or "window.initialsjOffline = (function" not in html:
        raise ValueError("오프라인 연결 코드가 삽입되지 않았습니다")
    files = config["coreFiles"] + config["engineFiles"]
    if config["index"] != index.name or config["engineFiles"] != [stem + ".wasm", stem + ".pck"]:
        raise ValueError("현재 엔진·게임 본체 파일 목록이 아닙니다")
    if index.name not in config["coreFiles"] or config["offline"] not in config["coreFiles"]:
        raise ValueError("메인·오프라인 안내 파일이 목록에 없습니다")
    for name in files:
        if Path(name).name != name or not (index.parent / name).is_file() or (index.parent / name).stat().st_size == 0:
            raise ValueError("내보내기 파일 누락 또는 잘못된 경로: " + name)
    print("웹 셸·관리 워커 버전·실제 파일 목록: PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args()
    try:
        verify(args.index)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
