#!/usr/bin/env python3
"""render_report.py — render a RE REPORT.md into a self-contained REPORT.html.

The HTML embeds the provided report.css (inlined → one portable file) and turns the
findings confidence tags ([confirmed]/[likely]/[hypothesis]/[refuted]) into colored
badge spans. Markdown is the source of truth; HTML is generated, never hand-written.

Usage:
    python3 render_report.py <REPORT.md> [<out.html>]   # default out: REPORT.html beside input

The deterministic core is render(md_text, css_text) -> html_text (unit-tested).
"""
import argparse
import html as _html
import re
import sys
from pathlib import Path

CSS_PATH = Path(__file__).resolve().parent / "report.css"

_TAGS = ("confirmed", "likely", "hypothesis", "refuted")
# why: substitute on the markdown SOURCE — markdown passes inline HTML through, so the
# <span> survives conversion. A tag inside a fenced code block is also wrapped (rare;
# accepted limitation).
_TAG_RE = re.compile(r"\[(" + "|".join(_TAGS) + r")\]")


def _badge(m):
    name = m.group(1)
    return f'<span class="tag tag-{name}">{name}</span>'


def render(md_text, css_text):
    """Return a full self-contained HTML document for the report markdown.

    Pure + deterministic. Raises RuntimeError if the markdown library is unavailable.
    """
    try:
        import markdown
    except ImportError as e:  # pragma: no cover - exercised only without the lib
        raise RuntimeError(
            "the 'markdown' library is required to render HTML; it is baked into the "
            "air-gapped image (add it via requirements/python-tools.txt on a dev host)"
        ) from e

    body = markdown.markdown(_TAG_RE.sub(_badge, md_text),
                             extensions=["tables", "fenced_code"])
    m = re.search(r"^#\s+(.+)$", md_text, re.MULTILINE)
    title = _html.escape(m.group(1).strip()) if m else "RE Report"
    return (
        "<!doctype html>\n"
        '<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{title}</title>\n"
        f"<style>\n{css_text}\n</style>\n"
        '</head>\n<body class="report">\n'
        f"{body}\n"
        "</body>\n</html>\n"
    )


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Render a RE REPORT.md to a self-contained REPORT.html.")
    ap.add_argument("report_md", help="path to REPORT.md")
    ap.add_argument("out_html", nargs="?",
                    help="output path (default: REPORT.html beside the input)")
    args = ap.parse_args(argv)

    md_path = Path(args.report_md)
    if not md_path.is_file():
        ap.error(f"no such file: {md_path}")
    out_path = Path(args.out_html) if args.out_html else md_path.with_name("REPORT.html")
    css_text = CSS_PATH.read_text(encoding="utf-8") if CSS_PATH.is_file() else ""
    try:
        html_doc = render(md_path.read_text(encoding="utf-8"), css_text)
    except RuntimeError as e:
        print(f"render_report: {e}", file=sys.stderr)
        return 1
    out_path.write_text(html_doc, encoding="utf-8")
    print(out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
