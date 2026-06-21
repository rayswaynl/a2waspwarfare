# Side Team State Function Reference

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

This page documents the shared side and team-state helpers compiled from `Common/Functions/`. Use it when a change touches side logic objects, side supply caches, group money, command-menu orders, AI respawn state, or side/team ID conversion.

## Function Registration

| Family | Registered names | Source |
| --- | --- | --- |
| Side/team money writers | `ChangeSideSupply`, `ChangeTeamFunds` | `Common/Init/Init_Common.sqf:19-20` |
| Legacy side readers | `GetSideFromID`, `GetSideID`, `GetSideSupply`, `GetSideUpgrades`, `GetSideTowns` | `Common/Init/Init_Common.sqf:40-44` |
| Legacy team readers | `GetTeamAutonomous`, `GetTeamFunds`, `GetTeamMoveMode`, `GetTeamMovePos`, `GetTeamRespawn`, `GetTeamType`, `GetTeamVehicles` | `Common/Init/Init_Common.sqf:52-58` |
| Legacy team writers | `SetTeamAutonomous`, `SetTeamRespawn`, `SetTeamMoveMode`, `SetTeamMovePos`, `SetTeamType` | `Common/Init/Init_Common.sqf:76-80` |
| Prefixed side readers | `WFBE_CO_FNC_GetSideFromID`, `WFBE_CO_FNC_GetSideHQDeployStatus`, `WFBE_CO_FNC_GetSideHQ`, `WFBE_CO_FNC_GetSideID`, `WFBE_CO_FNC_GetSideLogic`, `WFBE_CO_FNC_GetSideSupply`, `WFBE_CO_FNC_GetSideStructures`, `WFBE_CO_FNC_GetSideTowns`, `WFBE_CO_FNC_GetSideUpgrades` | `Common/Init/Init_Common.sqf:126-134` |
| Prefixed team money helpers | `WFBE_CO_FNC_ChangeTeamFunds`, `WFBE_CO_FNC_GetTeamFunds` | `Common/Init/Init_Common.sqf:99,135` |
| Server side-supply bridge | `WFBE_SE_FNC_ChangeSideSupply`, `WFBE_SE_PV_RequestSupplyValue` | `Server/Init/Init_Server.sqf:82,84` |
| Client side-supply reply bridge | `WFBE_CL_PV_ReceiveSupplyValue` | `Client/Init/Init_Client.sqf:140` |

## Side Identity And Logic Objects

| Helper | Contract | Source |
| --- | --- | --- |
| `GetSideID` / `WFBE_CO_FNC_GetSideID` | Maps `west`, `east`, `resistance`, and `civilian` to `WFBE_C_WEST_ID`, `WFBE_C_EAST_ID`, `WFBE_C_GUER_ID`, and `WFBE_C_CIV_ID`; any other input returns `-1`. | `Common/Functions/Common_GetSideID.sqf:7-13` |
| `GetSideFromID` / `WFBE_CO_FNC_GetSideFromID` | Maps `WFBE_C_*_ID` and legacy `WESTID` / `EASTID` / `RESISTANCEID` constants back to engine sides; unknown IDs return `sideLogic`. | `Common/Functions/Common_GetSideFromID.sqf:7-16` |
| `WFBE_CO_FNC_GetSideLogic` | Maps `west`, `east`, and `resistance` to `WFBE_L_BLU`, `WFBE_L_OPF`, and `WFBE_L_GUE`; other input returns `objNull`. | `Common/Functions/Common_GetSideLogic.sqf:7-12` |
| `WFBE_CO_FNC_GetSideHQ` | Reads `wfbe_hq` from the side logic object for west/east/resistance; other input returns `objNull`. | `Common/Functions/Common_GetSideHQ.sqf:7-12` |
| `WFBE_CO_FNC_GetSideHQDeployStatus` | Reads `wfbe_hq_deployed` from the side logic object for west/east/resistance; other input returns `objNull`. | `Common/Functions/Common_GetSideHQDeployStatus.sqf:7-12` |
| `WFBE_CO_FNC_GetSideStructures` | Reads `wfbe_structures` from the side logic object for west/east/resistance; other input returns `objNull`. | `Common/Functions/Common_GetSideStructures.sqf:7-12` |
| `GetSideTowns` / `WFBE_CO_FNC_GetSideTowns` | Converts the input side through `GetSideID`, then returns every object in global `towns` whose `sideID` variable matches that ID. | `Common/Functions/Common_GetSideTowns.sqf:3-10` |
| `GetSideUpgrades` / `WFBE_CO_FNC_GetSideUpgrades` | Reads `wfbe_upgrades` from the side logic object for west/east/resistance; other input returns `objNull`. | `Common/Functions/Common_GetSideUpgrades.sqf:7-12` |

