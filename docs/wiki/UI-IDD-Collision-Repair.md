# UI IDD Collision Repair

Status: confirmed UI/resource risk, patch-ready. This page owns the exact source evidence and safe repair plan for duplicated `idd` values in dialogs and title resources.

Combined UI cleanup route: [UI resource parity cleanup](UI-Resource-Parity-Cleanup) is the canonical matrix for stale `RscMenu_Upgrade`, Economy missing-control writes and duplicate IDDs. Use this page for the duplicate-IDD patch details after that matrix tells you which branch/root still needs work.

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

Branch check 2026-06-05: current source, `origin/master` and `miksuu/master` keep both collision groups in Chernarus and maintained Vanilla. `origin/release/2026-06-feature-bundle` changes Chernarus `RscMenu_EASA` to `idd = 24000`, leaving Chernarus Economy at `23000`, but release Vanilla still keeps both EASA and Economy on `23000`. The `RscOverlay` / `OptionsAvailable` title collision on `10200` is still present in both release roots. Current mission source has no hard-coded `findDisplay 23000` or `findDisplay 10200` caller in `Missions` / `Missions_Vanilla`, so this remains a maintenance/debug/future-control risk rather than a proven live lookup bug.

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

Release-branch caveat: `origin/release/2026-06-feature-bundle` already moves Chernarus EASA to `idd = 24000` (`Dialogs.hpp:2860-2863`), but maintained Vanilla on that branch still has EASA/Economy both on `23000` (`Dialogs.hpp:3294-3296`, `:3372-3374`). Treat the Chernarus release shape as a useful comparison point, not as proof the cleanup is complete.

Two title resources share `idd = 10200`:

| Resource | Evidence | Runtime owner |
| --- | --- | --- |
| `RscOverlay` | `Rsc/Titles.hpp:44-46` | Started from `Client/Init/Init_Client.sqf:149` on cutRsc channel 1365. |
| `OptionsAvailable` | `Rsc/Titles.hpp:164-165` | Started from `Client/FSM/updateavailableactions.fsm:62` and `Client/Client_UpdateRHUD.sqf:7`. |

There is no standalone `Client/RHUD` subtree in the current source. RHUD is folded into `OptionsAvailable` plus `Client/Client_UpdateRHUD.sqf`, so title-ID repair must preserve that display-owner relationship.

Wave Q added a separate title lifecycle-handle ownership finding. `EndOfGameStats` uses `idd = 90000` (`Rsc/Titles.hpp:532-533`), but it shares the same `onLoad`/`onUnload` helper scripts and therefore the same `uiNamespace["currentCutDisplay"]` key as `OptionsAvailable` (`Titles.hpp:539-540`). `Client/GUI/GUI_EndOfGameStats.sqf:13` cuts `EndOfGameStats`, then waits for and writes controls through `currentCutDisplay` at `:34-44` and `:86-93`. Meanwhile `Client/Client_UpdateRHUD.sqf:183-190` keeps its one-second loop alive and `_RHUDGetDisplay` can re-cut `OptionsAvailable` when the shared key is null (`:89-92`). This is a lifecycle handle collision even if all `idd` values are made unique.

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
2. Re-run the current no-`findDisplay 23000/10200` grep before patching and keep it clean after the change.
3. Keep existing `idc` values unless a specific control collision is proven after the dialog ID change.
4. Assign a distinct `idd` to either `RscOverlay` or `OptionsAvailable`; release Chernarus did not already solve this title-resource collision.
5. Keep title IDD cleanup separate from title display-variable cleanup.
6. Split title display handles so `OptionsAvailable`/RHUD/action icons and `EndOfGameStats` do not share `currentCutDisplay`. Either add separate helper scripts/keys or make the helper accept the key name explicitly.
7. Before reviving or deleting stale resource classes, check script targets and assets as well as IDs. Current source example: `RscMenu_Upgrade` points at missing `Client/GUI/GUI_Menu_Upgrade.sqf` and missing `Client\Images\wf_*.paa` upgrade icons (`Dialogs.hpp:2425-2428`, `:2634-2821`).
7. If the minimal patch instead gates RHUD/action-icon recreation during endgame, still avoid making endgame stat rendering depend on an action-HUD-owned key.

Do not combine this with EASA balance generation or Economy authority changes. This is resource hygiene and future-proofing.

## Generated And Modded Copies

The same collisions are present in generated Vanilla Takistan and old modded mission copies. Patch source Chernarus first, propagate or manually sync maintained Vanilla with `Tools/LoadoutManager` as appropriate for the branch, and treat modded copies as a separate maintenance decision.

## Validation

Source-only:

- `RscMenu_EASA` and `RscMenu_Economy` have distinct `idd` values.
- `RscOverlay` and `OptionsAvailable` have distinct `idd` values.
- `OptionsAvailable`/RHUD/action icons and `EndOfGameStats` no longer set/clear the same `uiNamespace` display key.
- No `findDisplay 23000` / `findDisplay 10200` source references are introduced, or any deliberate hard-coded display lookup is updated to the new unique IDs and documented.

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
