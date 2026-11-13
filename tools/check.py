"""로컬·CI·웹 배포가 공유하는 검사 진입점. 설치·빌드·배포는 수행하지 않는다."""
import argparse
from pathlib import Path
import os
import re
import shlex
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "build/reports/checks"
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
GODOT_ERROR = re.compile(r"^(?:SCRIPT ERROR:|ERROR:)", re.M)


class CheckFailure(RuntimeError):
    pass


def run(label, command, *, godot=False, report_dir=REPORTS, timeout=900):
    report_dir.mkdir(parents=True, exist_ok=True)
    path = report_dir / (label + ".log")
    print(f"검사: {label} — {shlex.join(map(str, command))}", flush=True)
    try:
        with path.open("w") as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise CheckFailure(f"{label}: 제한 시간 초과. 로그: {path}") from error
    except OSError as error:
        raise CheckFailure(f"{label}: 실행 도구를 확인하세요: {error}") from error
    content = path.read_text(errors="replace")
    print(content, end="", flush=True)
    if result.returncode != 0:
        raise CheckFailure(f"{label}: 종료 코드 {result.returncode}. 로그: {path}")
    # 엔진은 일부 스크립트 오류에도0으로 종료하므로 실제 오류 로그도 실패로 취급한다.
    if godot and GODOT_ERROR.search(ANSI.sub("", content)):
        raise CheckFailure(f"{label}: Godot 오류가 있습니다. 로그: {path}")


def static_checks():
    formatter = os.environ.get("INITIALSJ_GDFORMAT_BIN")
    if not formatter:
        local = ROOT / "build/dev-venv/bin/gdformat"
        formatter = str(local) if local.is_file() else shutil.which("gdformat")
    if not formatter:
        raise CheckFailure("tools/requirements-dev.txt의 개발 도구를 설치하세요. docs/CODING_STYLE.md를 참고하세요.")
    run("style", [formatter, "--check", "scripts", "models", "addons", "tests", "tools"])
    run("python", [sys.executable, "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py"])
    # 원본 GLB·생성물·충돌 캐시의 신선도 검사도 여기에 포함된다.
    run("repository", [sys.executable, "tools/verify_repository.py"])


def engine_checks():
    engine = str(ROOT / "tools/godot")
    for label, arguments in [
        ("engine-version", ["--script", "res://tests/verify_engine.gd"]),
        ("import", ["--editor", "--import", "--quit"]),
        ("models", ["--script", "res://tools/check_models.gd"]),
        ("gameplay", ["--fixed-fps", "60", "--script", "res://tests/race_test.gd"]),
    ]:
        run(label, [engine, "--headless", "--path", ".", *arguments], godot=True)
    for name in ["install_bridge", "back_bridge", "fullscreen_bridge", "audio_lifecycle", "web_offline"]:
        run(name, ["node", f"tests/{name}_checks.cjs"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    phases = parser.add_mutually_exclusive_group()
    phases.add_argument("--static", action="store_true", help="엔진 없이 정적 검사만 실행")
    phases.add_argument("--engine", action="store_true", help="엔진·게임·브리지 검사만 실행")
    args = parser.parse_args()
    try:
        if not args.engine:
            static_checks()
        if not args.static:
            engine_checks()
    except CheckFailure as error:
        print(f"검사 실패: {error}", file=sys.stderr)
        return 1
    print("선택한 검사: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
