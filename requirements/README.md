# Installing the harness's external tools

Two equivalent ways to get every external tool the harness uses.

## Option A — on your host (`setup.sh`)

```sh
sh requirements/setup.sh
```

Installs the system tools (via apt/brew) and the Python tools (angr, z3, …) into a
**uv-managed venv** at `$RE_HARNESS_VENV` (default `~/.local/share/re-harness/venv`).
Ghidra is printed as a manual step (it needs a JDK + a large download).

## Option B — Docker (`Dockerfile`)

```sh
docker build -f requirements/Dockerfile -t re-harness .
docker run --rm -it -v "$PWD:/work" re-harness
```

Same tools, isolated; the venv is on `PATH`, so `python` is the venv Python.

## The Python venv (uv)

- Python RE tools live in a venv — **never system Python**.
- Location: `$RE_HARNESS_VENV` (override the env var to relocate it).
- The harness runs them via `"$RE_HARNESS_VENV/bin/python"` (or `uv run`), so it
  works from any investigation directory.
- Add tools by editing `python-tools.txt`, then re-run `setup.sh` (or rebuild).

`re-preflight` detects what's installed and points here for anything missing.
