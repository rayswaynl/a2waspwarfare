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

## 6. Owner-assisted / gated items
- Runtime RPT matrix (needs a human at an Arma 2 OA install) — turnkey checklist ready.
- Live/PC RPT via SSH — read-only pull available on request (live host runs Miksuu/PR8, not the RC → limited RC-proof value).
- Miksuu Google Drive dump (`armedassault`) — headless-blocked; owner download or attach files.
- Jerry bIdentify dump — targeted pulls on request.

## 7. Changelog
- **v0 (2026-07-01):** program stood up; Waves 1–2 (9 lanes, incl. terrain-parity) consolidated; RC identified (#125); release blockers surfaced.
