# detonate.ps1 — Windows in-guest detonation agent (auto-run at logon; see windows-guest.md).
# Finds the sample on the VIBESAMPLE CD, runs it under Procmon, writes results to the
# VIBEOUT disk, then shuts down. The VM has NO network (vmrun gives -nic none).
$ErrorActionPreference = "SilentlyContinue"
$TimeoutSec = 60
$cd  = (Get-Volume -FileSystemLabel VIBESAMPLE).DriveLetter + ":"
$out = (Get-Volume -FileSystemLabel VIBEOUT).DriveLetter + ":"
$sample  = Join-Path $cd  "sample.exe"
$procmon = "C:\Tools\Procmon.exe"
$pml     = Join-Path $out "procmon.pml"

"== detonate $(Get-Date -Format o) ==" | Out-File -Encoding ascii (Join-Path $out "run.log")
Start-Process $procmon -ArgumentList "/AcceptEula","/Quiet","/Minimized","/BackingFile",$pml -WindowStyle Hidden
Start-Sleep 3
$p = Start-Process -FilePath $sample -PassThru
if (-not $p.WaitForExit($TimeoutSec * 1000)) { try { $p.Kill() } catch {} }
Start-Sleep 2
Start-Process $procmon -ArgumentList "/Terminate" -Wait
Start-Process $procmon -ArgumentList "/OpenLog",$pml,"/SaveAs",(Join-Path $out "procmon.csv") -Wait
Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
  Select-Object FullName,Length,LastWriteTime | Out-File -Encoding ascii (Join-Path $out "temp_listing.txt")
"done" | Out-File -Append -Encoding ascii (Join-Path $out "run.log")
Stop-Computer -Force
