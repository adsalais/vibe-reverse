# RE harness — all external tools, containerized.
# Build:  docker build -f requirements/Dockerfile -t re-harness .
# Use:    docker run --rm -it -v "$PWD:/work" re-harness
FROM debian:stable-slim

# 1) system tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd \
        ca-certificates curl git python3 \
    && rm -rf /var/lib/apt/lists/*

# 2) uv (the official image ships a static binary)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# 3) python tools in a uv venv; put it on PATH so `python` is the venv python
ENV RE_HARNESS_VENV=/opt/re-harness/venv
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN uv venv "$RE_HARNESS_VENV" \
    && uv pip install --python "$RE_HARNESS_VENV/bin/python" -r /tmp/python-tools.txt
ENV PATH="$RE_HARNESS_VENV/bin:$PATH"

# 4) Ghidra (optional — large; uncomment to bake it in)
# RUN apt-get update && apt-get install -y --no-install-recommends openjdk-17-jdk unzip wget \
#     && wget -O /tmp/ghidra.zip <release-url-from-github> \
#     && unzip -q /tmp/ghidra.zip -d /opt && rm /tmp/ghidra.zip
# ENV PATH="/opt/ghidra_VER/support:$PATH"

WORKDIR /work
