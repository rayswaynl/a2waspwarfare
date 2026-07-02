# Construction System QA - 2026-07-02

Lane: `fleet-lane-62-construction-system-qa-2026-07-02`
Branch: `codex/62-construction-system-qa`
Base checked: `origin/claude/build84-cmdcon36@24604e9f7`
Scope: documentation-only QA of the commander construction flow, including CoIn placement, `RequestStructure`, `RequestDefense`, construction scripts, auto-wall handling, repair/recycle adjacency, and visible commander/player feedback.

## Summary

The current construction surface is mostly in a better state than the older audit notes imply. Several stale issues are already fixed on `claude/build84-cmdcon36`: invalid structure ids no longer index `-1`, bank validation no longer uses `exitWith` inside a nested `then`, SmallSite no longer double-appends old site logic, deployed HQ walls are cleaned on kill, and core construction files match between Chernarus and Takistan.

One player-facing reliability gap remains: normal structure purchases debit supply/funds on the client before the server can reject CBRadar or Bank placement. The server has clear rejection branches for those structure types, but `RequestStructure` receives no requester/cost context and has no refund path, unlike `RequestDefense`.

## Findings

| ID | Severity | Finding | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| CON-QA-01 | P2 | Structure purchases can debit supply/funds before a server-side CBRadar or Bank rejection, with no refund path. | `Client\Module\CoIn\coin_interface.sqf:668-676` charges side supply or player funds before `RequestStructure` is sent at `coin_interface.sqf:719`. `Server\PVFunctions\RequestStructure.sqf:24-38` can reject CBRadar when no alive AAR exists, and `RequestStructure.sqf:40-80` can reject Bank placement for already-built, pending, or too-close-to-base cases. Accepted builds only execute after the `_reject` gate at `RequestStructure.sqf:82-86`; the request payload has only side/class/pos/dir, so the server cannot refund the original payer. | Move structure payment to a server-accepted path, or thread requester/currency/price through `RequestStructure` and refund rejected CBRadar/Bank attempts. Mirror the `RequestDefense` refund pattern while coordinating with PR #278's broader authority-guard work. |
| CON-QA-02 | P3 | Rejected CBRadar/Bank structure requests still emit `building-started` feedback first. | `Server\PVFunctions\RequestStructure.sqf:16-18` broadcasts `building-started` for recognized structure types before the CBRadar and Bank rejection gates at `RequestStructure.sqf:24-80`. A denied Bank/CBRadar attempt can therefore flash a build-started marker/message even when no construction script runs. | Move the `building-started` broadcast below the `_reject` gate so it only fires for accepted structure builds. |

## Verified Non-Findings

- `RequestStructure` now guards invalid structure classes before reading structure metadata: `Server\PVFunctions\RequestStructure.sqf:8-12`.
- The older Bank `exitWith`-inside-validation issue is gone; current code uses `_reject` and only starts construction through the final accept gate: `Server\PVFunctions\RequestStructure.sqf:40-86`.
- Defense placement already passes requester context from CoIn and refunds/alerts rejected budget or threat-gate attempts: `Client\Module\CoIn\coin_interface.sqf:724-729`, `Server\PVFunctions\RequestDefense.sqf:243-279`.
- Site clearance is charged server-side only after gates pass and trees are actually felled: `Server\Functions\Server_SiteClearance.sqf:30-147`, `Server\Functions\Server_SiteClearance.sqf:152-161`.
- `Construction_SmallSite.sqf` no longer uses the stale `+` append when retiring the temporary site logic; the current mode-1 cleanup removes the logic from the per-side site list.
- Stationary defenses reject invalid build positions and have the no-Barracks fallback for manning through HQ/global defense groups: `Server\Construction\Construction_StationaryDefense.sqf:14-23`, `Server\Construction\Construction_StationaryDefense.sqf:96-151`.
- Deployed HQ walls are removed both on mobilize and deployed-HQ destruction: `Server\Construction\Construction_HQSite.sqf:73-74`, `Server\Functions\Server_OnHQKilled.sqf:42-45`.
- The repaired/mobile HQ killed-event-handler casing fix is present in both HQ construction and MHQ repair paths: `Server\Construction\Construction_HQSite.sqf:102-104`, `Server\Functions\Server_MHQRepair.sqf:42-43`.
- Real-base-assault damage handling is already enabled by default through `WFBE_C_STRUCTURES_ENEMY_DESTROYABLE`: `Server\Functions\Server_BuildingHandleDamages.sqf:14-30`, `Server\Functions\Server_HandleBuildingDamage.sqf:6-16`.
- Auto-wall state is per-side for construction and side-wide HUD sync, with the legacy global kept only as compatibility state: `Server\PVFunctions\RequestAutoWallConstructinChange.sqf:6-11`, `Server\Construction\Construction_SmallSite.sqf:123-140`, `Server\Construction\Construction_MediumSite.sqf:168-185`.
- GUER FOB/structure registry cleanup is present in building kill handling: `Server\Functions\Server_BuildingKilled.sqf:160-168`.
- The flatness check remains disabled by parameter/default design because it overblocked Takistan terrain; that placement-parity policy belongs to lane 46, not this lane.

## Map Parity Check

All audited construction-adjacent files had matching SHA-256 hashes between:

- `Missions\[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan`

Checked files included:

- `Client\Module\CoIn\coin_interface.sqf`
- `Client\Init\Init_BaseStructure.sqf`
- `Server\PVFunctions\RequestStructure.sqf`
- `Server\PVFunctions\RequestDefense.sqf`
- `Server\PVFunctions\RequestAutoWallConstructinChange.sqf`
- `Server\PVFunctions\RequestSiteClearance.sqf`
- `Server\Construction\Construction_SmallSite.sqf`
- `Server\Construction\Construction_MediumSite.sqf`
- `Server\Construction\Construction_HQSite.sqf`
- `Server\Construction\Construction_StationaryDefense.sqf`
- `Server\Functions\Server_CreateDefenseTemplate.sqf`
- `Server\Functions\Server_ConstructPosition.sqf`
- `Server\Functions\Server_SiteClearance.sqf`
- `Server\Functions\Server_BuildingKilled.sqf`
- `Server\Functions\Server_BuildingHandleDamages.sqf`
- `Server\Functions\Server_HandleBuildingDamage.sqf`
- `Server\Functions\Server_OnHQKilled.sqf`
- `Server\Functions\Server_MHQRepair.sqf`

## Out Of Scope

- PR #278 already owns broad PVF authority guard work for `RequestStructure`, `RequestDefense`, and `RequestMHQRepair`; this report only flags the structure refund/feedback behavior observable in the current construction path.
- PR #283 and adjacent structure-parity work own Reserve/ArtilleryRadar source changes.
- Lane 46 owns deeper placement-parity and terrain/flatness policy decisions.
- No mission source files were changed in this lane, so `Tools\LoadoutManager\dotnet run` was intentionally not run.

## Suggested Smoke Checks

1. With economy Bank enabled, attempt to place a Bank inside own base protection range. Verify no supply/funds are lost and no build-started message/marker appears after the fix.
2. Attempt to build CBRadar before any alive AAR exists. Verify the player/side gets the localized rejection and no charge is kept.
3. Place a normal accepted structure, a defense rejected by budget/threat gate, and a Site Clearance action. Verify the three payment paths still behave independently.
