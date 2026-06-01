# Economy, Towns And Supply

## Town Supply Model

Town supply value drives economy and supply missions. Constants define automatic supply growth and truck/supply mission effects:

- `WFBE_C_ECONOMY_SUPPLY_SYSTEM = 1` by default, meaning automatic timed supply growth.
- `WFBE_C_ECONOMY_SUPPLY_TIME_INCREASE_DELAY = 60`.
- `WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER = 20`.
- `WFBE_C_TOWNS_SUPPLY_LEVELS_TIME = [1, 2, 3, 4, 5]`.
- `WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK = [5, 6, 7, 8, 10]`.

## Player Supply Mission Flow On `master`

1. A SpecOps skill action adds `LOAD SUPPLIES TO TRUCK` through `Client/Module/Skill/Skill_Apply.sqf`.
2. `Client/Module/supplyMission/supplyMissionStart.sqf` asks the server if the town is on cooldown.
3. If allowed, the selected supply truck receives `SupplyFromTown` and `SupplyAmount`.
4. The client broadcasts `WFBE_Client_PV_SupplyMissionStarted`.
5. `Server/Module/supplyMission/supplyMissionStarted.sqf` starts tracking the vehicle object and town.
6. Proximity to a command center completes the mission by broadcasting `WFBE_Server_PV_SupplyMissionCompleted`.
7. `Server/Module/supplyMission/supplyMissionCompleted.sqf` updates side supply and sends the completion message.
8. `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf` notifies the player and asks the server to award score.

## Cooldown Flow

`isSupplyMissionActiveInTown.sqf` compares `LastSupplyMissionRun` to `WFBE_CO_VAR_SupplyMissionRegenInterval`, then broadcasts `WFBE_Server_PV_IsSupplyMissionActiveInTown`. Client `townSupplyStatus.sqf` stores that on the town as `supplyMissionCoolDownEnabled`.

## Economy And Commander Funds

Funds and supply are separate systems unless the mission parameter switches currency behavior. Commander income can be limited and distributed; player delivery funds use `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF`.

## Supply-Related Partial Work

`Server/AI/AI_UpdateSupplyTruck.sqf` exists but is not compiled on `master`; its compile line in `Init_Server.sqf` is commented out. The script references missing `Server/FSM/supplytruck.fsm`. Treat autonomous AI logistics as incomplete/deferred.

## PR #1 Supply Helicopters

The open PR extends this flow to helicopters. See [Current work: supply helicopters PR #1](Current-Work-Supply-Helicopters-PR1).

