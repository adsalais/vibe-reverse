# syntax=docker/dockerfile:1
# vibe-reverse — air-gapped RE / malware-analysis image.
# Base: python:3.12-slim-trixie (Debian 13 + CPython 3.12, validated for angr).
# Java for Ghidra is Debian trixie's apt openjdk-21-jdk (full JDK, has javac for
# Ghidra's .java GhidraScripts). Python tools install globally (this image's pip
# is not PEP-668 externally-managed). A baked 'vibe' user is remapped to the host
# uid at runtime by the entrypoint (setpriv), so reports in /work stay owned by you.
# ----------------------------- builder -----------------------------
FROM python:3.12-slim-trixie AS builder
ARG OPENCODE_VERSION
ARG GHIDRA_URL
ARG GHIDRA_SHA256
ARG RADARE2_DEB_URL
ARG UPX_URL
ARG CAPA_URL
ARG CAPA_SHA256
ARG FLOSS_URL
ARG DIE_DEB_URL
ARG DIE_DEB_SHA256
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Ghidra (URL + sha pinned via build args; see build.sh)
RUN curl -fsSL "$GHIDRA_URL" -o /tmp/ghidra.zip \
 && echo "${GHIDRA_SHA256}  /tmp/ghidra.zip" | sha256sum -c - \
 && unzip -q /tmp/ghidra.zip -d /opt \
 && mv /opt/ghidra_* /opt/ghidra \
 && rm /tmp/ghidra.zip

# radare2 (.deb) + upx (static binary) — newer than Debian's; staged for runtime.
RUN mkdir -p /opt/dl \
 && curl -fsSL "$RADARE2_DEB_URL" -o /opt/dl/radare2.deb \
 && curl -fsSL "$UPX_URL" -o /tmp/upx.tar.xz \
 && tar -C /tmp -xf /tmp/upx.tar.xz \
 && cp /tmp/upx-*-amd64_linux/upx /opt/dl/upx \
 && chmod +x /opt/dl/upx \
 && rm -rf /tmp/upx.tar.xz /tmp/upx-*

# capa + FLOSS: FLARE standalone Linux release binaries (zip -> single binary).
# Staged here, copied to runtime — they are NOT pip-installed (vivisect deps would
# clash with angr's pinned stack). Detect-It-Easy ships as a Debian .deb (diec CLI).
RUN curl -fsSL "$CAPA_URL"  -o /tmp/capa.zip \
 && echo "${CAPA_SHA256}  /tmp/capa.zip"  | sha256sum -c - \
 && unzip -q /tmp/capa.zip -d /tmp/capa && cp /tmp/capa/capa /opt/dl/capa \
 && curl -fsSL "$FLOSS_URL" -o /tmp/floss.zip \
 && unzip -q /tmp/floss.zip -d /tmp/floss && cp /tmp/floss/floss /opt/dl/floss \
 && chmod +x /opt/dl/capa /opt/dl/floss \
 && curl -fsSL "$DIE_DEB_URL" -o /opt/dl/die.deb \
 && echo "${DIE_DEB_SHA256}  /opt/dl/die.deb" | sha256sum -c - \
 && rm -rf /tmp/capa.zip /tmp/capa /tmp/floss.zip /tmp/floss

# opencode (pinned standalone binary) installed into a HOME we copy to the vibe
# user. NOT executed at build time (it opens a TUI and hangs).
ENV OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1
RUN mkdir -p /opt/opencode-home \
 && HOME=/opt/opencode-home sh -c 'curl -fsSL https://opencode.ai/install | VERSION="'"${OPENCODE_VERSION}"'" bash' \
 && test -x /opt/opencode-home/.opencode/bin/opencode

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
FROM python:3.12-slim-trixie AS runtime
# RE tools + Java (openjdk-21-jdk = full JDK with javac, for Ghidra's .java
# GhidraScripts) + the entrypoint's identity tools (passwd: usermod/groupmod/
# groupadd; util-linux: setpriv). radare2/upx are staged from the builder.
# build-essential: miasm has a C extension with no wheel (compiled at pip-install)
# AND its default jitter compiles C at runtime — so the compiler stays in the image.
COPY --from=builder /opt/dl /opt/dl
RUN apt-get update && apt-get install -y --no-install-recommends \
      file binutils binwalk gdb ltrace strace xxd yara \
      build-essential \
      zip unzip p7zip-full unar cabextract xz-utils zstd lz4 lzip libarchive-tools cpio \
      ssdeep openssl jq ripgrep poppler-utils libimage-exiftool-perl less tree \
      qemu-system-x86 qemu-utils xorriso dosfstools mtools \
      ca-certificates openjdk-21-jdk passwd util-linux \
      /opt/dl/radare2.deb /opt/dl/die.deb \
 && install -Dm755 /opt/dl/upx   /usr/local/bin/upx \
 && install -Dm755 /opt/dl/capa  /usr/local/bin/capa \
 && install -Dm755 /opt/dl/floss /usr/local/bin/floss \
 && test -x /usr/lib/jvm/java-21-openjdk-amd64/bin/java \
 && rm -rf /var/lib/apt/lists/* /opt/dl

# python tools, installed GLOBALLY (no venv, no extra resolver). Verified at build.
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN pip install --no-cache-dir -r /tmp/python-tools.txt \
 && python -c 'import angr, z3, capstone, unicorn, keystone, lief, pefile, elftools, miasm, qiling, yara, r2pipe' \
 && python -c 'import pwn, oletools' \
 && python -c 'import triton' \
 && rm -f /tmp/python-tools.txt

# the vibe user: a real identity (HOME + passwd entry). The entrypoint remaps its
# uid/gid to the host user's at runtime, then drops to it via setpriv.
RUN useradd --create-home --uid 1000 --user-group --shell /bin/sh vibe

# opencode "for the vibe user": staged from the builder into vibe's HOME.
COPY --from=builder --chown=vibe:vibe /opt/opencode-home/.opencode /home/vibe/.opencode

# baked artifacts
COPY --from=builder /opt/ghidra             /opt/ghidra
COPY --from=builder /opt/vibe-reverse/guest /opt/vibe-reverse/guest
COPY deploy/vmrun.sh                        /opt/vibe-reverse/bin/vmrun.sh

# the 10 skills + scripts
COPY skills/                /opt/vibe-reverse/skills/
COPY deploy/entrypoint.sh   /opt/vibe-reverse/bin/entrypoint.sh
COPY deploy/smoke.sh        /opt/vibe-reverse/bin/smoke.sh
RUN chmod +x /opt/vibe-reverse/bin/*.sh

# internal CA (placeholder-safe: register only if non-empty)
COPY deploy/ca.pem /tmp/ca.pem
RUN if [ -s /tmp/ca.pem ]; then \
      cp /tmp/ca.pem /usr/local/share/ca-certificates/internal-ca.crt && update-ca-certificates ; \
    fi ; rm -f /tmp/ca.pem

ENV HOME=/home/vibe \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH="/opt/vibe-reverse/bin:/home/vibe/.opencode/bin:/opt/ghidra/support:/usr/lib/jvm/java-21-openjdk-amd64/bin:${PATH}" \
    OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1 \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

WORKDIR /work
ENTRYPOINT ["/opt/vibe-reverse/bin/entrypoint.sh"]
