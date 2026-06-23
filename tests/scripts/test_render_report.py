import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

pytest.importorskip("markdown")  # tool-optional: skip where the renderer dep is absent

RENDER_PY = Path("skills/re-report/render_report.py")


def _load():
    spec = importlib.util.spec_from_file_location("render_report", RENDER_PY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


SAMPLE_MD = (
    "# REPORT — sample\n\n"
    "## Findings\n"
    "- **[confirmed]** it does X.\n\n"
    "| a | b |\n|---|---|\n| 1 | 2 |\n"
)


def test_render_produces_self_contained_html():
    out = _load().render(SAMPLE_MD, ".tag-confirmed { color: green }")
    assert "<!doctype html>" in out.lower()           # full document
    assert ".tag-confirmed { color: green }" in out    # CSS inlined verbatim
    assert "<h1>" in out                               # heading rendered
    assert "<table>" in out                            # tables extension active
    assert 'class="tag tag-confirmed"' in out          # confidence badge span
    assert "[confirmed]" not in out                    # raw tag was replaced


def test_help_exits_zero():
    r = subprocess.run([sys.executable, str(RENDER_PY), "--help"],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "usage" in r.stdout.lower()


def test_cli_writes_html(tmp_path):
    md = tmp_path / "REPORT.md"
    md.write_text(SAMPLE_MD, encoding="utf-8")
    r = subprocess.run([sys.executable, str(RENDER_PY), str(md)],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    out = tmp_path / "REPORT.html"
    assert out.is_file()
    assert "<!doctype html>" in out.read_text(encoding="utf-8").lower()
