# UI IDD Collision Repair

Status: confirmed UI/resource risk, patch-ready. This page owns the exact source evidence and safe repair plan for duplicated `idd` values in dialogs and title resources.

Combined UI cleanup route: [UI resource parity cleanup](UI-Resource-Parity-Cleanup) is the canonical matrix for stale `RscMenu_Upgrade`, Economy missing-control writes and duplicate IDDs. Use this page for the duplicate-IDD patch details after that matrix tells you which branch/root still needs work.

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

Branch check 2026-06-23 after fresh fetch: current docs checkout `docs/developer-wiki-index` `edbd341e` keeps the `b5219d47` Dialogs/Titles line shape; docs/source, Miksuu `b8389e748243` and perf `0076040f` still keep `RscMenu_EASA` and `RscMenu_Economy` both on `idd = 23000` in Chernarus and maintained Vanilla. Current stable `origin/master@0139a346`, current B69 `origin/claude/b69@8d465fce`, adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` and historical `a96fdda2` move EASA to `idd = 24000` and keep Economy on `23000` in both maintained roots. The `RscOverlay` / `OptionsAvailable` title collision on `10200` remains present in every checked ref and root. No checked maintained root has a hard-coded `findDisplay 23000`, `findDisplay 24000` or `findDisplay 10200` caller, so duplicate IDD cleanup remains maintenance/debug/future-control risk rather than a proven live lookup bug.

## What To Read

- `description.ext`
- `Rsc/Dialogs.hpp`
- `Rsc/Titles.hpp`
- `Client/GUI/GUI_Menu_EASA.sqf`
- `Client/GUI/GUI_Menu_Economy.sqf`
- `Client/GUI/GUI_Menu.sqf`
- `Client/GUI/GUI_Menu_Service.sqf`
- `Client/Client_UpdateRHUD.sqf`
- `Client/FSM/updateavailableactions.fsm`
- [UI resource parity cleanup](UI-Resource-Parity-Cleanup)
- [Client UI systems atlas](Client-UI-Systems-Atlas)
- [Feature status register](Feature-Status-Register)

## Current Collisions

`description.ext` includes the relevant UI resources:

- `description.ext:54` includes `Rsc\Ressources.hpp`.
- `description.ext:56` includes `Rsc\Dialogs.hpp`.
- `description.ext:58` includes `Rsc\Titles.hpp`.

Two dialog classes share `idd = 23000`:

| Resource | Evidence | Runtime owner |
| --- | --- | --- |
| `RscMenu_EASA` | `Rsc/Dialogs.hpp:3209-3211` | `Client/GUI/GUI_Menu_EASA.sqf` |
| `RscMenu_Economy` | `Rsc/Dialogs.hpp:3287-3289` | `Client/GUI/GUI_Menu_Economy.sqf` |

Stable/B69/B74/release caveat: current stable `0139a346`, current B69 `8d465fce` and adjacent B74 `b23f557f` move EASA to `idd = 24000` and keep Economy on `23000` in both maintained roots (`Dialogs.hpp:2926-2928`, `:3004-3006`). Historical release evidence `a96fdda2` carries the same distinct dialog IDD shape in both maintained roots (`Dialogs.hpp:2862-2864`, `:2940-2942`). Docs checkout, Miksuu and perf still need the EASA/Economy parity cleanup if they remain target branches.

Two title resources share `idd = 10200`:

| Resource | Evidence | Runtime owner |
| --- | --- | --- |
| `RscOverlay` | `Rsc/Titles.hpp:44-46` | Started from `Client/Init/Init_Client.sqf:149` on cutRsc channel 1365. |
| `OptionsAvailable` | `Rsc/Titles.hpp:164-165` | Started from `Client/FSM/updateavailableactions.fsm:62` and `Client/Client_UpdateRHUD.sqf:7`. |

There is no standalone `Client/RHUD` subtree in the current source. RHUD is folded into `OptionsAvailable` plus `Client/Client_UpdateRHUD.sqf`, so title-ID repair must preserve that display-owner relationship.

Wave Q added a separate title lifecycle-handle ownership finding. `EndOfGameStats` uses `idd = 90000` (`Rsc/Titles.hpp:532-533`), but it shares the same `onLoad`/`onUnload` helper scripts and therefore the same `uiNamespace["currentCutDisplay"]` key as `OptionsAvailable` (`Titles.hpp:539-540`). `Client/GUI/GUI_EndOfGameStats.sqf:13` cuts `EndOfGameStats`, then waits for and writes controls through `currentCutDisplay` at `:34-44` and `:86-93`. Meanwhile `Client/Client_UpdateRHUD.sqf:183-190` keeps its one-second loop alive and `_RHUDGetDisplay` can re-cut `OptionsAvailable` when the shared key is null (`:89-92`). This is a lifecycle handle collision even if all `idd` values are made unique.

## Title Display Handle Branch Matrix

This matrix is separate from the duplicate-IDD matrix above. It tracks the stored display-handle ownership problem: `OptionsAvailable`/RHUD/action icons and `EndOfGameStats` both use the same `currentCutDisplay` helpers.

| Root / branch | OptionsAvailable / RHUD / action icons | EndOfGameStats | Practical meaning |
| --- | --- | --- | --- |
| Docs checkout `edbd341e` Chernarus | Same line shape as `b5219d47`: `Rsc/Titles.hpp:170-171` calls `GUI_SetCurrentCutDisplay.sqf` / `GUI_ClearCurrentCutDisplay.sqf`; `Client_UpdateRHUD.sqf:89-92` and `updateavailableactions.fsm:225-230` read/write `currentCutDisplay`. | `Rsc/Titles.hpp:539-540` calls the same helpers; `GUI_EndOfGameStats.sqf:34-44,86-93` writes stat controls through `currentCutDisplay`. | Patch-ready. The lifecycle-handle collision remains in current docs/source. |
| Maintained Vanilla Takistan at docs checkout `edbd341e` | Same helper/key shape in `Rsc/Titles.hpp:170-171,539-540`, `Client_UpdateRHUD.sqf:89-92`, `updateavailableactions.fsm:225-230` and `GUI_EndOfGameStats.sqf:34-44,86-93`. | Same. | Propagate deliberately after any source fix. |
| Current stable `origin/master@0139a346`, B69 `8d465fce` and B74 `b23f557f` | Same shared helper/key shape in both maintained roots; title line refs drift to `Rsc/Titles.hpp:174-175,587-588`, RHUD still reads/re-cuts through `Client_UpdateRHUD.sqf:89,92,266`, and action icons still write through `updateavailableactions.fsm:225,228,230`. | Same shared key. Stable and B74 Vanilla use `GUI_EndOfGameStats.sqf:13,34-44,86-93`; B69/B74 Chernarus drift to `:15,36-46,88-95` because of unrelated GUER-label work. | These refs fix the EASA dialog IDD but do not fix title-IDD or title-handle ownership. Checked B69..B74 title-handle deltas are empty, and `origin/master..B74` changes only unrelated Chernarus endgame-label / vehicle-tint title content among checked paths. |
| Miksuu `b8389e748243` and perf `0076040f` | Same as docs/source in both maintained roots. | Same as docs/source. | No upstream/perf rescue for either title IDD or title handle ownership. |
| Historical release evidence `a96fdda2` | Same in both maintained roots; title refs match stable for checked title anchors and the RHUD display refresh call is at `Client_UpdateRHUD.sqf:258`. | Same in both maintained roots. | Release fixes the EASA dialog IDD but still carries duplicate title IDD and the handle collision. |

Repair this with a display-variable split before or alongside any title-display work: for example `currentActionHudDisplay` for `OptionsAvailable` and `currentEndgameStatsDisplay` for `EndOfGameStats`, or a helper that takes the key name explicitly. Keep this separate from the `idd` uniqueness pass so smoke failures can be traced cleanly.

## Why It Is A Risk

In Arma 2 OA UI terms, duplicated `idd` makes `findDisplay 23000` or `findDisplay 10200` ambiguous when more than one matching display can exist or when future code assumes uniqueness.

The dialog collision is more actionable because EASA and Economy both sit near the same control ID range:

- `GUI_Menu_EASA.sqf:7` uses listbox control `23003`.
- `GUI_Menu_Economy.sqf:3` receives a display handle and uses `DisplayCtrl 23002`.

Current normal flow reduces the chance of an immediate player-visible bug:

- `GUI_Menu.sqf:171` closes the previous dialog before opening Economy.
- `GUI_Menu_Service.sqf:243` closes the previous dialog before opening EASA.

The title IDD collision is less likely to break creation because `cutRsc` addresses resources by class/layer, but it can still confuse ID-based debug, `findDisplay`, or future display-control lookup. The `currentCutDisplay` collision is more direct: two unrelated title resources write through the same stored handle, so unloading or recreating one title can make another title's controller read the wrong display.

## Patch Shape

Keep the first patch small:

1. Assign a new unique `idd` to one of `RscMenu_EASA` or `RscMenu_Economy`.
2. Re-run the current no-`findDisplay 23000/24000/10200` grep before patching and keep it clean after the change.
3. Keep existing `idc` values unless a specific control collision is proven after the dialog ID change.
4. Assign a distinct `idd` to either `RscOverlay` or `OptionsAvailable`; release Chernarus did not already solve this title-resource collision.
5. Keep title IDD cleanup separate from title display-variable cleanup.
6. Split title display handles so `OptionsAvailable`/RHUD/action icons and `EndOfGameStats` do not share `currentCutDisplay`. Either add separate helper scripts/keys or make the helper accept the key name explicitly.
7. Before reviving or deleting stale resource classes, check script targets and assets as well as IDs. The active upgrade dialog on master is `WFBE_UpgradeMenu` (`Dialogs.hpp:4`, `idd = 504000`); its script `Client/GUI/GUI_UpgradeMenu.sqf` exists. No class named `RscMenu_Upgrade` exists in master `Dialogs.hpp`, `GUI_Menu_Upgrade.sqf` does not exist in the mission tree, and `Dialogs.hpp:2425-2428` / `:2634-2821` contain unrelated controls (`CA_SupportCost_Label`, `CA_HealAll_Button`). If a stale-class example is needed, verify it against the target branch before documenting it here.
8. If the minimal patch instead gates RHUD/action-icon recreation during endgame, still avoid making endgame stat rendering depend on an action-HUD-owned key.

Do not combine this with EASA balance generation or Economy authority changes. This is resource hygiene and future-proofing.

## Generated And Modded Copies

The same collisions are present in generated Vanilla Takistan and old modded mission copies. Patch source Chernarus first, propagate or manually sync maintained Vanilla with `Tools/LoadoutManager` as appropriate for the branch, and treat modded copies as a separate maintenance decision.

## Validation

Source-only:

- `RscMenu_EASA` and `RscMenu_Economy` have distinct `idd` values.
- `RscOverlay` and `OptionsAvailable` have distinct `idd` values.
- `OptionsAvailable`/RHUD/action icons and `EndOfGameStats` no longer set/clear the same `uiNamespace` display key.
- No `findDisplay 23000` / `findDisplay 24000` / `findDisplay 10200` source references are introduced, or any deliberate hard-coded display lookup is updated to the new unique IDs and documented.

Arma smoke:

- EASA opens from service menu and applies/returns as before.
- Economy opens from main menu and income/sell/supply-truck controls still render.
- RHUD/FPS HUD still appears and updates.
- Action availability icons still appear.
- Endgame stat bars populate after match end with RHUD/FPS toggled on and off.
- Unloading endgame stats does not clear the action/RHUD display handle unless endgame intentionally disables that surface.
- No title resource flicker/regression during map/menu transitions.

## Continue Reading

Previous: [Client UI systems atlas](Client-UI-Systems-Atlas) | Next: [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
