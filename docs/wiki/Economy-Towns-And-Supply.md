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

Source reconciliation note: `Common/Init/Init_Town.sqf` seeds `lastSupplyMissionRun`, but server supply mission code reads/writes `LastSupplyMissionRun`. Treat cooldown behavior as suspect until the casing is normalized or proven harmless in-game.

## Economy And Commander Funds

Funds and supply are separate systems unless the mission parameter switches currency behavior. Commander income can be limited and distributed; player delivery funds use `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF`.

## Economy Authority Synthesis

The economy authority class is now fully characterized by source review. Every confirmed spend or value-changing path is client-authoritative or trusts client-originated payload/state:

| Path | Finding | Evidence |
| --- | --- | --- |
| Construction/build | Client pays and sends `RequestStructure` / `RequestDefense`; server performs only light creation checks. | DR-6, [Construction atlas](Construction-And-CoIn-Systems-Atlas) |
| Player unit buy | Client spawns through `Client_BuildUnit` and deducts locally; no `RequestBuyUnit` PVF exists. | DR-14, [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas) |
| Structure sale | Economy UI refunds and destroys locally. | DR-16 |
| Side supply | Server negative-delta floor can turn overspend into supply gain. | DR-22 |
| Supply mission cargo/reward | Client stamps `SupplyFromTown` / `SupplyAmount` onto the vehicle; server completion trusts those vars after proximity checks. | [Supply mission architecture](Supply-Mission-Architecture) |
| Upgrades | `RequestUpgrade` passes raw payload into server process; no server-side cost/commander/dependency validation. | DR-23 |
| ICBM/special | Client can send `RequestSpecial ["ICBM", ...]`; server spawns `NukeDammage` from payload without authority checks. | DR-27, [Networking/PV](Networking-And-Public-Variables) |
| Gear/EASA/service | Gear, EASA and vehicle service effects/debits are client-side; service rearm/refuel skip even client affordability guards. | DR-28, [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Attack wave price modifier | `ATTACK_WAVE_INIT` is a direct client/common -> server publicVariable; server trusts `_supply` / `_side` and can apply a side-wide unit-price modifier from forged payload. | DR-41, [Networking/PV](Networking-And-Public-Variables), [Server authority map](Server-Authority-Migration-Map), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) |

This should be treated as one owner decision, not separate patch tracks. Either introduce a server-side funds/effects ledger and validate each spend handler before applying effects, or explicitly accept the legacy client-trusted model and lean on BattlEye script filters for public-server hardening. DR-41 adds an important architecture rule: the forgery class has two surfaces, registered PVF handlers and direct `publicVariableServer` channels, so a PVF dispatcher fix alone does not harden direct economy/support channels. Small parity fixes, such as adding affordability guards to service rearm/refuel, are useful correctness work but do not close the architectural authority gap.

## Supply-Related Partial Work

`Server/AI/AI_UpdateSupplyTruck.sqf` exists but is not compiled on `master`; its compile line in `Init_Server.sqf` is commented out. The script references missing `Server/FSM/supplytruck.fsm`. Treat autonomous AI logistics as incomplete/deferred.

## PR #1 Supply Helicopters

The open PR extends this flow to helicopters. It adds class constants, light/heavy upgrade gates, `SupplyByHeli`, air bonuses, commander-team cash runs and interdiction rewards, but it does not change the fundamental client-started/server-completed trust model. See [Current work: supply helicopters PR #1](Current-Work-Supply-Helicopters-PR1).

Implementation handoff: [Economy authority first cut](Economy-Authority-First-Cut) turns this economy-authority class into the smallest source-backed patch order.

## Continue Reading

Previous: [Core systems](Core-Systems-Index) | Next: [Supply mission architecture](Supply-Mission-Architecture)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

