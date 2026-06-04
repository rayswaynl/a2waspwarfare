# Economy, Towns And Supply

Town object initialization, capture/SV state, camp capture, marker visibility and town-AI activation are now mapped in [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas). Keep this page focused on economy/supply/resource interpretation and route town lifecycle implementation details there.

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
7. `Server/Module/supplyMission/supplyMissionCompleted.sqf` trusts the vehicle object vars, updates side supply and sends the completion message.
8. `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf` notifies the player, applies the personal cash reward locally and asks the server to award score.

## Cooldown Flow

`isSupplyMissionActiveInTown.sqf` compares the town's supply-mission timestamp to `WFBE_CO_VAR_SupplyMissionRegenInterval`, then broadcasts `WFBE_Server_PV_IsSupplyMissionActiveInTown`. Client `townSupplyStatus.sqf` stores that on the town as `supplyMissionCoolDownEnabled`.

Routing note: [Supply mission architecture](Supply-Mission-Architecture) owns the cooldown/JIP flow, [Deep-review findings](Deep-Review-Findings) DR-18 owns the `lastSupplyMissionRun` / `LastSupplyMissionRun` casing defect, and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) owns the patch shape.

## Economy And Commander Funds

Funds and supply are separate systems unless the mission parameter switches currency behavior. Commander income can be limited and distributed. On current `master`, supply mission side reward is applied by `supplyMissionCompleted.sqf`, while the personal player cash message path grants raw `_supplyAmount`; the constant `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF` is defined but no live consumer was found in this flow.

2026-06-04 economy scout refinement: the separation is conceptual, not a guarantee that every payout path is independently gated. `Server/FSM/updateresources.sqf:29-70` computes town supply income, then wraps side-supply growth, player paychecks and AI-commander funds in `if (_supply < WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT)`. Because `_supply` is the town-income value, not the current side-supply balance, this looks like an old supply-cap guard that also suppresses money payouts when the computed town supply reaches the cap. Treat income-loop changes as economy gameplay changes, not only supply UI changes.

The same scout found a client/server display mismatch for income system `4`: server payout multiplies income by `1.5` before splitting commander/player shares (`updateresources.sqf:41-44`), while `Client/Functions/Client_GetIncome.sqf:20-29` displays the same split without the `1.5` multiplier. Verify the intended balance before changing either path; the important docs point is that RHUD/menu income can differ from the actual paycheck.

AI commander upgrades have a separate suspected debit bug. `Server_AI_Com_Upgrade.sqf:32-36` validates `_cost select 0` as side supply and `_cost select 1` as funds, matching the player upgrade menu (`GUI_UpgradeMenu.sqf:96-99,139-159`), but the deduction path subtracts `_cost select 0` from AI commander funds and `_cost select 1` from side supply (`Server_AI_Com_Upgrade.sqf:47-50`). Treat this as a likely split-currency bug before enabling or expanding autonomous AI commander upgrades.

### Supply Mission Reward Formula And Stale Copy

The live truck reward path is not the old "4 x actual value" player-help rule. Current source computes loaded cargo as `floor((town supplyValue) * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * supplyUpgradeModifier)` in `Client/Module/supplyMission/supplyMissionStart.sqf:22-34`; the multiplier constant is `20` at `Common/Init/Init_CommonConstants.sqf:167`. Completion then sends the same `_supplyAmount` to the player message path, where `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:8,13-14` grants that raw amount as local cash.

The stale copy is in `stringtable.xml:188-193`: `STR_Supplies_2` still tells players they receive "4 x the actual value as cash". The matching constant, `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4`, remains defined at `Init_CommonConstants.sqf:268`, but this source pass found no live consumer in the current supply-mission completion flow. Treat the stringtable text as player-facing docs debt, not runtime authority.

## Economy Authority Synthesis

The economy authority class is now fully characterized by source review. Every confirmed spend or value-changing path is client-authoritative or trusts client-originated payload/state:

| Path | Finding | Evidence |
| --- | --- | --- |
| Construction/build | Client pays and sends `RequestStructure` / `RequestDefense`; server performs only light creation checks. | DR-6, [Construction atlas](Construction-And-CoIn-Systems-Atlas) |
| Player unit buy | Client spawns through `Client_BuildUnit` and deducts locally; no `RequestBuyUnit` PVF exists. | DR-14, [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas) |
| Structure sale | Economy UI refunds and destroys locally. | DR-16 |
| Side supply | Direct temp channels mutate keyed `wfbe_supply_%1` values; the generic `wfbe_supply` client init value is a legacy alias/cache. Server negative-delta floor can turn overspend into supply gain, and the west/east handlers trust the payload side rather than deriving it from the channel suffix. | DR-22, DR-44, [Economy authority first cut](Economy-Authority-First-Cut) |
| Score mutation/rewards | `RequestChangeScore` accepts a payload score, while `Common_AwardScorePlayer` and kill scoring show safer server-derived award patterns. | [Economy authority first cut](Economy-Authority-First-Cut), [Public variable channel index](Public-Variable-Channel-Index) |
| Player/group funds | No `RequestChangeFunds` PVF exists; funds are changed through replicated `wfbe_funds` group variables and shared helpers. | [Economy authority first cut](Economy-Authority-First-Cut) |
| Supply mission cargo/reward | Client stamps `SupplyFromTown` / `SupplyAmount` onto the vehicle; server completion trusts those vars after proximity checks. Personal cash/score reward presentation is still client-side after the completion broadcast. | [Supply mission architecture](Supply-Mission-Architecture) |
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

