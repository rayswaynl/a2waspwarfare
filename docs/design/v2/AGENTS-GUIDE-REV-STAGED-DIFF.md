# AGENTS-GUIDE-REV-STAGED-DIFF

Status: SPEC-READY staged diff. This prep lane did not apply the diff to AGENTS.md, CLAUDE.md, or docs/AGENT-HANDBOOK.md because the user requested markdown deliverables only.

Guide rev for downstream PR bodies: cite old rev GR-2026-07-03a. The staged target rev is GR-2026-07-04a.

## Intent Summary

One later docs PR should apply the same policy changes to AGENTS.md and CLAUDE.md, then update docs/AGENT-HANDBOOK.md with matching references:

1. V2 artifact convention in "Where to look".
2. Soak-farm awareness in Claim protocol.
3. Spec required field in PR mechanics.
4. GUIDE-REV bump `GR-2026-07-03a` to `GR-2026-07-04a`.
5. Per-map AICOM profiles clarification.
6. FLAG-CENSUS cross-reference in flag policy.

## Patch 1: AGENTS.md

```diff
diff --git a/AGENTS.md b/AGENTS.md
--- a/AGENTS.md
+++ b/AGENTS.md
@@
-# WASP Warfare — Agent Guide
-<!-- GUIDE-REV: GR-2026-07-03a — PR bodies MUST cite this rev -->
+# WASP Warfare — Agent Guide
+<!-- GUIDE-REV: GR-2026-07-04a — PR bodies MUST cite this rev -->
@@
 ## Flag policy
 
 - Feature additions: flag-gate with `missionNamespace getVariable ["WFBE_C_FLAG", 0]`, default 0.
   With the flag at 0 the mission must be byte-identical to HEAD.
 - Correctness fixes (crashes, nil dereferences, idempotency guards): ship directly, no flag required.
 - Append new flag registrations to `Common/Init/Init_CommonConstants.sqf` only; never change existing defaults.
 - `WFBE_C_SIM_GATING` is owner-rejected; never wire it.
+- For V2 prep and dark-flag decisions, check `docs/design/v2/FLAG-CENSUS.md` before proposing a default flip.
@@
 ## PR mechanics
 
 - Draft PRs only: `gh pr create --draft --base claude/build84-cmdcon36`
 - Branch naming: `codex/<lane>-<topic>` or `fable/<topic>`; never target `master`
 - Commit format: `feat(<lane>): <summary> [flag <FLAG> default 0]`
 - PR body required fields: feature description, flag name + default, why flag-off is inert,
-  test plan, mirrors confirmed, GUIDE-REV `GR-2026-07-03a`
+  test plan, mirrors confirmed, linked spec/report artifact when the PR implements a V2 prep design,
+  GUIDE-REV `GR-2026-07-04a`
 - Never stage line-ending-churn files, `_MISSIONS.7z`, or a `nul` file artifact
@@
 ## Claim protocol
 
 Before starting any task:
 1. Check `agent-status.json` for in-progress claims on the target files. This is a
    fleet-coordinator runtime artifact and may be absent in the repo — if not present,
    fall back to the wiki Agent-Worklog page
    (`https://github.com/rayswaynl/a2waspwarfare/wiki/Agent-Worklog`) and open-PR check.
 2. Check open PRs for in-flight branches touching the same files.
 3. Check the Block J avoid-list in the fleet prompt for forbidden file sets.
 4. If a target file is touched by an in-flight PR, base on that PR's HEAD and declare
    "stacked on #NNN" in the PR body.
 5. One active claim at a time per lane.
+6. For deploy, live-box, scheduled-task, or soak-farm work, also check for an active `DEPLOY-CLAIM`
+   heading in the Agent-Worklog before touching stamps, RPT archives, scheduled tasks, deploy scripts,
+   or MPMissions state.
@@
 ## Where to look
 
 - AICOM team logs: HC RPT (`ArmA2OA.RPT`), not `arma2oaserver.RPT`; scope reads to the
   current `MISSINIT` boundary.
 - Soak KPIs: `Tools/Soak/README.md`
+- V2 specs, datasets, reports, soak-farm contracts, archive catalogs, flag census, and guide-rev staged
+  diffs: `docs/design/v2/`
 - Fleet lanes: `CODEX-FLEET-PROMPT.md`
 - Deep tooling reference (LoadoutManager full flow, template restore, RPT smoke, stacked-PR walkthrough,
   full trap taxonomy, match-report bugs, ZG constants): `docs/AGENT-HANDBOOK.md`
 - Wiki Agent-Guide: https://github.com/rayswaynl/a2waspwarfare/wiki/AI-Assistant-Developer-Guide
@@
 ## Owner constraints
 
 - Never deploy to the live server; PRs are the only output.
 - Never touch: HC architecture, player enrollment/JIP flow, deploy/box scripts.
 - GUER volume is the point; no caps or nerfs to GUER output.
 - Do not re-propose: TPWCAS, AI supply trucks, satchel AI, EMP/WP/DECOY SCUD munitions,
   doctrine personalities, antistack touch, ACR content.
+- AICOM V2 may use per-map profile data and map-specific constants. Do not repackage those profiles as
+  "doctrine personalities"; owner rejected doctrine personalities, not defensive per-map data reads.
```

## Patch 2: CLAUDE.md

Apply the same hunks as AGENTS.md. After applying, verify:

```powershell
fc AGENTS.md CLAUDE.md
```

Expected result: no differences, unless the repo intentionally diverges these files later.

## Patch 3: docs/AGENT-HANDBOOK.md

```diff
diff --git a/docs/AGENT-HANDBOOK.md b/docs/AGENT-HANDBOOK.md
--- a/docs/AGENT-HANDBOOK.md
+++ b/docs/AGENT-HANDBOOK.md
@@
 ### Post-soak KPI analysis
 
 python Tools\Soak\analyze_soak.py arma2oaserver.RPT --hc ArmA2OA.RPT
@@
-Grades a soak against the cmdcon41 fix-package KPIs (arrival %, zombies,
-scorecard. Full options and KPI thresholds: `Tools/Soak/README.md`.
+Grades a soak against the cmdcon41 fix-package KPIs (arrival %, zombies,
+scorecard. Full options and KPI thresholds: `Tools/Soak/README.md`.
+Nightly soak-farm pipeline, four-lens verdict rules, and the build-ledger contract are specified
+under `docs/design/v2/`.
@@
 ## Review checklist
@@
-- [ ] PR body cites GUIDE-REV `GR-2026-07-03a`
+- [ ] PR body cites GUIDE-REV `GR-2026-07-04a`
 - [ ] PR body contains: flag name, default, why flag-off is inert, test plan
+- [ ] PR body links the implementing spec/report in `docs/design/v2/` when the work comes from V2 prep
 - [ ] Shelved-PR register checked for duplicate proposals
```

## Verification Plan

After applying:

```powershell
Select-String -Path AGENTS.md,CLAUDE.md,docs\AGENT-HANDBOOK.md -Pattern 'GR-2026-07-03a|GR-2026-07-04a'
fc AGENTS.md CLAUDE.md
```

Expected:

- AGENTS.md header reads `GR-2026-07-04a`.
- CLAUDE.md header reads `GR-2026-07-04a`.
- docs/AGENT-HANDBOOK.md review checklist cites `GR-2026-07-04a`.
- No `GR-2026-07-03a` remains except in historical notes or this staged-diff artifact.
- `fc AGENTS.md CLAUDE.md` reports no diff.

