#!/usr/bin/env python3
"""Run the owned engine failure corpus against the shared assertion runner."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("shared_godot_assertions", Path(os.environ["TOOLS_ROOT"]) / "helpers/godot-test.py")
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)

class RouterRunnerControls(unittest.TestCase):
    def execute(self, name, sentinel, timeout=45):
        native.run(os.environ["GODOT_BIN"], ROOT, ROOT / "tests/runner_fixtures" / name,
                   sentinel, timeout, environment=os.environ.copy())

    def test_failure_corpus_then_restored_pass(self):
        controls = [
            ("runtime_error_zero_exit.gd", "PASS runner-control runtime-error", 45),
            ("overwritten_failure.gd", "PASS runner-control overwritten-failure", 45),
            ("unreachable.gd", "PASS runner-control unreachable", 45),
            ("parse_error.gd", "PASS runner-control parse-error", 45),
            ("hang.gd", "PASS runner-control hang", 1),
            ("does-not-exist.gd", "PASS runner-control missing", 45),
        ]
        for name, sentinel, timeout in controls:
            with self.subTest(control=name), self.assertRaises((ValueError, OSError)):
                self.execute(name, sentinel, timeout)
        self.execute("pass.gd", "PASS runner-control reachable=1 assertions=1")

if __name__ == "__main__":
    unittest.main(verbosity=2)
