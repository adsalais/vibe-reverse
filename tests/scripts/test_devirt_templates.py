import py_compile
from pathlib import Path

TEMPLATES = [
    Path("skills/re-devirtualize/templates/triton_handler.py"),
    Path("skills/re-devirtualize/templates/miasm_lift.py"),
]


def test_exist():
    for t in TEMPLATES:
        assert t.is_file(), f"{t} missing"


def test_compile():
    for t in TEMPLATES:
        py_compile.compile(str(t), doraise=True)
