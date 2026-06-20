# Installing the harness's external tools

Two equivalent ways to get every external tool the harness uses.

## Option A — on your host (`setup.sh`)

```sh
sh requirements/setup.sh
```

Installs the system tools (via apt/brew) and the Python tools (angr, z3, …) into a
**stdlib `python3 -m venv`** at `$RE_HARNESS_VENV` (default `~/.local/share/re-harness/venv`).
Ghidra is printed as a manual step (it needs a JDK 21 + a large download).

## Option B — Docker (`Dockerfile`)

```sh
docker build -f requirements/Dockerfile -t re-harness .
docker run --rm -it -v "$PWD:/work" re-harness
```

Same tools, isolated; the container installs the Python tools **globally** (no
venv), so `python` is the image Python with angr/z3 available.

## The Python tools

- On the **host**, Python RE tools live in a stdlib venv — **never system Python**.
  In the **container**, they are installed globally (the image is the isolation).
- Location (host): `$RE_HARNESS_VENV` (override the env var to relocate it).
- The harness runs them via `"$RE_HARNESS_VENV/bin/python"`, falling back to
  `python3` when that path is unset (e.g. the global container install), so it
  works from any investigation directory.
- Add tools by editing `python-tools.txt`, then re-run `setup.sh` (or rebuild).

The skills assume every tool is already present (air-gapped) and call `python3`
directly. In the **container** that resolves to the global install; on a **host**,
activate the venv (or put `$RE_HARNESS_VENV/bin` on PATH) before running the skills.