The server seeds the side logic object with HQ, deploy state, structures, AI commander state, upgrades, upgrade queue, vote time, and other side-owned variables during side initialization. The core side-state writes are `wfbe_commander`, `wfbe_hq`, `wfbe_hq_deployed`, `wfbe_structures`, `wfbe_aicom_funds`, `wfbe_upgrades`, `wfbe_upgrading`, `wfbe_upgrading_id`, `wfbe_upgrade_queue`, and `wfbe_votetime`. `Server/Init/Init_Server.sqf:356-371`. When `WFBE_C_BASE_AREA > 0`, the server also initializes side-logic `wfbe_basearea`. `Server/Init/Init_Server.sqf:380-381`.

Side supply is not stored on the side logic object in current master. When currency mode uses supply, the server seeds `missionNamespace["wfbe_supply_%1"]` from `WFBE_C_ECONOMY_SUPPLY_START_%1`; the old side-logic `wfbe_supply` write is commented in both common and server side-supply helpers. `Server/Init/Init_Server.sqf:386`; `Common/Functions/Common_ChangeSideSupply.sqf:32`; `Server/Functions/Server_ChangeSideSupply.sqf:15,39`.

## Team Group State

Teams are Arma groups. Server initialization creates the durable group variables below for every present player group, and the setter helpers replicate their writes with `setVariable [..., true]`. `Server/Init/Init_Server.sqf:474-483`; `Common/Functions/Common_SetTeamAutonomous.sqf:8`; `Common/Functions/Common_SetTeamRespawn.sqf:8`; `Common/Functions/Common_SetTeamMoveMode.sqf:8`; `Common/Functions/Common_SetTeamMovePos.sqf:8`; `Common/Functions/Common_SetTeamType.sqf:8`.

| State key | Initial value | Getter fallback | Writer / behavior | Source |
| --- | --- | --- | --- | --- |
| `wfbe_funds` | `WFBE_C_ECONOMY_FUNDS_START_%1` if missing | Null or nil team funds return `0`. | `ChangeTeamFunds` adds the signed amount to the current `wfbe_funds` value and broadcasts the new value. | `Server/Init/Init_Server.sqf:474`; `Common/Functions/Common_GetTeamFunds.sqf:3-7`; `Common/Functions/Common_ChangeTeamFunds.sqf:3-8` |
| `wfbe_autonomous` | `false` | Null group returns `false`. | `SetTeamAutonomous` writes the boolean status and broadcasts it. | `Server/Init/Init_Server.sqf:479`; `Common/Functions/Common_GetTeamAutonomous.sqf:1-3`; `Common/Functions/Common_SetTeamAutonomous.sqf:3-8` |
| `wfbe_respawn` | Empty string | Null group returns `""`. | `SetTeamRespawn` writes a respawn target string/object and broadcasts it. | `Server/Init/Init_Server.sqf:480`; `Common/Functions/Common_GetTeamRespawn.sqf:1-3`; `Common/Functions/Common_SetTeamRespawn.sqf:3-8` |
| `wfbe_teamtype` | `-1` | Null group returns `0`. | `SetTeamType` writes the selected team type ID and broadcasts it. | `Server/Init/Init_Server.sqf:481`; `Common/Functions/Common_GetTeamType.sqf:1-3`; `Common/Functions/Common_SetTeamType.sqf:3-8` |
| `wfbe_teammode` | `"towns"` | Null group returns `"towns"`. | `SetTeamMoveMode` writes the command-menu movement mode and broadcasts it. | `Server/Init/Init_Server.sqf:482`; `Common/Functions/Common_GetTeamMoveMode.sqf:1-3`; `Common/Functions/Common_SetTeamMoveMode.sqf:3-8` |
| `wfbe_teamgoto` | `[0,0,0]` | Null group returns `[0,0,0]`. | `SetTeamMovePos` writes the command-menu movement target and broadcasts it. | `Server/Init/Init_Server.sqf:483`; `Common/Functions/Common_GetTeamMovePos.sqf:1-3`; `Common/Functions/Common_SetTeamMovePos.sqf:3-8` |

