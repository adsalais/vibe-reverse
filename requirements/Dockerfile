# RE harness — all external tools, containerized.
# Build:  docker build -f requirements/Dockerfile -t re-harness .
# Use:    docker run --rm -it -v "$PWD:/work" re-harness
# Base: python:3.12-slim-trixie (Debian 13 + CPython 3.12). pip installs globally
# (this image's pip is not PEP-668 externally-managed — no venv, no separate tool).
FROM python:3.12-slim-trixie

# 1) system tools (Debian trixie apt)
RUN apt-get update && apt-get install -y --no-install-recommends \
        file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd \
        ca-certificates curl git \
    && rm -rf /var/lib/apt/lists/*

# 2) python tools, installed GLOBALLY; the build fails if anything is missing
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN pip install --no-cache-dir -r /tmp/python-tools.txt \
 && python -c 'import angr, z3' \
 && rm -f /tmp/python-tools.txt

# 3) Ghidra (optional — large; uncomment to bake it in)
# RUN apt-get update && apt-get install -y --no-install-recommends openjdk-21-jdk unzip wget \
#     && wget -O /tmp/ghidra.zip <release-url-from-github> \
#     && unzip -q /tmp/ghidra.zip -d /opt && rm /tmp/ghidra.zip
# ENV PATH="/opt/ghidra_VER/support:$PATH"

WORKDIR /work
