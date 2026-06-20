# vibe-reverse — air-gapped deployment

Build on an internet-connected host, ship one bundle to the air-gapped network,
run per case folder.

## Build (internet host)
```sh
# put your internal CA at deploy/ca.pem (optional), then:
sh deploy/build.sh                         # -> vibe-reverse:latest (Ghidra/JDK shas pinned inside)
sh deploy/export.sh                        # -> dist/vibe-reverse-bundle.tgz
```

## Install (air-gapped host)
```sh
tar xzf vibe-reverse-bundle.tgz && cd vibe-reverse-bundle && sh install.sh
# then edit ~/.config/vibe-reverse/opencode.json (LLM baseURL + model id)
#      and ~/.config/vibe-reverse/auth.json       (your bearer token)
#  opt. edit ~/.config/vibe-reverse/tui.json      (opencode TUI keybinds)
```

## Use
```sh
cd /cases/incident-42 && vibe-reverse      # opencode TUI; reports land here, owned by you
```

- The container reaches your internal LLM only; **malware detonates only in the
  no-network microVM** (`re-dynamic` → `vmrun.sh`).
- Windows dynamic analysis: see `windows-guest.md` (supply your own licensed image).
- Design: `docs/superpowers/specs/2026-06-20-airgap-deployment-design.md`.
