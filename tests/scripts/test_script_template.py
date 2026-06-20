import subprocess, sys, py_compile
from pathlib import Path

TEMPLATE = Path("skills/re-scripting/script_template.py")


def test_template_exists():
    assert TEMPLATE.is_file(), "script_template.py missing"


def test_template_compiles():
    # Raises py_compile.PyCompileError on syntax errors.
    py_compile.compile(str(TEMPLATE), doraise=True)


def test_template_has_help():
    # The skeleton must expose a --help (argparse) and exit 0.
    r = subprocess.run([sys.executable, str(TEMPLATE), "--help"],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "usage" in r.stdout.lower()
