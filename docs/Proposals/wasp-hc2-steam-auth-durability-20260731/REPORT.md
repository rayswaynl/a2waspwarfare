# HC2 Steam auth durability — findings + recommended path

**Task:** `wasp-hc2-steam-auth-durability-20260731`  
**Agent:** `grok-main-07311829-night` (research / design only)  
**Date:** 2026-07-31  
**Scope:** written findings + recommended path. **No live-box mutations. No credentials handled. No SQF edits.**  
**Confidence:** high on topology + proven-dead paths; medium on “can HC run with zero Steam” (static analysis only; live A/B not run this session).

---

## 1. Executive recommendation

| Priority | Path | Verdict | Why |
|---|---|---|---|
| **P0 ship-now** | **(3) Loud, self-limiting failure + owner alert** | **RECOMMENDED first** | Fully implementable without credentials; stops player-visible flash/retry storm; alerts with one-line owner remedy |
| **P1 experiment** | **(1) HC without Steam auth** | **LIKELY NOT VIABLE for Steam install of ArmA2OA.exe; owner-gated probe still worth one restore-clean window** | HC is full game client (`ArmA2OA.exe -client`), not dedi binary; Steam install hard-depends on SteamAPI for client launch; server’s “Unable to initialize Steam API” tolerance does **not** transfer to HCs |
| **P2** | **(2) Offline mode / VDF / registry persistence** | **PROVEN NOT A FIX** for invalidated refresh tokens (2026-07-31 15:40 live trial) | AutoLogin/RememberPassword already present; registry + relaunch did not clear “Sign in to Steam” |

**Architectural north star (if (1) fails the probe):** keep multi-Steam + Sandboxie for multi-HC licenses, but **decouple recovery from interactive sign-in frequency** by:

1. never force-killing healthy sandboxed Steam as a routine cure,
2. only relaunching Steam via InteractiveToken scheduled tasks (session 2 desktop),
3. detecting auth death early and **stopping HC relaunch**, not thrashing,
4. leaving plaintext auto-login tooling as **owner-only** (move to a secret store when the owner next touches box secrets).

Live mutations remain **owner-gated**. This document is design input, not a merge or deploy authority.

---

## 2. Problem (recurring live outage)

**Symptom (players):** flashing join/leave lobby entry for `HC-AI-Control-2` (can appear on a BLUFOR row; looks like a slot bug but is auth-driven churn).

**Symptom (engine / server RPT):** connect-retry loop — rotating channel ids, `Message not sent … ("HC-AI-Control-2")`, `NetServer::SendMsg: cannot find channel`, `No player found for channel`.

**Symptom (HC2 client RPT):** `Unable to initialize Steam API` on each launch attempt.

**True RPT path (sandbox):**  
`C:\Sandbox\Administrator\HC2\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT`  

**Stale path (do not use for HC2 truth):**  
`C:\WASP\hc2-profile\ArmA2OA.RPT` (launcher passes no `-profiles`).

**Trigger chain (3rd occurrence class, 2026-07-31):**

1. Force-kill of real + sandboxed Steam (boot-wedge “cure” path) **or** Steam restart (~04:53 PST same day).
2. Sandboxed Steam comes back without a valid session → **“Sign in to Steam”** dialog in RDP session 2.
3. HC2 `ArmA2OA.exe` cannot init Steam API → exits / is relaunched forever by recovery/guard paths.
4. Recovery is **blocked on owner interactive sign-in** in session 2.

**Proven not the fix (2026-07-31 15:40 — do not re-burn a round):**

- Sandbox `loginusers.vdf` already had `AutoLogin=1` + `RememberPassword=1`.
- Setting `AutoLoginUser` / `RememberPassword` under the sandbox Valve registry hive + full sandboxed Steam kill/relaunch did **not** clear the dialog.
- Conclusion recorded in memory `wasp-hc2-sandbox-steam-relaunch-trap`: blocker is an **invalidated/expired Steam refresh token**; no flag/registry/file manipulation substitutes for interactive sign-in.

