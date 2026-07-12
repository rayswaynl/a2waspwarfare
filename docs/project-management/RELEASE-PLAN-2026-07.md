# WASP Warfare — Release Plan (owner-declared 2026-07-06; reconciled 2026-07-12)

**VERSION NAME (owner, 2026-07-06): 1.0** — public name for the release. Engineering lineage keeps the
cmdcon tags (release build marker: release-1.0 + cmdcon lineage in git tag, e.g. v100-release-1.0).
Announcement, news post, wiki, and Discord all say **1.0**.

**Definition (owner):** Release = the V2 era, publicly announced. AI Commander V2 integrated (rollback
flags live), all owner-picked features settled, no known release-blocking defects.
**Timeline:** ASAP, quality-gated — no calendar date; gates decide.

**Reconciliation note (2026-07-12):** This plan originally assumed a single big-bang cutover event
(a `fable/v2-cutover-*` branch → `build84` → `master` merge, gated by a 3-stage Soak 1/2/3 program).
That did not happen as written. `docs/testing/V2-CUTOVER-SOAK-PROGRAM.md` was formally **retired**
2026-07-11 (Fleet task `wasp-aicom-v2-cutover-doc-reconcile`): there is no single
`WFBE_C_AICOM_V2_ENABLE`-style global flag, and PRs #760/#788/#793 never landed as the described
cutover. Instead, AICOM2 Snapshot/Allocator/Decapitate/AirResp and the GUER Director (lane 800) were
integrated straight onto `master` behind their own per-subsystem `WFBE_C_AICOM2_*` /
`AICOMV2_LANE_*` flags, each carrying its own default and rollback. The sections below describe
**current master reality**, not the original plan.

## Current integrated state (verified against `origin/master`, 2026-07-12)

| Control | Flag | Default | Status |
| --- | --- | --- | --- |
| Allocator | `WFBE_C_AICOM2_ALLOCATE_ENABLE` | `1` | Live. Flip to `0` restores legacy Strategy/AssignTowns target selection. |
| Decapitate | `WFBE_C_AICOM2_DECAP_ENABLE` | `1` | Live. Flip to `0` re-enables the legacy HQ-strike block (`AI_Commander_Strategy.sqf:753-804`). |
| Air response | `WFBE_C_AICOM2_AIRRESP_ENABLE` | `1` | Live (M6 organic W/E air-response closer). |
| GUER Director V2 (lane 800) | `AICOMV2_LANE_GUER_DIRECTOR` | `1` | Live. Spec merged #715, amendments #743. |
| Commander Town Ledger (CTL) | `AICOMV2_LANE_CMD_TOWN_LEDGER` | `0` | **Owner-disarmed** since 2026-07-09 — spec-only until soaked (2 open survivor-tracking defects, `CTL-ARMING-SPEC.md`). Sub-flags `AICOMV2_CTL_INVEST_ENABLE=1` and `AICOMV2_CTL_GARRISON_LINK=1` are individually armed (owner ruling 2026-07-12, soak evidence `box-harvest.log 2026-07-12T06:06-08:51Z, err=0/19`) but stay inert — double-gated behind the disarmed lane master switch. |

Rollback for each control is a single-flag flip, not a branch revert — the "rollback flag live"
release condition is satisfied per-subsystem, continuously, rather than by one global switch.

## Critical path (updated)

1. ~~Soak 1/2/3 + single cutover merge~~ — **superseded**; see reconciliation note above. AICOM2
   controls above are already live on `master`.
2. **Blocker audit** — DONE 2026-07-06. RCE + confused-deputy + `SEND_MESSAGE` injection
   confirmed fixed on master (commits `7d60b02b4`, `4f2c506b5`; allow-list + CODE-type checks
   verified via `git cat-file`).
3. **PR #768 resolved** — the PR itself is CLOSED (unmerged) on GitHub, but its content landed via
   `fable/hunt-batch-landing` (merge commit `6361be7f5`, content commit `0c0dada03`): supply
   pay-out no-op + DR-55 guard restructure + air-def/kill-assist/rearm/nil-freeze batch. Confirmed
   by `3b7091bbd` ("1.0 code gates closed (#768 landed, audit clean, BE-off posture)").
