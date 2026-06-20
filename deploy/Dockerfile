# syntax=docker/dockerfile:1
# vibe-reverse — air-gapped RE / malware-analysis image.
# Plan 1: analyst environment (RE tools + Ghidra + venv + opencode + skills + QEMU).
# The detonation guest (vmlinuz + rootfs) is added in Plan 2.
ARG DEBIAN_REL=bookworm

# ----------------------------- builder -----------------------------
FROM debian:${DEBIAN_REL}-slim AS builder
ARG OPENCODE_VERSION
ARG GHIDRA_URL
ARG GHIDRA_SHA256
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates unzip git python3 \
    && rm -rf /var/lib/apt/lists/*

# uv (static binary from the official image)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# python venv (angr, z3): same path as runtime + pinned to system python => portable copy
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN uv venv --python /usr/bin/python3 /opt/vibe-reverse/venv \
 && uv pip install --python /opt/vibe-reverse/venv/bin/python -r /tmp/python-tools.txt

# Ghidra (URL + sha pinned via build args; see build.sh)
RUN curl -fsSL "$GHIDRA_URL" -o /tmp/ghidra.zip \
 && echo "${GHIDRA_SHA256}  /tmp/ghidra.zip" | sha256sum -c - \
 && unzip -q /tmp/ghidra.zip -d /opt \
 && mv /opt/ghidra_* /opt/ghidra \
 && rm /tmp/ghidra.zip

# opencode (pinned standalone binary) + pre-install the OpenAI-compatible SDK.
ENV HOME=/root \
    PATH="/opt/vibe-reverse/bin:/root/.opencode/bin:${PATH}" \
    OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1
RUN curl -fsSL https://opencode.ai/install | VERSION="${OPENCODE_VERSION}" bash \
 && install -Dm755 /root/.opencode/bin/opencode /opt/vibe-reverse/bin/opencode
# trigger + bake the openai-compatible provider package (no runtime npm needed)
COPY deploy/_probe-opencode.json /tmp/probe.json
RUN OPENCODE_CONFIG=/tmp/probe.json opencode run --model probe/probe "noop" >/dev/null 2>&1 || true ; \
    pkg=$(find /root -type d -path '*@ai-sdk/openai-compatible*' 2>/dev/null | head -1) ; \
    test -n "$pkg" || { echo "AI-SDK not installed by probe — adjust the probe/paths (plan T3 notes)" >&2; exit 1; } ; \
    mkdir -p /opt/vibe-reverse/opencode-data /opt/vibe-reverse/opencode-cache ; \
    cp -a /root/.local/share/opencode/. /opt/vibe-reverse/opencode-data/  2>/dev/null || true ; \
    cp -a /root/.cache/opencode/.       /opt/vibe-reverse/opencode-cache/ 2>/dev/null || true

# ----------------------------- runtime -----------------------------
FROM debian:${DEBIAN_REL}-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
      file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd \
      qemu-system-x86 qemu-utils \
      python3 openjdk-17-jre-headless ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# baked artifacts (venv at the SAME path it was built at)
COPY --from=builder /opt/vibe-reverse/venv            /opt/vibe-reverse/venv
COPY --from=builder /opt/ghidra                       /opt/ghidra
COPY --from=builder /opt/vibe-reverse/bin/opencode    /opt/vibe-reverse/bin/opencode
COPY --from=builder /opt/vibe-reverse/opencode-data   /opt/vibe-reverse/opencode-data
COPY --from=builder /opt/vibe-reverse/opencode-cache  /opt/vibe-reverse/opencode-cache

# the 10 skills + scripts
COPY skills/              /opt/vibe-reverse/skills/
COPY deploy/entrypoint.sh /opt/vibe-reverse/bin/entrypoint.sh
COPY deploy/smoke.sh      /opt/vibe-reverse/bin/smoke.sh
RUN chmod +x /opt/vibe-reverse/bin/*.sh

# internal CA (placeholder-safe: register only if non-empty)
COPY deploy/ca.pem /tmp/ca.pem
RUN if [ -s /tmp/ca.pem ]; then \
      cp /tmp/ca.pem /usr/local/share/ca-certificates/internal-ca.crt && update-ca-certificates ; \
    fi ; rm -f /tmp/ca.pem

ENV RE_HARNESS_VENV=/opt/vibe-reverse/venv \
    PATH="/opt/vibe-reverse/bin:/opt/ghidra/support:${PATH}" \
    OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1 \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    OPENCODE_DATA_BAKED=/opt/vibe-reverse/opencode-data \
    OPENCODE_CACHE_BAKED=/opt/vibe-reverse/opencode-cache

WORKDIR /work
ENTRYPOINT ["/opt/vibe-reverse/bin/entrypoint.sh"]
