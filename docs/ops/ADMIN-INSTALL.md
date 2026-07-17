# ADMIN-INSTALL — WASP main server (one-page cold start)

**Audience:** owner/admin installing or updating the Miksuu MAIN game server.  
**Tool:** `Tools/WaspServerInstaller/` (config file + apply).  
**Hard rules:** never point this at the live main host without explicit owner authority; agents do not deploy live. **Difficulty is always Veteran** (immutable).

## What this is (and is not)

| This installer | Sister tools (do not fork another) |
| --- | --- |
| Renders `server.cfg`, **versioned** `basic.cfg`, HC/server launch scripts, firewall helper, ASR skeleton, **flag-plan**, affinity math | **Deploy-Wasp.ps1** — pack/place mission PBO + verify/rollback |
| Config: `wasp-server.json` (+ interactive NewConfig) | **HetznerInstaller (PR #1102)** — fenced transactional install controller |
| DryRun diff + Validate + Apply into a **scratch/fence** root | **server-config/** + PR #1081 — proven live-ish snapshots |

## 5-minute path

```powershell
cd <repo>
# 1) Create config (edit paths/hostname/HC count/telemetry)
pwsh -File Tools\WaspServerInstaller\Invoke-WaspServerInstaller.ps1 -Action NewConfig -ConfigPath .\wasp-server.json
# optional wizard:
# ... -Action NewConfig -ConfigPath .\wasp-server.json -Interactive

# 2) Edit wasp-server.json — set paths.installRoot to a SCRATCH dir (not C:\WASP)

# 3) Validate + dry-run
pwsh -File Tools\WaspServerInstaller\Invoke-WaspServerInstaller.ps1 -Action Validate -ConfigPath .\wasp-server.json
pwsh -File Tools\WaspServerInstaller\Invoke-WaspServerInstaller.ps1 -Action DryRun  -ConfigPath .\wasp-server.json -InstallRoot D:\scratch\wasp-main

# 4) Apply (pass secrets on CLI only; they are not stored in the JSON saver)
pwsh -File Tools\WaspServerInstaller\Invoke-WaspServerInstaller.ps1 -Action Apply -ConfigPath .\wasp-server.json -InstallRoot D:\scratch\wasp-main -PasswordAdmin '***' -Password ''

# 5) Mission PBO (separate, owner-run when ready)
# Tools\Ops\Deploy-Wasp.ps1 -Build <tag> -ActiveMap ch   # dry-run first; -Apply only with authority
```

## Knobs you set in `wasp-server.json`

| Section | What |
| --- | --- |
| `server.*` | Name, ports, maxPlayers, MOTD/rules, BattlEye (default **0** — BE master-down finding), verifySignatures |
| `server.difficulty` | **Forced Veteran** — other values fail Validate |
| `headlessClients.count` | 0–8; writes `headlessClients[]`/`localClient[]` + `hc_launch.cmd` / `hc2_launch.cmd`… |
| `telemetry.mode` | `on` / `off` / `stats-only` → flag-plan mapping (see below) |
| `featureFlags` | Curated WFBE flags (see `-Action Catalog`) |
| `perf.*` | malloc (default **mimalloc** server / **tbb4malloc_bi** HC), cpuCount/exThreads, priority, basic.cfg, ASR knobs, affinity layout |

### Parameters.hpp trap (read this)

Lobby params in `Rsc/Parameters.hpp` use `default=` values that **win** over `Init_CommonConstants.sqf` `isNil` fallbacks.  
The installer **records** desired flags in `flag-plan/flag-plan.json` and explains the layer (`lobby` vs `script`). It does **not** silently rewrite mission SQF. To realize lobby defaults you must **repack** (Deploy-Wasp) or set them in the MP lobby.

### Telemetry modes

| Mode | Effect (installer-mapped) |
| --- | --- |
| `on` | STATLOG + MATCH telemetry + stats pipeline + PLAYERSTAT on (TELEM_HOST_V2 on) |
| `off` | All mapped telemetry flags off |
| `stats-only` | Gameplay/WASPSCALE-family off; **STATS_ENABLED + PLAYERSTAT** stay on for leaderboard feed |

### Perf defaults (evidence one-liners)

| Knob | Default | Why / source |
| --- | --- | --- |
| `MaxSizeGuaranteed` | 512 | JIP black-screen fix; 1024 fragments (server-config/README, PR #1081 family) |
| `MaxMsgSend` / nonguaranteed | 512 | Co-tuned with live basic.cfg |
| server `-malloc` | mimalloc | Live allocator split; custom allocator works on A2OA 1.64 |
| HC `-malloc` | tbb4malloc_bi | Live HC lines |
| `-cpuCount` / `-exThreads` | 2 / 3 | Live HC lines; main loop ~single-thread bound — cpuCount is engine-belief override (hosting corpus). **exThreads=7 unmeasured → conservative 3** |
| Affinity | disjoint masks | Server cores ≠ HC cores; HT even-first heuristic; `Set-WaspCpuAffinity.ps1` pattern |
| Priority | High server / AboveNormal HC | OS-side contention preference (hosting corpus) |
| HC count default | 2 | Live topology + Hetzner profile `hc-2` intent |

## Self-test

```powershell
pwsh -File Tools\WaspServerInstaller\WaspServerInstaller.Tests.ps1
```

## After apply

1. Read `flag-plan/README.md` in the install root.  
2. Open UDP game port (or run generated `firewall-open-ports.ps1` elevated on the box).  
3. Deploy mission PBO with **Deploy-Wasp** when you intend a real update.  
4. For a new fenced host tree, hand artifacts to **HetznerInstaller** (still NO-GO for production without owner runtime gate).

GUIDE-REV: tooling docs aligned with GR-2026-07-08a practices (draft PR only; no live deploy).
