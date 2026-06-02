# Construction Logic List Cleanup

Patch-ready playbook for the `Construction_SmallSite.sqf` / `Construction_MediumSite.sqf` `wfbe_structures_logic` asymmetry.

This is not a gameplay patch yet. It is the source-backed checklist a future code owner should use before changing construction code.

## Status

| Field | Value |
| --- | --- |
| Current state | Source-confirmed asymmetry, runtime impact smoke-pending |
| Priority | P2 correctness / maintenance candidate |
| Canonical owner page | [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) |
| Propagation owner | [Source fix propagation queue](Source-Fix-Propagation-Queue) after a source patch exists |
| Do not mix with | DR-6 construction authority hardening, CoIn UI redesign, or repair-system revival |

## Source Evidence

All source paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| Area | Evidence |
| --- | --- |
| Small-site initial tracking | `Server/Construction/Construction_SmallSite.sqf:62-70` creates the construction logic, sets `WFBE_B_*` variables, and appends `_nearLogic` to `wfbe_structures_logic`. |
| Small-site cleanup bug candidate | `Server/Construction/Construction_SmallSite.sqf:92-99` waits for completion, comments that the logic should be removed because it is built, then appends `_nearLogic` again. |
| Medium-site expected pattern | `Server/Construction/Construction_MediumSite.sqf:62-70` appends `_nearLogic`, then `:107-114` removes `_nearLogic` after completion. |
| Structure lists seeded elsewhere | `Server/Init/Init_Server.sqf:363` seeds `wfbe_structures`; `:394` seeds `wfbe_structures_live`. A static source search did not find a matching initializer for `wfbe_structures_logic`. |
| Repair cleanup consumer | `Server/Functions/Server_HandleBuildingRepair.sqf:77-81` removes repair logic on successful rebuild; `:97-103` removes it when completion degrades to zero or is lost. |
| Repair caller caveat | `Server/Functions/Server_HandleBuildingRepair.sqf` is compiled from `Server/Init/Init_Server.sqf:26`, but no active source caller was found beyond compile/init text. |
| Killed-building flow | `Server/Functions/Server_BuildingKilled.sqf:81-90` decrements `wfbe_structures_live` and removes the dead object from `wfbe_structures`; it does not add repair logic. |
| CoIn live-limit state | `Client/Module/CoIn/coin_interface.sqf:713-715` mutates client live-limit display state; `:891-892` displays the limit, separately from `wfbe_structures_logic`. |

Wave P also checked generated/parallel mission copies: source Chernarus, maintained Vanilla Takistan, Eden and Napf carry the same SmallSite add/add and MediumSite add/remove shape. Treat Vanilla as the required propagation target after a source patch; treat modded copies as explicit owner decisions.

## Why It Matters

Small and medium construction sites are near twins. MediumSite adds the build logic while construction is in progress and removes it after completion. SmallSite adds the same logic before construction and again at the cleanup point where its own comment says removal should happen.

If `wfbe_structures_logic` is active at runtime, SmallSite can leave duplicate or stale construction logic entries behind. If the list is effectively dormant because initialization/callers are missing, this still creates generated-code drift and makes the repair-system contract harder to reason about.

## Minimal Patch Shape

Patch the source Chernarus mission first:

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Construction/Construction_SmallSite.sqf`

Keep the initial append around line `70`; it marks an in-progress construction logic.

Change the post-completion cleanup around line `99` from append to remove:

```sqf
_logik setVariable ["wfbe_structures_logic", (_logik getVariable "wfbe_structures_logic") - [_nearLogic]];
```

Do not change `Construction_MediumSite.sqf` unless adding a shared nil-safe guard to both files. If runtime proves the list can be nil, use a small local guard before add/remove rather than rewriting the construction flow:

```sqf
_logicList = _logik getVariable "wfbe_structures_logic";
if (isNil "_logicList") then {_logicList = []};
```

Only add that guard if the runtime actually needs it. A one-line add-to-remove patch is the smallest correctness change.

## Propagation Plan

1. Patch source Chernarus only.
2. Run the maintained generation path from the repo root:

```powershell
$env:A2WASP_SKIP_ZIP = "1"
dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj
```

3. Inspect `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Construction/Construction_SmallSite.sqf`; the same cleanup line should now remove `_nearLogic`.
4. Do not bulk-edit `Modded_Missions` unless a maintainer explicitly claims modded mission propagation. Existing docs classify those folders as partial forks/stubs, not maintained generation targets.
5. Update [Source fix propagation queue](Source-Fix-Propagation-Queue) and `agent-release-readiness.json` only after source and Vanilla diffs exist.

## Smoke Checklist

Run this before claiming the fix:

| Smoke | Expected result |
| --- | --- |
| Dedicated or hosted build: construct one small structure. | Structure finishes, real site appears, markers/init run, and `wfbe_structures_logic` does not gain a duplicate completed small-site logic. |
| Construct one medium structure. | Medium behavior remains unchanged; its construction logic is removed after completion. |
| Destroy the created structure. | `Server_BuildingKilled.sqf` still removes the dead object from `wfbe_structures` and decrements `wfbe_structures_live` as before. |
| If building repair is revived or found live. | `Server_HandleBuildingRepair.sqf` still removes the repair logic on success and failure. |
| JIP after construction. | Allied structure marker/init state remains visible to a late joiner. |

Useful temporary RPT/debug probes, if a tester wants exact evidence:

```sqf
diag_log format ["WASP construction logic count before=%1", count (_logik getVariable "wfbe_structures_logic")];
diag_log format ["WASP construction logic count after=%1", count (_logik getVariable "wfbe_structures_logic")];
```

Keep probes out of the final source patch unless the owner wants permanent debug instrumentation.

## Acceptance Criteria

- Source Chernarus SmallSite post-completion path removes `_nearLogic`.
- Maintained Vanilla Takistan carries the same fix after `Tools/LoadoutManager`.
- MediumSite behavior is unchanged.
- No source claims are made about visible player impact until Arma 2 OA smoke records it.
- Docs stay routed through this page, [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue).

## Continue Reading

Previous: [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) | Next: [Source fix propagation queue](Source-Fix-Propagation-Queue)

Related: [Testing workflow](Testing-Debugging-And-Release-Workflow) | [Tools/build workflow](Tools-And-Build-Workflow) | [Feature status](Feature-Status-Register)
