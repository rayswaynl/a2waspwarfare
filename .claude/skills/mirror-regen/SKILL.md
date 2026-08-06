---
name: mirror-regen
description: Run AFTER any edit inside Missions/[55-2hc]warfarev2_073v48co.chernarus and BEFORE staging — propagates Chernarus changes to the Takistan and Zargabad mirrors via LoadoutManager, restores drifted templates, and spot-checks per-map values.
---
<!-- source: Agent-Guide GUIDE-REV GR-2026-07-08a; per-map template values defer to Tools/Ops/Test-WaspVersionTemplates.ps1 since 2026-08-06 -->

# mirror-regen

Chernarus is the source; TK and ZG are generated mirrors. Full flow on the wiki
([AI-Assistant-Developer-Guide](https://github.com/rayswaynl/a2waspwarfare/wiki/AI-Assistant-Developer-Guide))
and `Tools/LoadoutManager/README.md`.

## 1. Run the mirror

NEVER bare `dotnet run` — the configuration is load-bearing (`DEBUG` adds funds/tier
unlocks; shipping it is a live-server incident). For PR work (propagation only, skip
the `_MISSIONS.7z` pack):

```powershell
cd Tools\LoadoutManager
$env:A2WASP_SKIP_ZIP = '1'
dotnet run -c RELEASE
```

If `dotnet` is missing: stop and report — do not hand-copy files between terrains.

## 2. Verify with the dry-run checker

```powershell
dotnet run -c RELEASE -- --check
```

Reports mirror drift without writing. Zero drift after step 1 = mirrors are current.

## 3. Restore version.sqf.template drift (always)

LoadoutManager may touch TK/ZG `version.sqf.template` as a side effect. Restore both to
merge-base before staging (run from repo root):

```powershell
git checkout origin/master -- "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/version.sqf.template"
```

Then run the invariant guard:

```powershell
powershell -NoProfile -File Tools\Ops\Test-WaspVersionTemplates.ps1
```

## 4. Per-map spot-checks (CH values must NOT leak into mirrors)

```powershell
Select-String -LiteralPath 'Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template','Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/version.sqf.template' -Pattern 'WF_MAXPLAYERS|STARTING_DISTANCE'
```

Expected values: defer to the `Tools\Ops\Test-WaspVersionTemplates.ps1` output from
step 3 — its PASS/FAIL lines are the authoritative per-map assertions. Do not trust
numbers hardcoded in this file or remembered from an earlier session; this section
previously carried stale WF_MAXPLAYERS values that contradicted the checker. Eyeball
context only: the `[61-...]` folder-name prefix is a player-slot label, not the
WF_MAXPLAYERS value; a live/generated `version.sqf` can also hold a different number
than the tracked `.template` — always read the `.template`. Neither mirror template
has `IS_CHERNARUS_MAP_DEPENDENT` or `IS_NAVAL_MAP` active (also checker-asserted).

## 5. Gotchas

- `mission.sqm` is NOT mirrored — lobby-slot changes need manual edits to all three
  `mission.sqm` files (and mission.sqm is the only TK/ZG file you may touch by hand).
- ZG has a `worldName == "Zargabad"` guard block in
  `Common/Init/Init_CommonConstants.sqf` (~lines 85-102) that pre-sets AICOM/base
  constants — never assume CH/TK defaults apply on ZG; check that block first.
- Never stage: `_MISSIONS.7z`, a `nul` file artifact, or files whose only diff is
  line-ending churn (`git diff --stat` a suspiciously-whole-file diff before adding).

## 6. Per-line lint suppression (noqa) — for context during mirror review

When reading mirror output, `// noqa: CODE` comments in source SQF suppress that specific
lint code on that line; bare `// noqa` suppresses all codes. Stale suppressions where the
finding no longer fires are reported as `DEADNOQA` — treat them as noise to clean up, not
as deliberate annotations. `A3PRIVATE` was restored to the gate list by PR #741; any
`// noqa: A3PRIVATE` in mirrored files should be removed once the underlying trap is fixed.
Full gate command: see `sqf-edit-guard` § 4 or `pr-preflight` § 4.

## 7. Done when

`git status` shows CH edits + matching TK/ZG mirror output only, templates restored,
`--check` clean, `Test-WaspVersionTemplates.ps1` all PASS.
