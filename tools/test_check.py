"""프로세스가0을 반환해도 실제 엔진 오류를 놓치지 않는지 검증한다."""
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

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
