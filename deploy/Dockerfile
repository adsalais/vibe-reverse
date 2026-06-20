# syntax=docker/dockerfile:1
# vibe-reverse — air-gapped RE / malware-analysis image.
# Plan 1: analyst environment (RE tools + Ghidra + venv + opencode + skills + QEMU).
# The detonation guest (vmlinuz + rootfs) is added in Plan 2.
# Python 3.12 base (angr requires >=3.12) on Debian bookworm (verified apt set).
# ----------------------------- builder -----------------------------
FROM python:3.12-slim-bookworm AS builder
ARG OPENCODE_VERSION
ARG GHIDRA_URL
ARG GHIDRA_SHA256
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates unzip \
    && rm -rf /var/lib/apt/lists/*

# uv (static binary from the official image)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# python venv (angr, z3): same path as runtime + pinned to system python => portable copy
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN uv venv --python python3 /opt/vibe-reverse/venv \
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
# NOTE: opencode is NOT executed at build time. The @ai-sdk/openai-compatible
# provider package is left for runtime/manual verification (the analyst tests it
# on the isolated host); models.dev/autoupdate fetches are disabled via env.

# radare2 (.deb) + upx (static binary) — not in Debian bookworm; use official releases
ARG RADARE2_DEB_URL
ARG UPX_URL
RUN apt-get update && apt-get install -y --no-install-recommends xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/dl \
 && curl -fsSL "$RADARE2_DEB_URL" -o /opt/dl/radare2.deb \
 && curl -fsSL "$UPX_URL" -o /tmp/upx.tar.xz \
 && tar -C /tmp -xf /tmp/upx.tar.xz \
 && cp /tmp/upx-*-amd64_linux/upx /opt/dl/upx \
 && chmod +x /opt/dl/upx \
 && rm -rf /tmp/upx.tar.xz /tmp/upx-*

# ---- Linux detonation guest (kernel + initrd + rootfs.ext4) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
      mmdebstrap fakechroot fakeroot e2fsprogs linux-image-amd64 \
    && rm -rf /var/lib/apt/lists/*
COPY deploy/guest/linux/detonate /tmp/detonate
COPY deploy/guest/linux/build-rootfs.sh /tmp/build-rootfs.sh
RUN set -eu; \
    KVER=$(basename /lib/modules/*); \
    mkdir -p /opt/vibe-reverse/guest; \
    cp /boot/vmlinuz-"$KVER"    /opt/vibe-reverse/guest/vmlinuz; \
    cp /boot/initrd.img-"$KVER" /opt/vibe-reverse/guest/initrd.img; \
    sh /tmp/build-rootfs.sh "$KVER" /opt/vibe-reverse/guest/rootfs.ext4

# ----------------------------- runtime -----------------------------
FROM python:3.12-slim-bookworm AS runtime
# radare2 (.deb) + upx (static) staged from the builder (not in Debian main)
COPY --from=builder /opt/dl /opt/dl
RUN apt-get update && apt-get install -y --no-install-recommends \
      file binutils binwalk gdb ltrace strace xxd \
      qemu-system-x86 qemu-utils xorriso dosfstools mtools \
      openjdk-17-jre-headless ca-certificates \
      /opt/dl/radare2.deb \
 && install -Dm755 /opt/dl/upx /usr/local/bin/upx \
 && rm -rf /var/lib/apt/lists/* /opt/dl

# baked artifacts (venv at the SAME path it was built at)
COPY --from=builder /opt/vibe-reverse/venv            /opt/vibe-reverse/venv
COPY --from=builder /opt/ghidra                       /opt/ghidra
COPY --from=builder /opt/vibe-reverse/bin/opencode    /opt/vibe-reverse/bin/opencode
COPY --from=builder /opt/vibe-reverse/guest           /opt/vibe-reverse/guest
COPY deploy/vmrun.sh                                  /opt/vibe-reverse/bin/vmrun.sh
RUN chmod +x /opt/vibe-reverse/bin/vmrun.sh

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
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

WORKDIR /work
ENTRYPOINT ["/opt/vibe-reverse/bin/entrypoint.sh"]