**Credentials constraint (hard):** agents never read, use, copy, or type passwords. Box may carry an owner-only plaintext auto-login helper under `C:\WASP\provision\` — treat as **owner tool only**; if a design would replace it, owner actions it. Prefer a proper secret store when the owner next revisits box secrets.

---

## 3. Current topology (repo + ops docs)

Sources: `server-config/hc_launch.cmd`, `hc2_launch.cmd`–`hc4_launch.cmd`, `server_launch.cmd`, `provision/Login-Steams.cmd`, `provision/README.md`, `provision/Start-Wasp-4HC.ps1`, `docs/ops/SERVER-STARTUP-ROTATION.md`, `docs/ops/deploy-v2.ps1`.

| Process | Binary | Steam model | Why |
|---|---|---|---|
| Dedicated server | `arma2oaserver.exe` | SteamAppId set; **tolerates** Steam API init failure | Separate dedi binary; does not need a player session |
| HC1 | `ArmA2OA.exe -client … -name=HC-AI-Control-1` | **Real** (unsandboxed) Steam session on host desktop | Full game client; one Steam account |
| HC2–HC4 | Same client binary, launched via Sandboxie `Start.exe /box:HCn` after sandboxed `steam.exe -silent` | **One sandboxed Steam account per HC** | Bypass Steam single-instance mutex so multiple licensed clients coexist |

### 3.1 HC1 vs HC2 auth fragility

| | HC1 | HC2+ |
|---|---|---|
| Steam process | Host Steam | Sandboxie-isolated Steam |
| Launch | `hc_launch.cmd` (and recovery path that must **not** global-`taskkill` all `ArmA2OA.exe`) | `hc2_launch.cmd`: start sandboxed Steam → **unconditional 30 s sleep** → launch game in box |
| Session “persist” claim | Provision docs: one-time login | **False under refresh-token death** — same class as HC1 if host Steam dies, but HC2 is the multi-account fragile path |
| Auth death signature | Host Steam dialog / API fail | Window title “Sign in to Steam” via `WaspHC2Win`; RPT `Unable to initialize Steam API` |
| Cross-session trap | GUI needs interactive desktop | SSH/session-0 Steam = frozen stub; **only InteractiveToken** tasks into RDP session 2 are valid |

**HC1 shares the same SteamAPI class of risk** when host Steam is force-killed or loses sign-in. HC2 is worse in practice because:

1. multi-account sandbox recovery is more complex,
2. false health signals (`WaspSteamHC2Silent` result 0, process up, still unsigned-in),
3. recovery/guard paths can **retry forever**, producing the player-visible flash.

### 3.2 Why Sandboxie exists (do not remove casually)

Steam enforces a single interactive instance. Multiple HCs on one box need either:

- N sandboxed Steam sessions (current design), or  
- N physical/VM hosts (each one Steam), or  
- a hypothetical non-Steam multi-client path (section 4).

Removing Sandboxie without another multi-session strategy collapses multi-HC.

---

## 4. Option analysis

### (1) Run HC without Steam auth entirely

**Hypothesis:** A2 OA 1.64 dedicated/headless historically could run from non-Steam binaries; server already logs Steam API init failure and works; maybe HC only needs game files + mods.

**Static evidence against a free lunch:**

1. **HC is not the dedi binary.** Repo launchers always use `ArmA2OA.exe -client -connect=127.0.0.1`. Server uses `arma2oaserver.exe`. Different product surface.
2. **Steam install path is universal on this box.** Workdir and mod roots are under the Steam library; `SteamAppId=33930` is set on server and all HCs.
3. **Community pattern (Arma family):** headless clients are full game clients and historically require a licensed client install per HC. A3 community docs explicitly require Steam + a second license for a second HC; A2 OA’s multi-HC layout here mirrors that model via Sandboxie.
4. **Observed failure mode matches SteamAPI hard-fail on client:** when sandbox Steam is unsigned-in, HC2 emits `Unable to initialize Steam API` and never seats — exactly the client Steamworks path, not a soft “online services optional” path.
5. **Non-Steam retail / CD-key multiplayer** historically depended on infrastructure that is EOL for A2; even with `verifySignatures=0` / `BattlEye=0` on this test box, a non-Steam client is **unproven** and likely still binds `steam_api` for the Steam build of the exe.

**What would prove (1) viable (owner-gated restore-clean window only):**

| Probe | Pass criterion | Expected (prior) |
|---|---|---|
| A. Launch `ArmA2OA.exe -client … -name=HC-AI-Control-2` **without** sandboxed Steam running | Process stays up, seats, emits `HCSTAT`/`HCSIDE` for HC-AI-Control-2 | **Fail** — Steam API init error |
| B. Same with Steam running but **intentionally offline** after a **known-good** signed-in session (no force-kill first) | Seats after Steam restart into offline | May pass while token cache valid; **fails** after invalidation (today’s class) |
| C. Separate non-Steam file tree (only if owner has a legal non-Steam install) | Seats on local server | Unknown; treat as research, not default |

**If A fails (expected):** close (1) as not viable for this install; invest in (3) + operational Steam-lifetime hygiene.  
**If A passes:** redesign `hc2_launch.cmd` to drop sandboxed Steam entirely (highest-value outcome). Document and owner-gate.

**Do not** pursue cracked `steam_api` stubs or credential automation by agents.

### (2) Steam offline mode / persistent credential store

| Approach | Status |
|---|---|
| `loginusers.vdf` AutoLogin / RememberPassword | **Already present during failure** — not sufficient |
| Registry AutoLoginUser / RememberPassword in sandbox hive | **Tried 2026-07-31 15:40 — failed** |
| Steam offline mode | Helps network blips **after** a good session; does **not** restore an invalidated refresh token after force-kill / online reauth demand |
| Agent-driven password entry | **Out of scope** (credentials ban) |
| Owner plaintext auto-login helper on box | Exists as owner tool; **security side-note:** move to a proper secret store when owner revisits secrets; agents must not read/use it |

**Verdict:** treat (2) as **closed for the invalid-token class**. Do not schedule more VDF/registry experiments for this failure mode.

### (3) Loud, self-limiting failure (recommended ship-now)

**Goal:** when Steam auth is dead, **stop the silent forever-retry** that makes players see flashing join/leave, and **alert the owner** with the exact remedy.

#### 3.1 Detection (authoritative signals)

Prefer **conjunction** of:

1. **HC2 client RPT** (sandbox path above) contains recent `Unable to initialize Steam API` after last process start.
2. **Window-title peek** via existing `WaspHC2Win` → title contains `Sign in to Steam` (session-2 truth).
3. **Server RPT current-session window:** channel spam for `"HC-AI-Control-2"` without a fresh `HCSTAT|…who="HC-AI-Control-2"` after relaunch.

Process presence alone is **not** health (`steam.exe` up ≠ signed in).  
`Start.exe /box:HC2 /listpids` from SSH is **not** health (cross-session lies).

#### 3.2 Self-limit policy

| Knob | Suggested default | Behavior |
|---|---|---|
| `HC2_AUTH_FAIL_MAX` | 3 consecutive auth-fail launches | After N, **stop** relaunching HC2 game process |
| Cooldown | 15–30 min | Optional single re-probe; do not storm |
| Guard interaction | Critical | **Do not** let `WaspServerGuard` escalate missing HC2 → **full stack bounce** while players online (07-30 precedent). Auth-dead state must be a **recognized degraded mode**: 1-HC acceptable, no full bounce |
| While players online and auth dead | Leave a **single** flapping proc **or** leave HC2 down with guard inhibited for HC2-only | Prefer **inhibited relaunch** + alert over infinite flash |

#### 3.3 Owner alert content (one line remedy)

Exact owner action once auth is dead (from live runbook / memory):

1. In **RDP session 2** (Administrator interactive desktop): sign in sandboxed Steam for box HC2.  
2. Kill HC2 **game** process only (not the whole stack).  
3. `schtasks /Run /TN WaspHC2` (or current HC2 seat task).  
4. Verify fresh `who="HC-AI-Control-2"` HCSTAT in the **current-session** server RPT window.

Steam relaunch (if needed) must use **`WaspSteamHC2Silent`** (InteractiveToken → session 2), never bare SSH `Start-Process`.

#### 3.4 Draft watchdog sketch (box script — owner-gated; not applied this session)

Place under box `C:\WASP\provision\` when owner accepts (mirror into `server-config/provision/` after redaction review):

```powershell
# DRAFT ONLY — not deployed by this task.
# Watch-Hc2SteamAuth.ps1 (sketch)
# - Read-only RPT tail + optional window-title file
# - After N auth fails: write inhibit flag; alert; do not relaunch
# - Never touches credentials

