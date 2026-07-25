# provision/ — new 4-HC box deployment runbook

Turn a freshly activated Windows Server box into the WASP 4-HC soak host.
**The only manual step is `Login-Steams.cmd` (step 5).** Everything else is scripted.

No hostnames, IPs, usernames, or credentials live in this folder — pass them as
parameters at run time. Never commit them here (public repo).

## Order of operations (run in an elevated PowerShell, RDP console session)

| Step | Command | What it does |
| --- | --- | --- |
| 0 | **`.\00-Bootstrap-SSH.ps1 -PubKey 'ssh-ed25519 AAAA...'`** | **MANUAL, once, pasted into the activation RDP session: installs sshd + authorizes the operator key. Everything after this runs remotely.** |
| 1 | `powershell -ExecutionPolicy Bypass -File .\01-Base-OS.ps1` | High Performance power plan, firewall openings (UDP 2302-2306), reports VBS/HVCI + SMT state |
| 2 | `powershell -ExecutionPolicy Bypass -File .\02-Install-Apps.ps1` | Installs Steam + Sandboxie-Plus via winget (fallback URLs printed if winget is missing) |
| 3 | `powershell -ExecutionPolicy Bypass -File .\03-Sync-GameFiles.ps1 -SourceHost <old-box> -SourceUser <user>` | Pulls the game install (incl. `Dll\` allocators + mods) and `C:\WASP\` from the old box over scp |
| 4 | `powershell -ExecutionPolicy Bypass -File .\04-New-SandboxieBoxes.ps1` | Creates Sandboxie boxes `HC2`/`HC3`/`HC4` (clones `[HC2]` if the synced ini has one) |
| 5 | **`Login-Steams.cmd`** | **MANUAL: log the 4 HC Steam accounts in, one guided prompt at a time. One-time; sessions persist per sandbox.** |
| 6 | `powershell -ExecutionPolicy Bypass -File .\Start-Wasp-4HC.ps1` | Starts server + HC1-HC4 staggered, then applies the affinity map |
| 7 | `powershell -ExecutionPolicy Bypass -File .\Verify-4HC.ps1` | PASS/FAIL: 5 processes, affinity map, 4x `HCSIDE\|v1\|connect` in the server RPT |

Steps 1-4 are idempotent — re-run freely. Step 3 can resume (scp per-directory).

## Affinity map (Ryzen 7 7700: 8 physical cores, 16 logical with SMT)

Applied by `Set-WaspAffinity.ps1` (called from `Start-Wasp-4HC.ps1`; safe to re-run any time):

| Process | Physical cores | Logical CPUs (SMT on) | Priority |
| --- | --- | --- | --- |
| `arma2oaserver.exe` | 0-1 | 0-3 | High |
| HC1 (`-name=HC-AI-Control-1`) | 2 | 4-5 | Above Normal |
| HC2 | 3 | 6-7 | Above Normal |
| HC3 | 4 | 8-9 | Above Normal |
| HC4 | 5 | 10-11 | Above Normal |
| OS / Steam / Sandboxie | 6-7 | 12-15 | (untouched) |

If SMT is off (8 logical CPUs) the script detects it and pins 1 logical CPU per HC,
2 for the server. HC processes are told apart by their `-name=HC-AI-Control-N`
command line, not window title.

Launch parameters (`-exThreads=3 -cpuCount=2` on HCs) are deliberately unchanged from
the 2-HC baseline so soak numbers stay comparable; affinity is layered on top.

## Mission + config placement (from the repo, not the old box)

- `server-pr8.cfg`, `basic.cfg`, `hc_launch.cmd` … `hc4_launch.cmd` come from
  `server-config/` (this repo, PR #1456 branch) → `C:\WASP\` per the paths in
  `../README.md`. Step 3 copies the old box's `C:\WASP\` first; then overwrite with the
  repo versions of these files so the 4-HC config wins. Restore `passwordAdmin` on the
  box copy by hand (never commit it).
- The mission PBOs for the 4-HC test are packed on the dev PC by `Tools/Pack/pack_pbo.py`
  from the PR #1456 branch and copied to `C:\WASP\MPMissions\` (scp). Set the
  `template =` line in `server-pr8.cfg` to the packed name (folder-name prefix with
  `_<BUILDTAG>` before the terrain suffix). Note: pre-release packs fall back to
  `version.sqf.template` (WF_DEBUG off, logging on) — fine for the soak box, not for a
  public wave ship.

## Gotchas

- **Do not start these scripts over a bare SSH session** — Windows sshd kills detached
  children when the session closes. Use the RDP console, or register a one-shot
  scheduled task: `schtasks /create /tn WASP-Start4HC /sc once /st 23:59 /tr "powershell -ExecutionPolicy Bypass -File C:\WASP\provision\Start-Wasp-4HC.ps1" /rl highest /f` then `schtasks /run /tn WASP-Start4HC`.
- Steam Guard: have the e-mail/authenticator for each HC account ready at step 5 —
  that is the whole manual step.
- The server runs `-malloc=mimalloc`, HCs `-malloc=tbb4malloc_bi`; both DLLs ride along
  in the game `Dll\` folder synced in step 3. If the server RPT logs an allocator
  fallback, the sync missed `Dll\`.
- First boot after step 6: give the server ~60 s before judging; HCs auto-retry their
  `connected-hc` registration (owner-id race is handled server-side).
