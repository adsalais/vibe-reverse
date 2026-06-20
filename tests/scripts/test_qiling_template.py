import py_compile
from pathlib import Path

T = Path("skills/re-dynamic/templates/qiling_emulate.py")


def test_exists():
    assert T.is_file(), "qiling_emulate.py missing"


def test_compiles():
    py_compile.compile(str(T), doraise=True)
