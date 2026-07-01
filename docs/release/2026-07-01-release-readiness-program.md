# WASP Warfare — July 2026 Release-Readiness Program

**Status:** 🔴 NO-GO as a release claim (runtime unproven). This is a **living tracking PR** — updated as work proceeds.
**Base:** `origin/master` @ `5bf5f923` · **Terrains:** Chernarus (source of truth) + Takistan (generated mirror via `Tools/LoadoutManager`)
**Tracks alongside** the release-loop drafts #123 · #124 · #125 · #126 (not superseding them).

> **Security note (privacy convention, per #124):** this repo is public. Server-authoritative input-validation findings are summarized here at a high level only — no exploit payloads. Full technical detail is handled privately with the owner until fixed.

## 1. Goal & scope
- Release-ready for **both** Chernarus and Takistan.
- **Code optimized**; **core features improved** (especially the AI Commander).
- **Wiki kept up to date.**
- Multi-source, multi-agent, loop-driven.

## 2. Release candidate
- **Leading candidate = #125** (`codex/release-command-center-20260630`) — 64 ahead / 2 behind master; the only content lane near-current.
- **#124 (r8)** heavily stale (108 behind, ~56-file merge conflict vs current master) → fold unique content (GUER improvised armor / patrol variety) or retire.
- **#126** focused AICOM guardrails — but its two "captured findings" were **false positives** (see §4).
- **#123** findings log — docs-only tracker.

## 3. Source matrix
| Source | Access (headless) | Use |
|---|---|---|
| `rayswaynl/a2waspwarfare` (+ wiki) | direct | primary; wiki reconciliation |
| `Miksuu/a2waspwarfare` (live public baseline) | mined | lineage/risk delta (done — Lane B) |
| Benny Warfare BE 2.073 + BI forums | web | AICOM lineage + borrowable mechanics |
| Server stats (miksuu.com/wasp, :8080) | web | live usage / balance signal |
| Live + PC RPT via SSH (Game PC / Hetzner) | owner-authorized, read-only | runtime evidence — NOTE: live host runs Miksuu/PR8, not the RC, so limited RC-proof value |
| Miksuu Google Drive dump (pw `armedassault`) | headless-blocked | owner download / provide files |
| Jerry bIdentify dump | heavy | targeted pulls on request |

## 4. Consolidated findings — Waves 1–2 (9 lanes; criticals independently re-verified in-tree)

### Release blockers
- **PVF dispatcher hardening (CRITICAL, pre-existing).** `Server_HandlePVF` selects its handler from a client-controlled field with no binding to the triggering variable and no allow-list, so a client can invoke server-authoritative functions it should not. Verified in code. The RC **widens** the surface with 10 new `WFBE_PVF_*` names that are not in the BattlEye allow-list (`publicvariable.txt` covers only `kickAFK`). *Fix: bind the dispatcher to the triggering PV name (or per-handler PVEHs); extend the BE allow-list.* (Detail held privately — public repo.)
- **Release-gate scanner has dead assertions (BLOCKER for the gate's validity).** Gates `wddm-static-artillery` and `supply-truck-heli` AND-require `WDDM_ARTILLERY_AUDIT` / `SERVICE_SUPPLY_AUDIT`, which exist **only** in the `pr8-stress` overlay — never in native mission code. Those gates **can never pass a real run**, so the "scanner PASS" signal is partly invalid. Verified (`Test-WaspReleaseRptEvidence.ps1:319,325`). *Fix: remove stress-only tokens from the native gates (or split into a stress-only gate).*

### High
- **`WFBE_C_SEC_HARDENING` defaults OFF** → upgrade-queue handlers do not enforce requester side (forged-side injection). *Fix: default it on, or make the side guard unconditional.*
- **Config default disagreements (Parameters.hpp lobby default overrides the code constant):**
  - `WFBE_C_GUER_PLAYERSIDE` is **hard-locked ON** (`initJIPCompatible.sqf:141` re-reads the param default post-init) → an admin disabling GUER in the lobby is silently undone.
  - `WFBE_C_NAVAL_HVT=1` with no lobby toggle and LHD hull offsets self-marked "BEST-GUESS, verify in-engine" → **needs one in-engine boot** before release.
  - `WFBE_C_AI_MAX`: constants=12, lobby ships **4** → AICOM density tuning (calibrated at 12) runs at ~⅓ intent.

### Medium
- **AICOM supervisor** (fork-new, #1 risk surface): boot `waitUntil` has no timeout and the heartbeat is seeded *before* it → a hung pre-init supervisor is **unrecoverable by the watchdog**; ≤1-tick zombie double-charge at watchdog restart (`ChangeAICommanderFunds` not idempotent). Otherwise architecturally sound.
- **Deployment footguns (keep at 0):** `WFBE_C_AICOM_HC_MERGE_ENABLE` (silently no-ops — worker never compiled) and `WFBE_C_AICOM_HC_TOPUP_ENABLE` (charges funds, no HC consumer).
- **Telemetry/soak flags shipping ON:** `PERFORMANCE_AUDIT_ENABLED`, `CLIENT_FPS_REPORT` (opposite its intended off-default), `MAP_ICON_BLINKING_ENABLED`, `AICOM_SERVICE_ENABLED`.
- `Init_NavalHVT.sqf:360` unguarded persistent `createGroup resistance` (minor; bounded to ~3 carriers).

### Verified-clean / good news
- **Group/144-cap:** comprehensively guarded (central `WFBE_CO_FNC_CreateGroup` wrapper + layered GC + founding block at 110 + GUER soft-cap at 80). The historical group-leak failure mode appears **retired**.
- **Terrain parity (Lane G): CLEAN.** All 18 `Server/AI/Commander` files and all 31 PR-modified shared files are byte-identical across terrains (only intentional diffs: `SET_MAP` id + terrain help text). Only pre-existing artillery-config divergences remain (dead code / mod-vs-vanilla / balance) — not parity bugs. Nothing needs re-mirroring for release.
- **AICOM command-semantics watch-list:** all 10 forbidden tokens confirmed A3-only (BIKI-cited). Suggested additions: `param`, `apply`, code-predicate `select {…}`, `allPlayers`.
- **Lineage:** Miksuu public repo lacks the **entire** `Server/AI/Commander` layer (18 files) → AICOM is fork-new with zero public runtime history = the biggest release risk.
- **Docs:** #126's two flagged "discrepancies" are **both false positives** (commander guide is correct; bank payout/destruction values agree across `briefing.html` / `briefing.sqf` / code).

## 5. Program — phases & agent model
- **Phase 0 (done):** 9-lane research recon (above).
- **Phase 1:** fix release blockers — scanner dead-assertions; PVF dispatcher hardening + BE allow-list; `SEC_HARDENING` default; flag reconciliation. Child branches, tracked here.
- **Phase 2 (owner-gated):** runtime RPT proof matrix — both terrains × server/HC1/HC2/start-client/late-JIP, per the turnkey capture checklist (Lane D).
- **Phase 3:** code-optimization pass — AICOM per-tick `O(allUnits)` scans, marker-update loops, GC pacing.
- **Phase 4:** AI Commander feature improvements — mined from Benny/lineage + live data.
- **Phase 5:** wiki reconciliation — align pages to RC truth; flip runtime-pending → runtime-proven after Phase 2.

**Agent model:** parallel research/audit subagents (Sonnet) per lane → orchestrator verifies criticals in-tree → fixes land in focused child branches → this PR tracks status. Loops re-run lanes until dry.

## Phase-3 perf backlog — adversarially validated (2026-07-01)

Lane L proposed 10 optimizations; a 10-skeptic verification workflow tested each against the RC code. **6 of 10 were rejected or moot** — two of them because the *fix itself* was unsafe. Survivors:

**Do (safe):**
| Item | Where | Win | Note |
|---|---|---|---|
| Income player-count scan | `Server/FSM/updateresources.sqf:~28` | med | `{isPlayer} count allUnits` runs every income tick (~1–3s). Fix = throttle recompute to every 5th tick. (Do NOT use `MonitorPlayerCount` as a cache — it publishes no count var.) |
| GroupsGC per-side hoist | `Server/FSM/server_groupsGC.sqf:82,189` | med | Hoist ONLY the per-side allUnits (82) + allGroups (189) above the `forEach [west,east,resistance]`. The cap-safety scans (296/315) are separate single-passes — leave them. |
| GRPBUDGET triple-count | `Server/AI/Commander/AI_Commander.sqf:714-716` | low | Replace 3 filtered `count allGroups` with one bucketed pass. Logging-only, zero cap impact — free but small. |

**Do only with the SAFE reformulation (highest value; needs a test-server run):**
| Item | Where | Win | Safe form |
|---|---|---|---|
| Common_CreateGroup first-pass scan | `Common/Functions/Common_CreateGroup.sqf:~30` | med-high | The unconditional `count allGroups` on *every* createGroup is the real hotspot during town-activation bursts. **Do NOT** let the `wfbe_grpcnt` cache gate the ≥140 emergency-GC directly — a stale cached count during the 60s warmup could skip the GC and hit the 144-cap. Safe form: cache as early-exit only when cached `< 120`; always live-scan when cache is ≥120, stale, or absent. |

**Rejected / moot (do NOT change):**
- Vehicles OB scan (item 2) — already co-gated with the 25-min audit.
- Wildcard `PickLeastLoadedHC` hoist (item 4) — Wildcard fires every 1800s, one branch per draw; hoist would break W24's intentional double-pick load-spread.
- Boot diagnostic scan (item 6) — one-shot; cache-read would corrupt the boot snapshot.
- Disband-guard `nearEntities` (item 8) — **safety regression**: `nearEntities ["Man"]` misses mounted players → team deleted under a watching player. One-shot anyway.
- Seed `wfbe_grpcnt_guer=0` (item 9) — would silently disable the GUER 80-cap during the 60s warmup.
- groupsMonitor gate (item 10) — spawn already commented out in all 5 mission variants.

## Phase-5 wiki fix-list — verified (2026-07-01)

Lane J audited the wiki vs RC; the HIGH factual errors were spot-verified against code:

| Wiki page(s) | Stale claim | Correct (verified) |
|---|---|---|
| `AI-Commander-Execution-Loop-Reference` | UPGRADE_INTERVAL = 120s | **300s** (B67, `Init_CommonConstants.sqf:241`) ✅ (a sister page already has 300 — they contradict) |
| `New-Player-Quickstart` + `Earning-Funds-And-Score` | supply delivery = SV × 4, citing `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF` | **floor(SV × 20)** via `WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER=20` (`:901`). The cited COEF is **dead code** — 1 reference total (its own definition) ✅ |
| `Commanders-Handbook` + `Upgrade-Research-Cross-Faction` | Fast Travel prereq = Light 1 + Supply 1 | **Light 3 + Supply Rate 1** (`Upgrades_USMC.sqf` LINKS) — agent-reported; confirm the LINKS row at edit time |
| +7 line-number drift cites (4 pages) | EXPERITAL block cites off by ~183 lines | refresh inline `Init_CommonConstants.sqf:NNN` cites |

Already-accurate (no edit): `July-2026-Release-Readiness`, `AI-Commander-Tunable-Constants-Reference`, `Supply-Mission-Player-Guide`, GUER overview, `Current-Source-Status-Snapshot`. All wiki edits stay **runtime-pending** until Phase 2 passes.

## Phase-4 AICOM improvement catalog — grounded (2026-07-01)

10 lineage-mined ideas (HETMAN / ALiVE / Field of War / Benny) were grounded against the fork's 18-file Commander layer. The fork is **more complete than the generic ideas assume** — most are already partly built.

**Real gaps worth building (ranked by value):**
| # | Idea | Status | Pri / effort | Note |
|---|---|---|---|---|
| 6 | FPS-gated AI throttle | PARTIAL | **med / small** | Fork samples `diag_fps` (SRVPERF) but **discards it**. Wire it to widen Produce/Teams intervals under low FPS → fixes the "AI stops shooting after an hour" death-spiral. Highest-value real gap. |
| 2 | Personality presets (Turtle/Balanced/Rusher) | NO | med / small | Only an economic LEVEL param exists; aggression constants aren't preset-wired. Lobby param + one switch block, no runtime-file edits. |
| 5 | Defensive reserve fraction + per-objective type caps | PARTIAL | med / small | Concentration + hard-cap exist; no reserve floor / per-type sub-cap. Both flag-gated inert-by-default. |
| 1 | Treasury-depth armor weighting | PARTIAL | low / small | Factory/air gates + maturity ramp exist; only treasury-depth bucket weighting missing. Polish. |
| 4 | Tunable cadence + HQ-attack interrupt | PARTIAL | low / small | 60s interval is fixed; no HQ-under-attack fast-refresh path. |
| 7 | Ringfenced defense fund reserve | PARTIAL | low / small | Team-role separation exists (RELIEF_MAX); no fund reservation. |
| 3 | Front-pressure / morale feedback | NO | low / med | ⚠️ surfaced a **latent dead input**: `wfbe_aicom_town_weight` is read by the spearhead scorer (`Strategy.sqf:204,331`) but **never written** — a scaffolded-but-unfinished feature. Either complete it (#3) or remove the dead read. |
| 8 | AA-before-CAS air sequencing | NO | low / med | CAS wildcards (W13/W22) never check AA coverage before drawing. |

**Do NOT build:** #10 player-count-scaled economy is **already fully implemented** (3 interlocking layers) — the live 39:1 K/D is the `AI_MAX=4-vs-12` config issue, not an economy gap. #9 HC decision-loop offload is **architecturally blocked** in A2 SQF (per-unit FSM already on HC; only config levers remain).

## 6. Owner-assisted / gated items
- Runtime RPT matrix (needs a human at an Arma 2 OA install) — turnkey checklist ready.
- Live/PC RPT via SSH — read-only pull available on request (live host runs Miksuu/PR8, not the RC → limited RC-proof value).
- Miksuu Google Drive dump (`armedassault`) — headless-blocked; owner download or attach files.
- Jerry bIdentify dump — targeted pulls on request.

## 7. Changelog
- **v0 (2026-07-01):** program stood up; Waves 1–2 (9 lanes, incl. terrain-parity) consolidated; RC identified (#125); release blockers surfaced.
- **v0.1 (2026-07-01):** Phase-3 perf backlog adversarially validated — 6/10 raw candidates rejected as moot or unsafe (two fixes would have re-introduced bugs). AICOM idea-grounding + wiki-reconciliation lanes still running.
- **v0.2 (2026-07-01):** Phase-4 AICOM catalog grounded against code (3 real gaps, 5 partial, 1 already-done, 1 architecturally-blocked; top gap = wire the already-sampled server FPS into an AI throttle; found a latent dead input `wfbe_aicom_town_weight`). Phase-5 wiki fix-list verified (4 factual errors incl. a dead-constant citation).
