# Preparing the Windows detonation guest

`vmrun.sh --guest windows` boots a licensed Windows `qcow2` that you prepare once on
an internet/build host, then place at `~/.config/vibe-reverse/guests/windows.qcow2`.
The VM runs with **no network** (`-nic none`) and `-snapshot` (throwaway).

## 1. Create the disk + install Windows (one-time, build host)
```sh
qemu-img create -f qcow2 windows.qcow2 40G
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -drive file=windows.qcow2,format=qcow2 -cdrom Windows.iso -boot d
# (optionally also attach virtio-win.iso and install virtio drivers for speed;
#  plain IDE works without them, which is what vmrun.sh uses)
```
Install Windows normally, then boot it.

## 2. Install the detonation agent (inside the guest)
- Install Sysinternals **Procmon** to `C:\Tools\Procmon.exe` (run it once, accept the EULA).
- Copy `deploy/guest/windows/detonate.ps1` and `detonate.cmd` into `C:\Tools\`.

## 3. Auto-logon + auto-run the agent
- Enable auto-logon: `netplwiz` (uncheck "Users must enter a user name and password"),
  or set `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`:
  `AutoAdminLogon=1`, `DefaultUserName`, `DefaultPassword`.
- Run the agent at logon: Task Scheduler → Create Task → Trigger "At log on" →
  Action `C:\Tools\detonate.cmd` (highest privileges), **or** put a shortcut to
  `detonate.cmd` in `shell:startup`.

## 4. Reduce noise (optional — the VM has no network anyway)
- Disable Windows Update, telemetry, and Defender cloud-delivered protection.
- Disable the lock screen; aim for a fast boot.

## 5. Seal + place
- Shut the guest down cleanly.
- Copy `windows.qcow2` to `~/.config/vibe-reverse/guests/windows.qcow2`
  (it reaches the container via the launcher's `-v $CFG/guests:/guests:ro`).

## 6. Verify once (benign EXE)
```sh
vmrun.sh /path/benign.exe /tmp/case --guest windows --timeout 60
ls /tmp/case/artifacts/dynamic/    # expect: procmon.csv, temp_listing.txt, run.log
```

## How it works
- The sample is handed in on a **read-only ISO** labelled `VIBESAMPLE` (as `sample.exe`).
- `detonate.ps1` runs it under Procmon, exports `procmon.csv` + a dropped-file listing
  to the **FAT disk** labelled `VIBEOUT`, then shuts down.
- `vmrun.sh` reads `VIBEOUT` back with `mtools` (no mount) into `artifacts/dynamic/`.
- No network, throwaway snapshot — same isolation guarantees as the Linux guest.