`GetTeamVehicles` is the larger team helper. Its call shape is `[_team, _canMove, _member?, _range?, _ignoreOwnerConflict?] Call GetTeamVehicles`; `_member` defaults to `objNull`, `_range` defaults to `150`, and `_ignoreOwnerConflict` defaults to `false`. The function scans `units _team`, collects each member's vehicle once, optionally removes immobile vehicles, optionally removes vehicles outside `_member`'s range, and removes vehicles carrying a player other than the team leader unless owner conflicts are ignored. `Common/Functions/Common_GetTeamVehicles.sqf:3-12,14-30`.

## Side Supply Flow

| Operation | Behavior | Source |
| --- | --- | --- |
| Read cached side supply | `GetSideSupply` reads `missionNamespace["wfbe_supply_%1"]` for west, east, or resistance. If the value is nil, it sets `REQUEST_SUPPLY_VALUE = player`, sends `publicVariableServer "REQUEST_SUPPLY_VALUE"`, waits until the side cache exists, then returns the cached value. Unknown side input returns `objNull`. | `Common/Functions/Common_GetSideSupply.sqf:9-18,23-31,36-49` |
| Server reply to missing cache | The server `REQUEST_SUPPLY_VALUE` handler derives the side from `side _player`, reads that side supply through `WFBE_CO_FNC_GetSideSupply`, then sends `SUPPLY_VALUE_REQUESTED` back to the player's owner. | `Server/Functions/Server_PV_RequestSupplyValue.sqf:1-8` |
| Client stores reply | The client `SUPPLY_VALUE_REQUESTED` handler writes the received value into `missionNamespace["wfbe_supply_%1"]` for `side player`. | `Client/Functions/Client_ReceiveSupplyValue.sqf:1-8` |
| Client startup wait | Client init waits until `missionNamespace["wfbe_supply_%1"]` exists for `sideJoinedText`, then copies that value into the legacy `wfbe_supply` variable. | `Client/Init/Init_Client.sqf:383-385` |
| Change side supply | `ChangeSideSupply` takes `[side, amount, reason?, includeStagnation?]`, optionally runs positive income through `WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers`, reads current supply, computes a local bounded `_change`, stores `[_side, _amount, _reason]` in `wfbe_supply_temp_<side>`, then sends that temp variable to the server. | `Common/Functions/Common_ChangeSideSupply.sqf:3-30` |
| Server apply/mirror | Current master registers west and east temp-channel handlers. Each handler reads `_side`, `_amount`, and `_reason` from the payload, computes the new supply value, writes `missionNamespace["wfbe_supply_%1"]`, and broadcasts that mirror variable. | `Server/Functions/Server_ChangeSideSupply.sqf:1-21,25-45` |

Known side-supply hazards remain owner-page material, not new findings here: current master still parses `_reason` only when `count _this > 3`, so three-argument callers lose their audit reason; its negative-floor branch uses `_currentSupply - _amount` when `_change < 0`; and the server handlers exist only for west/east temp channels while the common writer formats `wfbe_supply_temp_<side>` generically. Use [Economy authority first cut](Economy-Authority-First-Cut), [Public variable channel index](Public-Variable-Channel-Index), and [Resistance supply scaffold](Resistance-Supply-Scaffold) before changing this path. `Common/Functions/Common_ChangeSideSupply.sqf:8-14,22-30`; `Server/Functions/Server_ChangeSideSupply.sqf:1-47`.

`WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers` only runs for positive side-supply income when `includeStagnation` is true. It checks same-side player presence, increments per-side no-player tick counters, clamps the decrease percentage to `0..1`, and reduces the income amount when the percentage is between zero and one. `Common/Functions/Common_ChangeSideSupply.sqf:16-18`; `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:38-47,49-67,69-85`.

