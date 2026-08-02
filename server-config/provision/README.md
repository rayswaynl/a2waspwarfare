# provision/ — new WASP box deployment runbook (1-4 headless clients)

Turn a freshly activated Windows Server box into a WASP soak host running 1, 2, 3 or 4
headless clients. **HC count is a parameter, not a different script set**: every script
below takes `-HcCount 1..4` (default 4) — `Login-Steams.cmd` takes it as its first
argument — so a 1-HC or 2-HC box runs this exact runbook with `-HcCount 1|2`.
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
| 4 | `powershell -ExecutionPolicy Bypass -File .\04-New-SandboxieBoxes.ps1 -HcCount 4` | Creates Sandboxie boxes `HC2`..`HC<N>` (clones `[HC2]` if the synced ini has one; no-op at `-HcCount 1`) |
| 5 | **`Login-Steams.cmd <N>`** | **MANUAL: log the first N HC Steam accounts in, one guided prompt at a time. One-time; sessions persist per sandbox.** |
| 6 | `powershell -ExecutionPolicy Bypass -File .\Start-Wasp-4HC.ps1 -HcCount 4` | Starts server + HC1..HC<N> staggered, then applies the affinity map |
| 7 | `powershell -ExecutionPolicy Bypass -File .\Verify-4HC.ps1 -HcCount 4` | PASS/FAIL: 1+N processes, affinity map, Nx `HCSIDE\|v1\|connect` in the server RPT |

Steps 1-4 are idempotent — re-run freely. Step 3 can resume (scp per-directory).

`Verify-4HC.ps1` reads the dedicated server RPT from
`$env:USERPROFILE\AppData\Local\ArmA 2 OA\arma2oaserver.RPT`, matching the launcher
default. Pass `-ServerRpt <path>` when the server runs under a different account or
the RPT was redirected.

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
command line, not window title. With `-HcCount <N>` only rows up to HC<N> apply and
the map needs `2 + N` physical cores — so 2 HCs fit a 4-core box, 1 HC a 3-core one.

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

- **HCs are GUI game clients — they need an interactive desktop session.** Two failure
  modes to avoid (wiki: HC-Scaling field notes): (a) a bare SSH session — sshd kills
  detached children on disconnect; (b) a non-interactive (Session-0) scheduled task —
  the HC process may start but **never register** (`connected-hc` never fires; task may
  error `0x80070520`). Start `Start-Wasp-4HC.ps1` from the RDP console, or use an
  interactive-only task while the console user is logged on:
  `schtasks /create /tn WASP-Start4HC /sc once /st 23:59 /it /rl highest /f /tr "powershell -ExecutionPolicy Bypass -File C:\WASP\provision\Start-Wasp-4HC.ps1"`
  then `schtasks /run /tn WASP-Start4HC` (keep the RDP session connected until HCs register).
- **Health truth = registration telemetry, not process count.** A live process can be
  unregistered. `Verify-4HC.ps1` checks HCSIDE owner registrations; once towns activate,
  the `[Performance Audit] delegate_townai_headless ... headless:N` RPT rows are the
  authoritative pool count. Registration lags process start by ~1-3 min (Init_HC sleeps
  20 s after mission load) — do not judge earlier.
- **Known log-spam bug to watch at 4 HCs**: ~20k "Message not sent - error 0
  ID=ffffffff" lines per round to stale HC handles are a known server bug on 2 HCs.
  Watch server RPT growth rate during the soak; if it scales with HC count, cap soak
  length or rotate the RPT between runs.
- Steam Guard: have the e-mail/authenticator for each HC account ready at step 5 —
  that is the whole manual step.
- **HC start order**: `hc_launch.cmd` (HC1) opens with `taskkill /f /im ArmA2OA.exe`,
  which kills every HC — HC1 must always start first, at any `-HcCount`.
  `Start-Wasp-4HC.ps1` guarantees the order; keep it if you hand-fire launchers. The
  kill stays in `hc_launch.cmd` deliberately: counts are contiguous (1..N) so HC1 is
  always in the set, and scheduled tasks that fire `hc_launch.cmd` standalone rely on
  it to clear a stuck HC before relaunching.
- The server runs `-malloc=mimalloc`, HCs `-malloc=tbb4malloc_bi`; both DLLs ride along
  in the game `Dll\` folder synced in step 3. If the server RPT logs an allocator
  fallback, the sync missed `Dll\`.
- First boot after step 6: give the server ~60 s before judging; HCs auto-retry their
  `connected-hc` registration (owner-id race is handled server-side).
