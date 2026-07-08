<!-- source: build-orchestration plan, not a design spec. GUIDE-REV GR-2026-07-07a -->

# CTL Implementation Plan — Commander Town Ledger (W/E)

Status: PLAN — implementation not yet started.
Base: `claude/build84-cmdcon36` @ `82a6b9c53`.
Branch: `fable/ctl-impl-v1` (worktree `C:\Users\Steff\a2wasp-ctl-build`).
Spec of record: `docs/design/v2/aicom-v2-commander-town-ledger.md` (merged via #807; this
plan does not restate it — see that file for the full data model, B1-B9 behaviours,
flag table, and telemetry contract).

## Scope

Build the CTL system for W/E (paid AI town investment + virtual per-town strength
ledger driving garrison materialization), per the merged spec. Ship as one or more
DRAFT PRs against `claude/build84-cmdcon36`, flag off by default
(`AICOMV2_LANE_CMD_TOWN_LEDGER = 0`), so this is inert until explicitly armed.

Out of scope: the GUER-side ledger/garrison-gain system. That workstream (PRs
#819/#835/#848/#877) is complete and already armed on `build84-cmdcon36` HEAD —
confirmed directly by reading current flag defaults before starting this plan. Nothing
further to build there.

## Architecture summary (from the spec — see spec for full detail)

- New brain: one side-agnostic loop covering both WEST and EAST, tick
  `AICOMV2_CTL_TICK_SEC` (30s). Records are NOT a local script-array like
  `Server_GuerDirector.sqf` uses — the spec stores the 6-field record via
  `setVariable` **on the side logic object**, one record per W/E-owned town. This is
  a deliberate architecture difference from GDIR; the build must follow the spec's
  storage model, not copy GDIR's local-array pattern verbatim.
- Materialization (B2): `effectiveGroups = 1 max round(baselineGroups * (strength max
  AICOMV2_CTL_SPAWN_MIN_STR))`. Published to the town object (`wfbe_ctl_str` or
  equivalent), read passively by the W/E spawn-sizing function. The *wiring pattern*
  (brain publishes via `setVariable` each tick; spawn function reads it with
  `getVariable` and a safe default of 1; read site is double-flag-gated) follows PR
  #835's proven precedent exactly. The *formula* does not: #835's GDIR-gain is an
  additive, no-nerf-only bonus (`+min(groups, ...)`, never below V1), whereas B2 is a
  full multiply that can scale a town's garrison both above and below V1 depending on
  strength. Build the multiply as specced — do not narrow it to bonus-only without an
  explicit decision (that would be owner-decision item 1 below, not a default to
  assume).
- Survivor read-back (B3) hooks the existing cleanup pass in `server_town_ai.sqf`
  (~lines 462-527), using unit-count ratio (not group-count ratio — deliberate,
  called out in the spec because W/E occupation groups vary in size more than GUER's).
- AI invest arm (B6/B7): inline block in the commander supervisor's `_canBuild` zone,
  "after ECON SINK; after REQDRAW if #805 lands first" per the spec. **Exact file and
  the #805 dependency status are unconfirmed — first build task must locate this
  before Phase 2 can proceed.**
- Telemetry: new `CTLSTAT|v1|` family, additive to `AICOMSTAT|v2|EVENT|` for invest
  actions. Consumers to update: `Tools/PrTestHarness/Ops/aicom-watch.ps1`, RPT pattern
  whitelist.
- Sovereignty (B8/B9): CTL never touches GUER Director state, camps, capture logic,
  HC architecture, or client code. Overlay only.

## File touch map

| File | Change | Can parallelize? |
|---|---|---|
| `Common/Init/Init_CommonConstants.sqf` | Append ~15 new flags, default per spec table | No — single-writer, foundational |
| `Server/AI/Server_CmdTownLedger.sqf` (new) | Brain loop, full B1-B9 core logic | No — foundational, needs continuous context |
| `Server/Functions/Server_GetTownGroups.sqf` (or equivalent W/E spawn-sizing fn — to confirm exact name) | Materialization read-site, PR #835-style pattern | Yes, once brain interface is fixed |
| `Server/FSM/server_town_ai.sqf` | Survivor read-back overlay in cleanup pass | Yes, once brain interface is fixed |
| Commander supervisor file (location TBD) | AI invest arm block | Yes, once located + interface fixed |
| `Tools/PrTestHarness/Ops/aicom-watch.ps1` + RPT whitelist | Telemetry consumer updates | Yes, fully independent |

Mirror-regen propagates the Chernarus edits above to Takistan and Zargabad
automatically (`dotnet run -c RELEASE`, `A2WASP_SKIP_ZIP=1`) — not manual per-map
work, except `mission.sqm` if the invest arm needs a UI/menu hook (spec says v1 has no
client code, so this should not apply).

## Fleet build sequence

**Phase 1 (sequential, 1 agent):** Locate the AI-invest arm insertion point and
resolve the #805 dependency; write the CTL brain script + register all flags. This
fixes the shared interface (record layout, variable names) for everything downstream.

**Phase 2 (parallel, one agent per file, per the table above):** materialization
read-site, survivor read-back overlay, AI-invest arm block, telemetry/tooling updates.
No two agents touch the same file.

**Phase 3 (sequential):** mirror-regen (CH→TK→ZG), `a2oa-verify-command` pass on any
new/uncertain SQF commands, lint (`check_sqf.py`) + bracket-delta gates on all changed
files, one integration-consistency read across the combined diff.

**Phase 4 (sequential):** deploy candidate build to the `Miksuus-TEST` box, soak run,
grade via `Tools/Soak/analyze_soak.py` per `rpt-triage` (window to current MISSINIT,
HC RPT for AICOM team logs).

**Phase 5:** `pr-preflight` final pass (claim recheck, flag-policy audit, evidence
wording) → draft PR(s) against `claude/build84-cmdcon36`.

## Open items carried from the spec (using spec's own recommendations as build defaults)

1. Below-baseline scaling from day one — spec recommends shipping full scaling (not
   the surplus-only fallback). Build to spec; T3 soak A/B decides later.
2. Prices/gains (50k/+0.25 repair, ×2 surge, 600k surge floor) — first-cut numbers,
   build as specced, tunable later.
3. Capture seed 0.25 vs mop-up overlap — spec recommends 0.25 + unchanged mop-up.
   Build to spec.
4. Human invest UI — v1.1, explicitly out of scope for this build.
5. Lobby params at flip-live — out of scope for this build (no lobby params in v1).

## Verification & evidence rules (per pr-preflight)

No "shipped"/"fixed" claims without branch + commit. No runtime-verified claims from
static work — soak RPT tokens (windowed to current MISSINIT) are the only acceptable
runtime evidence, and the PR body must say so explicitly if soak hasn't run yet.