## Runtime Consumer Map

| Consumer | Team/side state used | Source |
| --- | --- | --- |
| Command menu | Reads team type, move mode, move target, funds, autonomous flag, vehicles, and respawn target; writes move mode/target, forced respawn, autonomous flag, team type, and selected respawn structure. | `Client/GUI/GUI_Menu_Command.sqf:62-66,182-190,210,256-258,299-306,359-362,370-406,442-452` |
| Client commander-loss cleanup | When `commanderTeam` becomes null, the client removes commander/HQ actions and sets every client team non-autonomous. | `Client/FSM/updateclient.sqf:211-225` |
| AI squad respawn | Reads team respawn, clears forced respawn, and when the team is not autonomous converts `"move"`, `"patrol"`, and `"defense"` modes into reset modes after respawn. | `Server/AI/AI_SquadRespawn.sqf:24,73,78,103-109` |
| Advanced AI respawn | Mirrors the same respawn/autonomous/move-mode reset shape as `AI_SquadRespawn`. | `Server/AI/AI_AdvancedRespawn.sqf:19,86,92,118-124` |
| Team income | Resource ticks pay group money through `WFBE_CO_FNC_ChangeTeamFunds`. | `Server/FSM/updateresources.sqf:63` |
| Queued upgrades | Upgrade queue checks side supply and commander-team funds, then debits side supply and team funds when starting an upgrade. | `Server/FSM/upgradeQueue.sqf:76-77,103-105` |
| Player upgrade menu | The client upgrade UI reads side supply for affordability and sends side-supply debit through `ChangeSideSupply` when starting an upgrade. | `Client/GUI/GUI_UpgradeMenu.sqf:186,230,253` |
| Supply mission completion | Heli cash runs can add commander-team funds; normal completion adds side supply through `ChangeSideSupply`. | `Server/Module/supplyMission/supplyMissionCompleted.sqf:37,40` |
| Client UI side facts | RHUD reads side upgrades, side supply, side structures, and HQ; client init resolves `sideID`, `clientTeam`, `clientTeams`, client side logic, and side color. | `Client/Client_UpdateRHUD.sqf:161,348-350,372-374`; `Client/Init/Init_Client.sqf:230-287` |

## Practical Rules

| Rule | Why | Source |
| --- | --- | --- |
| Prefer the prefixed `WFBE_CO_FNC_*` names in new shared code when they exist. | Current init compiles both legacy short names and prefixed names for many side/team helpers, and both point at the same helper files. | `Common/Init/Init_Common.sqf:40-44,52-58,76-80,126-135` |
| Treat `wfbe_autonomous` as an order-reset flag, not proof of a live independent AI commander brain. | The visible writers/readers are command UI toggles, commander-loss cleanup, and AI respawn order-reset logic. | `Client/GUI/GUI_Menu_Command.sqf:370-391`; `Client/FSM/updateclient.sqf:225`; `Server/AI/AI_SquadRespawn.sqf:103-109`; `Server/AI/AI_AdvancedRespawn.sqf:118-124` |
| Do not put UI loops behind unbounded `GetSideSupply` reads unless the cache is known present. | `GetSideSupply` waits until a missing `wfbe_supply_<side>` cache appears after a request/reply path. | `Common/Functions/Common_GetSideSupply.sqf:13-18,26-31,39-44`; `Client/GUI/GUI_Menu_Economy.sqf:229` |
| Keep side-supply arithmetic fixes separate from authority fixes. | `ChangeSideSupply` sends a direct temp public variable; the server temp handlers still trust side/amount payload values and mirror west/east supply caches. | `Common/Functions/Common_ChangeSideSupply.sqf:28-30`; `Server/Functions/Server_ChangeSideSupply.sqf:4-21,28-45` |

## Continue Reading

- [Function and module index](Function-And-Module-Index)
- [Variable and naming conventions](Variable-And-Naming-Conventions)
- [Economy authority first cut](Economy-Authority-First-Cut)
- [Public variable channel index](Public-Variable-Channel-Index)
- [AI commander autonomy audit](AI-Commander-Autonomy-Audit)
