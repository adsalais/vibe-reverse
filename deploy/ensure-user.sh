#!/usr/bin/env sh
# ensure-user.sh — give the (possibly mapped, arbitrary) container uid a usable
# identity. SOURCE this, don't exec it: it sets HOME and appends a /etc/passwd
# entry for the running uid.
#
# Why: `docker run --user <uid>` with an arbitrary host uid has no /etc/passwd
# entry, which breaks tools that resolve the user from the passwd database:
#   - Java / Ghidra: user.home resolves to "?" -> "user home directory does not
#     exist" (note: the JVM uses getpwuid, NOT $HOME, so $HOME alone won't help).
#   - Python getpass.getuser() (pyvex -> angr): KeyError getpwuid.
# The Dockerfile makes /etc/passwd world-writable so this append can succeed.
# Malware never runs in the container (only in the no-network microVM), so a
# writable passwd here is not a meaningful exposure.
: "${HOME:=/state}"; [ -d "$HOME" ] || HOME=/tmp; export HOME
if ! getent passwd "$(id -u)" >/dev/null 2>&1; then
  echo "vibe:x:$(id -u):$(id -g):vibe:${HOME}:/bin/sh" >> /etc/passwd 2>/dev/null || true
fi
