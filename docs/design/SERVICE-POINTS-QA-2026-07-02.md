# Service Points QA - 2026-07-02

Lane: 60
Branch: codex/lane60-service-points-qa
Base: claude/build84-cmdcon36 @ 24604e9f74a1f67b23727748327fc2f35c8aecf6

## Verdict

The player service module is mostly coherent across base service points, repair trucks, depots, and repair-truck-built service-point statics. This sweep fixed one availability gap: repair-truck-built service-point statics were accepted by the service menu, but did not enable the service action/icon when no base service point, repair truck, or depot was also nearby.

## Source Map

| Area | Evidence |
| --- | --- |
| Support ranges | `Common/Init/Init_CommonConstants.sqf:1369`, `Common/Init/Init_CommonConstants.sqf:1457` |
| Action availability | `Client/FSM/updateavailableactions.fsm:180-201`, `Client/FSM/updateavailableactions.fsm:228` |
| Repair-truck service-point stamping | `Server/Construction/Construction_StationaryDefense.sqf:37-38` |
| Repair-truck service-point lookup | `Client/Functions/Client_GetRepairTruckServicePoints.sqf:11-14`, `Client/Functions/Client_CanUseRepairPointEASA.sqf:15` |
| Service menu providers | `Client/GUI/GUI_Menu_Service.sqf:233`, `Client/GUI/GUI_Menu_Service.sqf:248`, `Client/GUI/GUI_Menu_Service.sqf:288-313` |
| Service menu actions | `Client/GUI/GUI_Menu_Service.sqf:404-465`, `Client/GUI/GUI_Menu_Service.sqf:483-524`, `Client/GUI/GUI_Menu_Service.sqf:537-560` |
| Repair primitive | `Client/Functions/Client_SupportRepair.sqf:60-83` |
| Rearm primitive | `Client/Functions/Client_SupportRearm.sqf:69-87` |
| Refuel primitive | `Client/Functions/Client_SupportRefuel.sqf:61-79` |
| Heal primitive | `Client/Functions/Client_SupportHeal.sqf:61-82` |
| AICOM self-service | `Common/Init/Init_CommonConstants.sqf:998-1006`, `Common/Functions/Common_AICOMServiceTick.sqf:72-94` |

## Findings

### Fixed In This PR

Repair-truck-built service-point statics are created as `Base_WarfareBVehicleServicePoint` objects and stamped with `WFBE_RepairTruckServicePoint`. `GUI_Menu_Service.sqf` already includes those statics in its effective service-provider list, so the menu can service a vehicle through them.

`updateavailableactions.fsm` did not run the matching static lookup. That meant the service action could stay hidden when a player was near one of these statics after the builder truck moved away. The Chernarus and Takistan FSMs now run a narrow `nearestObjects` scan for stamped service-point statics before falling through to the rest of the availability checks.

### Routed Elsewhere

Paid repair still uses `_veh setDammage 0` in `Client_SupportRepair.sqf`. Component hitpoint reset work overlaps open PR #256, so this sweep documents the behavior but does not duplicate that lane.

### Follow-Up Candidates

Service actions debit locally before the delayed service primitive completes. If the support source moves, dies, or falls out of range during the timer, the action can fail after payment. A refund or server-authoritative accounting pass would be broader than this lane.

The player service primitives remain client-side effects. A larger authority pass would need coordinated server validation for funds, range, ownership, and service success.

### Existing GUI Findings From The Prior Report

The earlier docs-only pass found that single-unit service actions rely on button enable state for context and do not re-check that context at action time before debit/spawn. A stale menu action or fast state change can therefore debit the player, then the worker can fail because the vehicle/support is no longer valid. The relevant action handlers are in `GUI_Menu_Service.sqf:483-524`, while worker failure paths are in `Client_SupportRearm.sqf:69-87`, `Client_SupportRepair.sqf:60-83`, `Client_SupportRefuel.sqf:61-79`, and `Client_SupportHeal.sqf:61-82`.

The same pass found that rearm/refuel can queue zero-price single-action workers if invoked through a stale action branch. Repair/heal already require positive prices in the action handlers, but rearm/refuel only check that current funds cover the computed price.

Batch and full-service helpers already re-read funds before debit, and support worker scripts do not change funds. `Client_SupportRefuel.sqf` also already uses a stopped default, avoiding the old unset-variable condition trap.

Those GUI findings are preserved here as follow-up work for the GUI owner lane. This PR does not edit `GUI_Menu_Service.sqf`.

## Runtime Smoke Checklist

1. Build a base service point. Verify the service action appears, the menu lists the nearby vehicle/player, and single, all, and full actions still work.
2. Build a service-point static from a repair truck. Drive the truck away, stand near the static, and verify the service action/menu still appears and repair, rearm, refuel, and heal work.
3. Test depot service for land vehicles. Verify air rearm remains blocked at depots.
4. Start repair-truck service, then move the support source or target out of range during the timer. Verify the action fails cleanly with no script crash.
5. Test aircraft EASA from a base service point and from a repair-truck service-point static.
6. Repair a damaged wheeled or tracked vehicle and re-check component hitpoint behavior after PR #256 lands.
7. Repeat the smoke on Takistan.

## Guardrails

No live deploy or mission package was produced. This PR does not rewrite service authority, refund logic, EASA pricing, AICOM self-service, or the PR #256 component-hitpoint repair work.
