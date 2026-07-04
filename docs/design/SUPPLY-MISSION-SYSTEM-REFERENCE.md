# Supply Mission System Reference

Lane 310 source-side reference for the Build84 target branch
`claude/build84-cmdcon36` (`a26871e852470b86b68c2f4f58eb44b436d076d6`).
This is documentation only: no mission runtime behavior, constants, package
files, or generated terrain output are changed.

## Scope

The supply mission subsystem lets SpecOps players load supplies from friendly
towns and deliver them to a Command Center by truck or, after Air research,
helicopter. The current Build84 implementation lives under
`Client/Module/supplyMission/` and `Server/Module/supplyMission/`; prompt text
that says `Server/FSM/` is stale for this target.

| Area | Current source anchor | Role |
| --- | --- | --- |
| SpecOps actions | `Client/Module/Skill/Skill_Apply.sqf:49-70` | Adds `LOAD SUPPLIES` and heli `UNLOAD SUPPLIES` actions only to SpecOps. |
| Client start gate | `Client/Module/supplyMission/supplyMissionStart.sqf:6-89` | Checks cooldown, target type, Supply Rate, Air level, load locks, load distance and heli load timer. |
| Client heli unload | `Client/Module/supplyMission/supplyMissionUnload.sqf:1-71` | Resolves a loaded supply helicopter, checks Command Center range, runs the unload timer and signals completion. |
| Server start loop | `Server/Module/supplyMission/supplyMissionStarted.sqf:1-104` | Stamps cooldown, attaches interdiction handling, watches delivery proximity and auto-completes truck runs. |
| Server completion | `Server/Module/supplyMission/supplyMissionCompleted.sqf:2-58` | Validates non-empty vehicle vars, records stats, pays side supply or commander cash-run funds and sends the client message. |
| Cooldown query | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:1-19` | Answers client cooldown pulls from `LastSupplyMissionRun`. |
| Cooldown expiry | `Server/Module/supplyMission/supplyMissionTimerForTown.sqf:1-10` | Clears `supplyMissionCoolDownEnabled` after 1800 seconds. |
| Player object lookup | `Server/Module/supplyMission/playerObjectsList.sqf:1-30` | Maintains UID to player-object rows used by truck delivery attribution. |
| Marker/status client | `Client/Module/supplyMission/townSupplyStatus.sqf:1-8` and `Client/FSM/updatetownmarkers.sqf:42-70` | Stores cooldown state locally and renders `[+SUPPLY]` or `[MM:SS]` town marker text. |

## Constants And Gates

| Constant or index | Value on Build84 | Source |
| --- | --- | --- |
| `WFBE_UP_AIR` | `3` | `Common/Init/Init_CommonConstants.sqf:40` |
| `WFBE_UP_SUPPLYRATE` | `6` | `Common/Init/Init_CommonConstants.sqf:43` |
| `WFBE_CO_VAR_SupplyMissionRegenInterval` | `1800` seconds | `Common/Init/Init_Common.sqf:222` |
| `WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER` | `20` | `Common/Init/Init_CommonConstants.sqf:1280` |
| `WFBE_C_SUPPLY_HELI_REWARD_MULT` | `1.25` | `Common/Init/Init_CommonConstants.sqf:1282` |
| `WFBE_C_SUPPLY_CASHRUN_COMMANDER_CUT` | `0.20` | `Common/Init/Init_CommonConstants.sqf:1283` |
| `WFBE_C_SUPPLY_INTERDICTION_CUT` | `0.25` | `Common/Init/Init_CommonConstants.sqf:1284` |
| `WFBE_C_SUPPLY_HELI_LOAD_TIME` | `15` seconds | `Common/Init/Init_CommonConstants.sqf:1285` |
| `WFBE_C_SUPPLY_HELI_UNLOAD_TIME` | `15` seconds | `Common/Init/Init_CommonConstants.sqf:1286` |
| `WFBE_SUPPLY_MISSION_SCORE_COEF` | `1.5` | `Common/Init/Init_CommonConstants.sqf:1306` |

Vehicle classes are centralized on Build84:

| Class set | Current contents | Source |
| --- | --- | --- |
| `WFBE_C_SUPPLY_TRUCK_TYPES` | `WarfareSupplyTruck_RU`, `WarfareSupplyTruck_USMC`, `WarfareSupplyTruck_INS`, `WarfareSupplyTruck_Gue`, `WarfareSupplyTruck_CDF`, `UralSupply_TK_EP1`, `MtvrSupply_DES_EP1` | `Common/Init/Init_CommonConstants.sqf:1288` |
| `WFBE_C_SUPPLY_HELI_TYPES` | Chernarus: `MH60S`, `Mi17_Ins`; non-Chernarus: `UH60M_EP1`, `Mi17_TK_EP1`; emptied if `WFBE_C_SUPPLY_HELI_ENABLED != 1` | `Common/Init/Init_CommonConstants.sqf:1290-1292` |
| `WFBE_C_SUPPLY_VEHICLE_TYPES` | Trucks plus enabled helis | `Common/Init/Init_CommonConstants.sqf:1293` |

## Runtime Flow

1. SpecOps receives `LOAD SUPPLIES` and `UNLOAD SUPPLIES` actions from
   `Skill_Apply.sqf:49-70`. The load action requires the player to be on foot,
   near the closest friendly town, targeting an unloaded supply truck or a
   supply helicopter after Air level 3.
2. `supplyMissionStart.sqf:6-9` asks the server for the town cooldown and reads
   the client-local `supplyMissionCoolDownEnabled` cache. This is an affordance
   gate, not a fully server-owned accept/reject decision.
3. The start script checks `cursorTarget` type against
   `WFBE_C_SUPPLY_TRUCK_TYPES` and `WFBE_C_SUPPLY_HELI_TYPES`
   (`supplyMissionStart.sqf:20-44`). Trucks are always eligible; helicopters
   require Air level 3 (`supplyMissionStart.sqf:28-47`).
4. For accepted loads, the client writes `SupplyFromTown`, `SupplyByHeli`,
   `SupplyAmount` and `SupplyLoading` on the vehicle, then publishes
   `WFBE_Client_PV_SupplyMissionStarted` (`supplyMissionStart.sqf:76-89`).
5. The server start handler stamps `LastSupplyMissionRun` on the source town,
   broadcasts it for marker countdowns, attaches one guarded `Killed` handler
   for interdiction, starts the cooldown timer and polls the vehicle
   (`supplyMissionStarted.sqf:12-48`).
6. Truck delivery auto-completes when the vehicle reaches a typed
   `Base_WarfareBUAVterminal` scan within 80 m. Helicopter runs use the same
   terminal class with a 400 m search and 2D 80 m horizontal qualification, but
   wait for the client `UNLOAD SUPPLIES` action (`supplyMissionStarted.sqf:55-104`
   and `supplyMissionUnload.sqf:38-71`).
7. `supplyMissionCompleted.sqf:14-24` ignores completions with missing source
   town or non-positive cargo, then records supply-run stats when a player UID
   is available.
8. Non-cash-run deliveries call `ChangeSideSupply` for the side pool
   (`supplyMissionCompleted.sqf:47-49`). Air level 4 heli deliveries become
   cash runs: the commander team receives a minted tithe, or the supply falls
   back to the side pool when no commander exists (`supplyMissionCompleted.sqf:36-46`).
9. The vehicle state is cleared after accepted completion:
   `SupplyAmount = 0`, `SupplyFromTown = objNull`, `SupplyByHeli = false`,
   `SupplyLoading = false` (`supplyMissionCompleted.sqf:50-53`).
10. The client completion message pays the delivering player, applies the heli
    1.25 reward multiplier and requests score gain
    (`supplyMissionCompletedMessage.sqf:14-32`).

## Player And UI Surfaces

| Surface | Build84 behavior | Source |
| --- | --- | --- |
| Town marker text | SpecOps sees `SV: current/max [+SUPPLY]` when ready and a `[MM:SS]` countdown while cooling down; other classes see `SV: current/max [+]` or plain SV text. | `Client/FSM/updatetownmarkers.sqf:42-70` |
| Supply-ready sound | SpecOps hears `ARTY_cooldown_over` when a tracked town flips from cooldown to ready. | `Client/FSM/updatetownmarkers.sqf:44-52` |
| JIP/player init | Client publishes `WFBE_C_PLAYER_OBJECT` and pulls cooldown state for all towns after player init. | `Client/Init/Init_Client.sqf:1329-1340` |
| Buy menu highlighting | Supply helis are tinted orange like other supply vehicles. | `Client/Functions/Client_UIFillListBuyUnits.sqf:155-160` |
| Buy menu explainer | Selecting a supply heli explains Air level 3, Air level 4 cash runs, pilot reward and interdiction. | `Client/GUI/GUI_Menu_BuyUnits.sqf:770-772` |
| QOL advisor | Adds supply trucks plus supply helis to the supply delivery nudge vehicle set. | `Client/Functions/Client_QOL_Advisor.sqf:112-126` |

## Current Integrity Notes

Build84 has several important hardening pieces already present: `LastSupplyMissionRun`
is seeded with matching casing in `Common/Init/Init_Town.sqf:41-42`, the old
dead `supplyMissionActive.sqf` compile is explicitly removed in
`Server/Init/Init_Server.sqf:104-118`, the command-center scan is typed to
`Base_WarfareBUAVterminal`, and side-supply writes route through the guarded
`Server_ChangeSideSupply.sqf` clamp/validation path.

The remaining authority posture is still the one recorded by the wiki supply
pages: start cargo facts are client-stamped on the vehicle and later consumed by
the server completion handler. Future code work should keep server-owned cargo
state, duplicate-start handling, disconnect/player-object cleanup and repeated
load/deliver/destroy smoke separate from this reference lane.

## Verification Notes

- Source branch was based on `github/claude/build84-cmdcon36`.
- Existing source `docs/design` had no supply-mission system reference on the
  target branch.
- Existing wiki pages used as prior art: `Supply-Mission-Architecture.md`,
  `Supply-Mission-Player-Guide.md`, `Supply-Mission-Authority-Cleanup-Playbook.md`
  and `Supply-Mission-Scan-Narrowing.md`.
- This document intentionally did not run `Tools/LoadoutManager`; no generated
  Takistan/Zargabad output is needed for a docs-only source file.
