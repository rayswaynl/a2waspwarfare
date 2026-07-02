# Artillery Module QA - 2026-07-02

Lane: 58, player artillery module QA
Base checked: `origin/claude/build84-cmdcon36@6f2fc4bd1`
Scope: docs-only audit of the player fire-mission path. No mission source was changed in this lane because the main user-facing fixes touch the tactical GUI, which is currently on the fleet avoid-list, and the one server-side cleanup candidate should be tested as a focused source lane.

## Summary

Player artillery is still driven by the Warfare tactical menu rather than the engine artillery computer. The client compiles `RequestFireMission` at `Client/Init/Init_Client.sqf:128`, initializes `fireMissionTime` and `artyRange` at `Client/Init/Init_Client.sqf:500-501`, disables the engine artillery UI at `Client/Init/Init_Client.sqf:564`, and only starts the BIS artillery command UI when `WFBE_C_ARTILLERY_UI > 0` at `Client/Init/Init_Client.sqf:1118`.

The dedicated parameter enables artillery by default in medium range mode: `Rsc/Parameters.hpp:65-75`. The SQF fallback remains enabled/short at `Common/Init/Init_CommonConstants.sqf:1061-1062`, the maximum marker radius is `300` at `Init_CommonConstants.sqf:1065`, and normal mission cooldowns are `[550,500,450,400,350,300,250]` at `Init_CommonConstants.sqf:1071`. Autonomous AI commander artillery is hard-locked off at `Init_CommonConstants.sqf:488`; this report covers player-requested fire missions only.

## Findings

| ID | Severity | Finding | Evidence | Recommended follow-up |
| --- | --- | --- | --- | --- |
| ARTY-QA-01 | P2 | Fire missions can leave an artillery piece restricted on validation or mid-mission abort paths. The out-of-range path now calls `ARTY_Finish` and clears `restricted`, but other exits are not symmetrical. | `Common/Functions/Common_FireArtillery.sqf:7` sets `restricted=true` before the invalid-type/null-gunner/player-gunner exits at lines `12-14`. The out-of-range exit cleans up at lines `42-44`. The dead-gunner exit at lines `73-76` removes fired handlers but does not call `ARTY_Finish` or clear `restricted`; the dead-artillery exit at lines `79-80` only re-enables gunner AI when possible. Normal completion calls `ARTY_Finish` and clears `restricted` at lines `101-104`. | In a source lane, add one local cleanup path used by every exit after `restricted=true`. Use `ARTY_Finish` only after `ARTY_Prep` has run. Keep the patch small, mirror Chernarus to Takistan with LoadoutManager, and smoke with invalid-gunner plus gunner/vehicle death during countdown. |
| ARTY-QA-02 | P3 | Fire mission radius is passed into `Client_RequestFireMission.sqf` but the actual firing call reads the mutable global `artyRange`. | The caller freezes the selected radius in the spawn payload at `Client/GUI/GUI_Menu_Tactical.sqf:757`. `Client/Functions/Client_RequestFireMission.sqf:7` reads `_arty_radius`, uses it for marker radius at line `28`, but line `15` passes global `artyRange` into `WFBE_CO_FNC_FireArtillery`. | Replace the line-15 `artyRange` argument with `_arty_radius` in a tiny source lane. This avoids drift if the global changes while the spawned request is running and makes tests easier to reason about. |
| ARTY-QA-03 | P3 | The visible cooldown can start even if the spawned request exits before firing. | The tactical menu sets `fireMissionTime = time` before spawning the request at `GUI_Menu_Tactical.sqf:756-757`. `Client_RequestFireMission.sqf:9-12` can still exit if no artillery units or no valid artillery type remain. The HUD suffix reads only the client-local `fireMissionTime` at `Client/Client_UpdateRHUD.sqf:259-280` and renders it onto the base row at line `506`. | When the GUI lane is free, move or confirm cooldown state after request validation, or reset it on early request exit. Preserve the existing local-HUD behavior unless a broader server-authority design is chosen. |
| ARTY-QA-04 | P3 | The "focus selected cannon" action can index the tracking list with an invalid row. | `GUI_Menu_Tactical.sqf:886-890` uses `getPos(_trackingArray select (lnbCurSelRow 17024))` without guarding for `-1` or an empty/stale `_trackingArray`. | In the GUI owner lane, guard the selected row before indexing and no-op when there is no selected artillery row. |

## Verified Non-Findings

- Global artillery marker cleanup is server-routed. `Client_RequestFireMission.sqf:38` sends `ArtyMarkerCleanup`, and `Server/Functions/Server_HandleSpecial.sqf:190` handles the cleanup, so marker deletion is not tied to the requesting client staying connected.
- Fire-mission chat output is structured message data, not a compile-built command path. This pass did not find a replay of the old message-injection issue in `Client_RequestFireMission.sqf`.
- Commander-built artillery discovery is intentionally limited. `Common_GetTeamArtillery.sqf:46-74` only scans commander-owned artillery for the commander team, within side command areas, and still requires non-player gunners and ammo through the same add path at lines `26-35`.
- The standalone `RUBHUD_Arty` controls still exist in `Rsc/Titles.hpp:207,508-519`, but the active HUD path now folds artillery status into the base row at `Client/Client_UpdateRHUD.sqf:506`. This is legacy layout surface, not a live display bug by itself.
- Out-of-range fire mission cleanup is already fixed on this base. `Common_FireArtillery.sqf:42-44` calls `ARTY_Finish` and clears `restricted` before returning.

## Suggested Source Shape

Prioritize the cleanup bug first:

1. Add a small local cleanup helper or repeated cleanup block in `Common_FireArtillery.sqf` for exits after `restricted=true`.
2. Ensure fired event handlers are removed when they may have been registered.
3. Call `ARTY_Finish` only after prep has run, then clear `restricted`.
4. For pre-prep validation exits, clear `restricted` without calling `ARTY_Finish`.
5. Mirror Chernarus to Takistan with `Tools\LoadoutManager\dotnet run -c Release` and remove generated archive artifacts.

The radius argument fix is safe to batch with the cleanup lane if the same owner is already touching artillery fire code. The cooldown and selected-row guards should wait for the tactical GUI lane to clear.

## Verification

- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only QA lane.
- The report was prepared against `origin/claude/build84-cmdcon36@6f2fc4bd1`.
