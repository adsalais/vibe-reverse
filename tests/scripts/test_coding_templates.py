import py_compile
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

PY = Path("skills/re-coding/python_template.py")
RS = Path("skills/re-coding/rust_template.rs")


def test_python_template_compiles():
    py_compile.compile(str(PY), doraise=True)


def test_python_template_has_help():
    r = subprocess.run([sys.executable, str(PY), "--help"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "usage" in r.stdout.lower()


def test_rust_template_compiles_and_tests(tmp_path):
    # tool-optional: rustc is baked into the air-gapped image; skip where absent.
    if shutil.which("rustc") is None:
        pytest.skip("rustc not installed")
    binp = tmp_path / "t"
    c = subprocess.run(["rustc", "--test", str(RS), "-o", str(binp)],
                       capture_output=True, text=True)
    assert c.returncode == 0, c.stderr
    r = subprocess.run([str(binp)], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "test result: ok" in r.stdout
