#!/usr/bin/env sh
# entrypoint.sh — starts as root (the launcher does NOT pass --user). Remaps the
# baked 'vibe' user onto the host user (HOST_UID/HOST_GID), seeds opencode auth,
# then drops privileges to vibe via setpriv and launches opencode. Reports in
# /work end up owned by the host user; no world-writable /etc/passwd is needed.
set -eu

U="${HOST_UID:-1000}"
G="${HOST_GID:-1000}"

# remap vibe -> host uid/gid (-o: tolerate collisions with existing system ids)
[ "$(id -g vibe)" = "$G" ] || groupmod -o -g "$G" vibe
[ "$(id -u vibe)" = "$U" ] || usermod  -o -u "$U" vibe

# kvm: let the dropped user reach /dev/kvm (microVM). The host kvm GID is whatever
# owns the device; ensure a group with that GID exists and add vibe to it, so
# setpriv --init-groups picks it up after the drop.
if [ -e /dev/kvm ]; then
  KG=$(stat -c %g /dev/kvm)
  getent group "$KG" >/dev/null 2>&1 || groupadd -g "$KG" hostkvm
  usermod -aG "$KG" vibe
fi

# auth.json is mounted read-only at /cfg/auth.json; opencode needs it in its data
# dir (data resolves under $HOME=/home/vibe — see `opencode debug paths`).
DATA=/home/vibe/.local/share/opencode
mkdir -p "$DATA" /home/vibe/.cache/opencode /home/vibe/.config/opencode
if [ -f /cfg/auth.json ]; then
  cp /cfg/auth.json "$DATA/auth.json"
  chmod 600 "$DATA/auth.json" 2>/dev/null || true
fi

chown -R vibe:vibe /home/vibe

exec setpriv --reuid vibe --regid vibe --init-groups opencode "$@"