4. **cc48b patch** — DONE. Garrison `disableMove` → `disableAI "MOVE"` hotfix merged (PR #789,
   commits `74629663c`/`55474d1ce`/`04f29e0e6`). SML-2 real-dismounts flip is live
   (`WFBE_C_SML_DISMOUNTS = 1`, commit lineage `560c9d451` "cc48a live").
5. **Dark-flag disposition** — see table below; 7/8 armed, one outstanding (owner ruling recorded).
6. **Server-config hardening** — DONE. `verifySignatures=2`, `kickDuplicate=1` merged to master
   (PR #1076, commit `265f4cb15`, in `server-config/server-pr8.cfg`). `BattlEye` stays `0`
   (standing ruling: A2 BE master server is down; revisit if that changes).
7. **FPV purchase authority** — DONE. Server-authoritative wallet debit + one-shot rearm capability
   merged (PR #1070, commit `f508d1bb5`, "Fix server-authoritative FPV purchases and rearm").
8. **Stabilization window** — heavy monitoring on the release build once tagged; hotfix bar =
   same-day. Not yet entered — no tag has been cut (see 1.0 Release-Tag Checklist below).
9. **Announce** — news post + Discord (materials lane below). Not yet executed.
10. **Post-release:** CTL soak-then-arm (see table above), anti-cheat v1 arm decision, dark-flag
    round 2.

## Parallel lanes

- **Blocker audit** — DONE (see Critical path #2-3 above).
- **cc48b patch** — DONE (see Critical path #4).
- **Release materials** — status not reconciled in this pass; verify V2 news drafts and the
  announcement skeleton exist before the Announce step (Critical path #9).
- **Guides refresh** — status not reconciled in this pass; confirm owner review closed before
  Announce.
- **Dark-flag disposition** (before release): each remaining dark flag → ship-on / ship-dark / cut:

  | Flag | Current default | Status |
  | --- | --- | --- |
  | `WFBE_C_SML_DISMOUNTS` | `1` | Armed |
  | `WFBE_C_DEFENSE_CLIENT_GATE_ALIGN` | `1` | Armed |
  | `WFBE_C_AICOM_BUILD_ROAD_CLEAR` (dial) | `6` | Armed (non-zero, road-clear gate active) |
  | `WFBE_C_WALLS_V4` | `1` | Armed |
  | `WFBE_C_DEF_FORTIF_PACK` | `0` | **Dark — owner ruling 2026-07-12: ship-on.** Flag flip to `1` is a code change (`Common/Init/Init_CommonConstants.sqf`), NOT executed by this docs pass. Needs its own PR through the normal `sqf-edit-guard` + `mirror-regen` workflow before it counts as shipped. |
  | `WFBE_C_NAVAL_HVT` + `WFBE_C_NAVAL_CAP_L39` | `1` / `1` | Armed. Owner ruling 2026-07-12: 2×L39 CAP composition ratified — matches current code (`WFBE_C_NAVAL_CAP_L39=1` already selects twin L39_TK_EP1 over legacy Hind/An2). |
  | `AICOMV2_LANE_GUER_DIRECTOR` (GUER Director V2) | `1` | Armed. Owner ruling 2026-07-12: RATIFIED at 1.0 (no longer post-release-only as the original plan assumed — it is live now). |
  | `WFBE_C_AIRFIELD_OWNERSHIP_GATE` | `1` | Armed |

  **7 of 8 armed.** `DEF_FORTIF_PACK` is the sole outstanding dark flag; owner has ruled ship-on,
  execution is a follow-up code PR (see Discovered Issues / follow-up in the accompanying report).

- **Watching:** permDay FPSREPORT confirm, first `MATCH|v1|END` → match-report embed verify — not
  reconciled in this pass.

## Owner rulings — Command Review 2026-07-12

Recorded verbatim from the 2026-07-12 Command Review triage, for the historical record and to
close the open decision points this plan previously listed as pending:

- **GUER Director V2** — RATIFIED at 1.0. (Matches code: `AICOMV2_LANE_GUER_DIRECTOR=1`, live.)
- **NAVAL HVT** — 2×L39 ratified. (Matches code: `WFBE_C_NAVAL_CAP_L39=1`, live.)
- **DEF_FORTIF_PACK** — ship-on. (Does NOT yet match code: flag is still `0`; flip is an open
  follow-up code PR, not executed here.)
- **verifySignatures / kickDuplicate** — hardened. (Matches code: `verifySignatures=2`,
  `kickDuplicate=1` merged via PR #1076.)
- **FPV** — harden-in-place. (Matches code: PR #1070 merged, server-authoritative purchase/rearm.)
- **CTL (Commander Town Ledger)** — soak-then-arm. (Matches code: lane master flag stays `0`;
  sub-flags armed incrementally with recorded soak evidence per owner rulings as gates are met.)

## Release gates (all must be green)

- [x] Blocker audit DONE 2026-07-06 (RCE + confused-deputy + injection fixed-confirmed;
  commits `7d60b02b4` + `4f2c506b5`).
- [x] PR #768 content landed (commit `6361be7f5`); code gates closed per `3b7091bbd`.
- [x] BattlEye posture: DECISION — ship 1.0 with BE OFF (A2 BE master server down). BE filters +
  chat bridge stay post-release, gated on the BE ecosystem coming back.
- [x] verifySignatures/kickDuplicate hardened for public deploy (PR #1076).
- [x] FPV purchase authority hardened in place (PR #1070).
- [ ] `DEF_FORTIF_PACK` ship-on ruling executed in code (flag flip + mirror regen) — OPEN.
- [ ] Cutover-era "3 clean soaks" runbook is retired and has no direct replacement identified in
  this pass. Recommend: before tagging, run a fresh full-build smoke/soak pass covering the
  currently-armed AICOM2 controls (Allocator, Decapitate, AirResp, GUER Director) together, using
  the current `Tools/Soak` harness (autopilot loop / experiment engine), and record the result here.
  Do not treat this plan as gate-satisfied on that basis until that pass is run and logged.
- [ ] Cutover build boots clean on all 3 terrains (marker + error budget) — re-verify once the
  release marker is refreshed (see 1.0 Release-Tag Checklist below).
- [ ] Release materials / Guides refresh — status not reconciled in this pass; confirm before
  Announce.
- [x] Version name: 1.0 (owner) — [ ] announcement sign-off pending.

## 1.0 Release-Tag Checklist (PREP ONLY — do not cut the tag yet)

This section prepares the mechanics for the 1.0 release tag. **No tag is cut by this PR.** Cut the
tag only once every item in Release Gates above is green and the owner gives explicit go-ahead.

**Current state:** `WF_RELEASE_MARKER` in `version.sqf.template` (all three maps — Chernarus source,
Takistan/Zargabad mirrors, currently byte-identical) still reads:

```
WASPRELEASE|v1|candidate=build89-cmdcon44t-20260704|git=build89-cmdcon44t|terrain=manual
```

This is stale — dated 2026-07-04, and `origin/master` HEAD is now `130003e7b`+ (2026-07-12), many
commits past `cmdcon44t`. It must be refreshed to the actual final-build commit before the tag is
cut, not before.

**When the build is declared final, the cutting agent/owner should:**

1. Confirm every Release Gates checkbox above is `[x]`.
2. Pick the exact commit on `master` that becomes the release build.
3. Update `WF_RELEASE_MARKER` in the Chernarus source `version.sqf.template` to reflect that
   commit, e.g. `WASPRELEASE|v1|candidate=v100-release-1.0|git=<short-sha>|terrain=manual`
   (keep the `terrain=manual` convention; adjust `candidate=`/`git=` to the real tag/sha at cut time).
4. Run the LoadoutManager mirror (`cd Tools\LoadoutManager && dotnet run -c RELEASE`) so the
   Takistan/Zargabad `version.sqf.template` copies pick up the change identically, then verify with
   `-- --check` that nothing else drifted.
5. This IS a `.sqf`/`.hpp`-adjacent mission-source edit — route it through the normal
   `sqf-edit-guard` + `mirror-regen` workflow and lint gates, not as a docs-only change.
6. Tag naming convention (per the version-name ruling above): `v100-release-1.0`, annotated with
   the exact commit SHA and cut date. Follow existing tag conventions
   (`v89-cmdcon44`, `v89-cmdcon48`, `v89-cmdcon48a`, `v88-pre-consolidation`) for message format.
7. Do NOT push the tag, deploy the build, or touch the live Hetzner server
   (`78.46.107.142`) as part of this checklist. Tagging `master` is a repo action; deploying it to
   the live game server is a separate, explicitly gated action requiring its own owner go-ahead.
