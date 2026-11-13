"""프로세스가0을 반환해도 실제 엔진 오류를 놓치지 않는지 검증한다."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import check
from check import CheckFailure, run


class CheckProcessTests(unittest.TestCase):
    def execute(self, source, **options):
        with tempfile.TemporaryDirectory() as folder, contextlib.redirect_stdout(io.StringIO()):
            return run("fixture", [sys.executable, "-c", source], report_dir=Path(folder), **options)

    def test_script_error_with_zero_exit_is_failure(self):
        with self.assertRaisesRegex(CheckFailure, "Godot 오류"):
            self.execute("print('SCRIPT ERROR: Invalid call')", godot=True)

    def test_ansi_engine_error_with_zero_exit_is_failure(self):
        with self.assertRaisesRegex(CheckFailure, "Godot 오류"):
            self.execute("print('\\x1b[31mERROR: Failed to load script\\x1b[0m')", godot=True)

    def test_nonzero_exit_is_failure(self):
        with self.assertRaisesRegex(CheckFailure, "종료 코드 7"):
            self.execute("raise SystemExit(7)")

    def test_warning_does_not_fail_successful_run(self):
        self.execute("print('WARNING: driver advisory'); print('PASS')", godot=True)

    def test_timeout_is_failure(self):
        with self.assertRaisesRegex(CheckFailure, "제한 시간 초과"):
            self.execute("import time; time.sleep(60)", timeout=.1)

    def test_windows_venv_formatter_is_found_without_activation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            formatter = root / "build/dev-venv/Scripts/gdformat.exe"
            formatter.parent.mkdir(parents=True)
            formatter.touch()
            with patch.object(check, "ROOT", root), patch.object(check.sys, "platform", "win32"), patch.dict(
                check.os.environ, {"INITIALSJ_GDFORMAT_BIN": ""}
            ):
                self.assertEqual(check.formatter_path(), str(formatter))

    def test_formatter_override_has_priority(self):
        with patch.dict(check.os.environ, {"INITIALSJ_GDFORMAT_BIN": "chosen-formatter"}):
            self.assertEqual(check.formatter_path(), "chosen-formatter")