param(
  [string]$Hc2Rpt = 'C:\Sandbox\Administrator\HC2\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT',
  [string]$InhibitFlag = 'C:\WASP\state\hc2-auth-inhibit.flag',
  [int]$MaxFails = 3
)

$authFail = $false
if (Test-Path -LiteralPath $Hc2Rpt) {
  # Tail last ~200 KB; match Steam API init failure after recent activity.
  $fs = [IO.File]::Open($Hc2Rpt, 'Open', 'Read', 'ReadWrite')
  try {
    $len = $fs.Length
    $start = [Math]::Max(0, $len - 200KB)
    $null = $fs.Seek($start, 'Begin')
    $sr = New-Object IO.StreamReader($fs)
    $tail = $sr.ReadToEnd()
    $sr.Close()
  } finally { $fs.Dispose() }
  if ($tail -match 'Unable to initialize Steam API') { $authFail = $true }
}

if (-not $authFail) {
  if (Test-Path $InhibitFlag) { Remove-Item $InhibitFlag -Force }
  exit 0
}

# Increment fail counter in a small state file; on threshold:
# 1) write inhibit flag consumed by restart/guard paths
# 2) Peach/owner alert with one-line remedy (no secrets)
# 3) optional: stop MiksuuHC2 / kill only HC-AI-Control-2 ArmA2OA if policy allows mid-match silence without full bounce
```

**Integration points (owner must wire carefully):**

- `Restart-Wasp-2HC.ps1` / guard: honor inhibit flag; **never** full-stack bounce solely for HC2 auth death.
- `hc2_launch.cmd`: optional preflight — if inhibit flag set, exit 0 without launching (loud log line).
- Replace RACE-4 blind `timeout /t 30` with “Steam process up **and** not showing Sign-in title” when owner next edits launchers (secondary improvement; does not fix token death).

#### 3.5 Mission/PR angle

No mission SQF change is **required** for (3). This is box ops. Optional later: server-side telemetry when an HC name flaps without seating (nice-to-have; not the durability fix).

---

## 5. Operational hygiene (reduces how often (3) fires)

These are **policy**, not substitutes for token validity:

1. **Stop treating Steam force-kill as a routine boot cure.** Memory `wasp-boot-wedge-steam-and-scp-masking` shows force-kill of Steam was a direct precursor to HC2 auth death. Prefer diagnosing true wedges (missing mission PBO, cfg lock, etc.) without nuking Steam sessions.
2. **Only InteractiveToken** for sandboxed Steam (`WaspSteamHC2Silent`). Session-0 SSH launches freeze pre-login.
3. **Health truth:** `tasklist /m SbieDll.dll` + window titles + HC2 sandbox RPT + server HCSTAT — not `listpids` from SSH, not “scheduled task result 0”.
4. **While players online:** do not kill flapping HC2 solely to silence flash if that escalates to full bounce; prefer inhibit + alert (section 3.2).
5. **HC1:** same SteamAPI class — after host Steam restart, verify host Steam signed-in before declaring HC1 recovery success.

---

## 6. Recommended phased plan (owner-facing)

### Phase A — now (owner-gated box, no mission PR required)

1. Implement **auth-fail detector + inhibit flag + owner alert** (section 3).  
2. Patch guard/restart so HC2 auth-dead ⇒ **degraded 1-HC**, never full bounce.  
3. Document the one-line remedy on the box runbook / DAY board.  
4. Security side-quest for owner: retire plaintext auto-login helper into a secret store (agents still never touch it).

### Phase B — one restore-clean window

1. Run probe **A** from section 4 (HC without Steam).  
2. Record RPT + seat outcome.  
3. If fail: mark (1) closed for Steam install; keep Sandboxie multi-Steam.  
4. If pass: redesign HC2+ launchers to drop sandboxed Steam (large win).

### Phase C — only if Phase B fails and outages remain frequent

1. Consider **second host / VM per extra HC** (one Steam each, no sandbox token coupling) — cost/ops tradeoff.  
2. Or accept 1-HC degraded mode as automatic fallback with clear player-facing status (optional Discord/Peach notice).

**Do not schedule more (2) VDF/registry work for invalid-token.**

---

## 7. Draft PR shape (when an implementer lane is assigned)

Grok lane did **not** open a PR (research-only; no live/public code publish required for this card). When an eligible implementation lane takes Phase A:

| Artifact | Notes |
|---|---|
| `server-config/provision/Watch-Hc2SteamAuth.ps1` | Detector + inhibit + alert hook |
| `server-config/provision/README.md` | Document inhibit flag + owner remedy |
| Optional: `hc2_launch.cmd` preflight | Exit early if inhibit set; log always-on line |
| Guard/restart scripts on box | Honor inhibit; **owner applies** live copies |

Flag policy N/A (ops, not mission feature flag).  
Mirrors N/A (no Chernarus SQF).  
**Never** commit secrets; never stage plaintext credential files.

---

## 8. What this session verified vs not

### Verified (static / memory / repo)

- Repo HC launch topology and Steam-per-HC design.  
- Server vs client binary split (`arma2oaserver.exe` vs `ArmA2OA.exe -client`).  
- Proven-dead (2) path from 2026-07-31 live trial (memory + task brief).  
- Session-0 vs InteractiveToken trap class.  
- Player-visible flash mechanism (engine connect retry without seat).  
- Wrong RPT path trap for HC2.

### Not verified this session (explicit)

- Live box RPT tail at close time (no live mutation / no SSH to livehost performed).  
- Probe A (HC without Steam) not executed.  
- Whether `WaspServerGuard` currently still escalates missing HC2 to full bounce (cited as 07-30 precedent; re-confirm before wiring inhibit).  
- Exact Peach/owner alert channel wiring on the box for a new watchdog.

---

## 9. Bottom line

**Remove interactive-sign-in from the critical recovery path only if probe A proves SteamAPI is optional for local HC.** That is unlikely on this Steam install; do not bet the next outage on it.

**What can be removed today from the outage *cost*:** the silent forever-retry and the full-stack bounce risk — by detecting `Unable to initialize Steam API` / Sign-in dialog, inhibiting HC2 relaunch, alerting the owner with the one-line remedy, and treating auth-dead as **degraded 1-HC**.

**(2) is closed** for refresh-token invalidation.  
**Credentials remain owner-only.**

---

## 10. File / evidence index

| Item | Path |
|---|---|
| This report | `docs/Proposals/wasp-hc2-steam-auth-durability-20260731/REPORT.md` |
| HC1 launcher | `server-config/hc_launch.cmd` |
| HC2 launcher | `server-config/hc2_launch.cmd` |
| Server launcher | `server-config/provision/server_launch.cmd` |
| Steam login runbook | `server-config/provision/Login-Steams.cmd` + `provision/README.md` |
| Rotation / RACE-4 notes | `docs/ops/SERVER-STARTUP-ROTATION.md` |
| Deploy HC recovery notes | `docs/ops/deploy-v2.ps1`, `DEPLOY-V2-CHANGELOG.md` |
| Live memory (trap) | `wasp-hc2-sandbox-steam-relaunch-trap` |
| Live memory (Steam kill wedge) | `wasp-boot-wedge-steam-and-scp-masking` |

**MILESTONE note for close:** this report is the owner-facing artifact for Fleet-Drop / Peach.
