# Economy Authority First Cut

This page turns the broad economy/server-authority decision into the smallest source-backed implementation sequence worth doing first.

Scope: Chernarus source mission first, Arma 2 Operation Arrowhead 1.64 only, then LoadoutManager propagation. It complements [Server authority map](Server-Authority-Migration-Map), [Upgrades and research atlas](Upgrades-And-Research-Atlas), [Economy, towns and supply](Economy-Towns-And-Supply), [Hardening roadmap](Hardening-Implementation-Roadmap), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).

## Status

| Item | State |
| --- | --- |
| Finding class | Confirmed economy/server-authority class across DR-6, DR-14, DR-16, DR-22, DR-23, DR-27, DR-28 and DR-41. |
| New value from this pass | First safe code sequence: side-supply arithmetic/validation first, then existing PVF spend handlers, then player-buy redesign. |
| Wave I refinement | Kepler split client-trusted score/funds/supply mutation from safer server-derived read and award helpers. |
| Immediate patch candidate | `Common_ChangeSideSupply.sqf` and `Server_ChangeSideSupply.sqf` negative clamp and side/channel validation. |
| Smallest server-led migration candidate | Upgrade purchase, because `RequestUpgrade` already reaches a server process but currently trusts client-side debit and dependency checks. |
| Do not treat as small | Player factory buys. They create units/vehicles from the client and have no `RequestBuyUnit` PVF. |

## What I Read

- `Common/Functions/Common_ChangeSideSupply.sqf:3-30`
- `Server/Functions/Server_ChangeSideSupply.sqf:1-47`
- `Common/Functions/Common_ChangeTeamFunds.sqf:1-8`
- `Server/PVFunctions/RequestChangeScore.sqf:3-13`
- `Client/PVFunctions/TownCaptured.sqf:71`
- `Common/Functions/Common_AwardScorePlayer.sqf:17-27`
- `Common/Functions/Common_GetTotalSupplyValue.sqf:7-11`
- `Common/Functions/Common_GetSideSupply.sqf:11,17,24,30,37,43`
- `Server/Functions/Server_PV_RequestSupplyValue.sqf:1-8`
- `Client/Functions/Client_ReceiveSupplyValue.sqf:7`
- `Client/Init/Init_Client.sqf:371`
- `Client/Functions/Client_ChangePlayerFunds.sqf:1`
- `Client/Functions/Client_GetPlayerFunds.sqf:1`
- `Client/GUI/GUI_UpgradeMenu.sqf:129-172`
- `Server/PVFunctions/RequestUpgrade.sqf:1-5`
- `Server/Functions/Server_ProcessUpgrade.sqf:12-18`, `:23-44`, `:85-87`
- `Client/Module/CoIn/coin_interface.sqf:240-260`, `:485-503`, `:667-724`
- `Server/PVFunctions/RequestStructure.sqf:3-22`
- `Server/PVFunctions/RequestDefense.sqf:2-10`
- `Client/GUI/GUI_Menu_BuyUnits.sqf:83-156`
- `Client/Functions/Client_BuildUnit.sqf:211-249`, `:409-455`
- `Client/GUI/GUI_Menu_Economy.sqf:120-150`
- `Client/GUI/GUI_Menu_Service.sqf:195-234`
- `Client/GUI/GUI_Menu_EASA.sqf:40-50`
- `Client/Action/Action_RepairMHQ.sqf:24-40`
- `WASP/actions/Action_RepairMHQDepot.sqf:13-28`
- `Client/Module/supplyMission/supplyMissionStart.sqf:3-51`
- `Server/Module/supplyMission/supplyMissionStarted.sqf:1-88`
- `Server/Module/supplyMission/supplyMissionCompleted.sqf:2-48`
- `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:1-18`
- `Server/Functions/Server_HandleSpecial.sqf:97-111`
- `Server/Functions/Server_AttackWave.sqf:1-38`
- Existing wiki records: [Deep-review findings](Deep-Review-Findings), [Server authority map](Server-Authority-Migration-Map), [Pending owner decisions](Pending-Owner-Decisions), [Public variable channel index](Public-Variable-Channel-Index), [Economy, towns and supply](Economy-Towns-And-Supply), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook).

## What The Code Actually Does

### Funds are a replicated group variable

`Common_ChangeTeamFunds.sqf` takes `[team, amount]` and writes:

```sqf
_team setVariable ["wfbe_funds", (_team getVariable "wfbe_funds") + _amount, true];
```

`Client_ChangePlayerFunds.sqf:1` simply calls that with `clientTeam`, and `Client_GetPlayerFunds.sqf:1` reads the same team value. This is why many UI paths can debit or credit locally after client-side affordability checks.

There is no `Server/PVFunctions/RequestChangeFunds.sqf` in the current source. Funds authority is a convention over replicated group variables and shared helpers, not a single server request wall.

### Side supply uses direct publicVariable temp channels

`Common_ChangeSideSupply.sqf:28-30` writes `wfbe_supply_temp_<side>` and `publicVariableServer`s it. `Server_ChangeSideSupply.sqf` registers separate handlers for `wfbe_supply_temp_west` and `wfbe_supply_temp_east`.

Both common and server code compute:

```sqf
_change = _currentSupply + _amount;
if (_change < 0) then {_change = _currentSupply - _amount};
```

For `_currentSupply = 100` and `_amount = -1000`, this produces `1100`, not `0`. The direct-PV authority issue remains, but the arithmetic bug is a small, real first patch.

The live source of truth for side supply is the side-keyed mission variable `wfbe_supply_%1` read by `Common_GetSideSupply.sqf`. The generic `wfbe_supply` value initialized in `Client/Init/Init_Client.sqf:371` is a legacy alias/cache and should not be used as the target for new authority work.

### Score and supply reads show mixed authority patterns

`RequestChangeScore.sqf` accepts a score value from the payload and applies it with `addScore`. `TownCaptured.sqf:71` uses this route after client-side capture reward handling, so capture bounty scoring belongs in the same authority family as funds and supply rewards.

There are also safer patterns worth reusing. `Common_AwardScorePlayer.sqf:17-27` derives score awards from configured constants, `RequestOnUnitKilled.sqf:71-80` computes kill points server-side, `Common_GetTotalSupplyValue.sqf:7-11` recomputes aggregate supply from town state, and `Server_PV_RequestSupplyValue.sqf:1-8` answers a read request by deriving the current supply on the server. New patches should move toward those server-derived patterns rather than adding more client-stamped mutation payloads.

### Upgrades already have a server entrypoint, but client owns debit and validation

`GUI_UpgradeMenu.sqf:141-161` checks funds, side supply and dependencies locally, then:

- debits player funds at `:158`;
- debits side supply through `ChangeSideSupply` at `:159`;
- sends `RequestUpgrade` with `[side, id, currentLevel, true]` at `:161`.

`RequestUpgrade.sqf:5` just spawns `Server_ProcessUpgrade`. `Server_ProcessUpgrade.sqf:12-18` trusts side, id and level from the payload to look up time; `:40-44` increments the upgrade state and clears the running flag. It does not recompute commander, current level, dependencies, cost or funds before accepting the transition. See [Upgrades and research atlas](Upgrades-And-Research-Atlas) for the full live-menu/server-worker/AI-worker map.

### Construction/defense already have server entrypoints, but client owns debit and placement affordance

`coin_interface.sqf:667-674` debits side supply or player funds for structures locally; `:718` sends `RequestStructure`. Defense purchase debits player funds at `:690-693` and sends `RequestDefense` at `:722`.

`RequestStructure.sqf:3-22` accepts side, class, position and direction from the payload, resolves the structure script and starts construction. `RequestDefense.sqf:2-10` accepts side, class, position, direction and manned flag and calls `ConstructDefense`. Neither handler proves requester, commander role, funds, base area, object side, placement or class permission beyond array membership.

### Player factory buys are the ceiling, not the first cut

`GUI_Menu_BuyUnits.sqf:102-108` checks funds locally, queues locally and at `:155-156` spawns `BuildUnit` and debits `ChangePlayerFunds`. `Client_BuildUnit.sqf:217` creates infantry through `WFBE_CO_FNC_CreateUnit`; `:249` creates vehicles through `WFBE_CO_FNC_CreateVehicle`; `:411-455` creates crew locally. There is no `RequestBuyUnit` PVF in `Init_PublicVariables.sqf` and no `Server/PVFunctions/RequestBuyUnit.sqf`.

That means player buy authority is a redesign, not a tidy handler hardening patch. It needs a server request/acceptance model or an explicit BattlEye `scripts.txt` posture while preserving locality.

### Supply missions are a separate logistics authority lane

On current `master`, `supplyMissionStart.sqf:20-39` lets the client stamp `SupplyFromTown` and `SupplyAmount` on the truck, then publishes `WFBE_Client_PV_SupplyMissionStarted`. The server starts a tracking loop in `supplyMissionStarted.sqf:1-88` and completes via `WFBE_Server_PV_SupplyMissionCompleted`. Completion reads the vehicle vars at `supplyMissionCompleted.sqf:9-28`, rewards side supply through `ChangeSideSupply`, clears the source/amount vars and broadcasts the completion message. The player's personal cash/score path is in the client completion message, not the server completion handler.

PR #1 adds `SupplyByHeli` and additional heli/cash-run reward branches on top of this trust model; keep those branch-only mechanics scoped to [Current supply helicopter PR](Current-Work-Supply-Helicopters-PR1) and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook).

That flow is important, but it should stay with `supply-mission-authority-cleanup` rather than being bundled into the first economy patch.

## First Implementation Sequence

### 1. Patch side-supply arithmetic and temp-channel validation

Files:

- `Common/Functions/Common_ChangeSideSupply.sqf`
- `Server/Functions/Server_ChangeSideSupply.sqf`

Patch shape:

```sqf
_change = _currentSupply + _amount;
if (_change < 0) then {_change = 0};
if (_change > _maxSupplyLimit) then {_change = _maxSupplyLimit};
```

Also validate the direct temp channel:

- west handler accepts only `_side == west`;
- east handler accepts only `_side == east`;
- reject malformed `_amount` or `_side` values with one compact `WARNING`;
- reject side/channel mismatches, not just negative amounts;
- keep positive rewards and normal spend behavior unchanged.

Why first: this is the smallest source-backed exploit fix. It does not solve who is allowed to mutate supply, but it prevents overspend from becoming a windfall while future authority work is designed.

Validation:

- Source-only: both common and server copies no longer use `_currentSupply - _amount` for the negative floor.
- Dedicated smoke: normal town income still raises supply; normal construction/upgrade supply spend lowers supply; overspend floors at zero.
- Negative smoke: forged temp channel with `_side` mismatching its channel no-ops and logs once.

### 2. Migrate upgrades to server-owned acceptance/debit

Files:

- `Client/GUI/GUI_UpgradeMenu.sqf`
- `Server/PVFunctions/RequestUpgrade.sqf`
- `Server/Functions/Server_ProcessUpgrade.sqf`

Patch shape:

- Keep the client menu affordability/dependency checks for feedback only.
- Send requester context, not just side/id/level. For example, include `player` and `clientTeam`, then let the server derive side/commander status from server-known objects as far as Arma 2 OA allows.
- On the server, reject if:
  - requester/team is null or not on the claimed side;
  - requester team is not the commander team;
  - side is already upgrading;
  - requested id or level is out of range;
  - requested level is not the current server-held level;
  - dependencies are not met;
  - commander funds or side supply are insufficient.
- Debit funds/supply on the server only after acceptance.
- Preserve the existing `upgrade-started`, sync wait and `upgrade-complete` broadcasts.

Why second: there is already a PVF handler and server process, so this is smaller than player-buy authority and more coherent than trying to patch every client-local support action first.

Validation:

- Valid commander upgrade still starts and completes.
- Non-commander request rejects.
- Wrong-side, bad id, skipped dependency and insufficient funds/supply reject.
- Hosted and dedicated paths both preserve upgrade-running UI state.

### 3. Migrate construction and defense debit/acceptance

Files:

- `Client/Module/CoIn/coin_interface.sqf`
- `Server/PVFunctions/RequestStructure.sqf`
- `Server/PVFunctions/RequestDefense.sqf`

Patch shape:

- Keep preview colors and local affordance.
- Move final debit and acceptance into the server handler.
- Include requester context and let the server derive commander/side.
- Recompute class allowlist, cost, base area, HQ/deployed state, direction/position sanity and manned-defense permission.
- On acceptance, server debits funds/supply and executes construction/defense.
- On rejection, server logs compactly and the client shows a failure message if practical.

Validation:

- Valid HQ undeploy/deploy and one non-HQ structure still work.
- Valid defense still works.
- Wrong-side, unaffordable, out-of-base, bad class and non-commander requests reject.
- Existing side messages and base-area availability do not double-decrement.

### 4. Defer player factory buys until locality design is approved

Do not try to hide DR-14 inside a small economy patch. The live path creates units and vehicles from the client. A proper server-authority version needs a request/acceptance model that accounts for factory queues, buyer group locality, vehicle locality, AI ownership, disconnects and crew creation.

Interim posture:

- document player buys as client-authoritative;
- if public-server hardening is required before redesign, design BattlEye `scripts.txt` constraints for client `createUnit`/`createVehicle` separately from `publicvariable.txt`;
- do not claim PVF dispatcher hardening or side-supply clamp makes player buys safe.

## Boundary Notes

This first-cut does not replace:

- [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook): dispatcher lookup hardening is still prerequisite foundation.
- [Attack-wave authority playbook](Attack-Wave-Authority-Playbook): `ATTACK_WAVE_INIT` is a direct publicVariable channel with its own server recomputation shape.
- `supply-mission-authority-cleanup`: supply mission cargo/reward trust and PR #1 helicopter reward behavior need a dedicated logistics pass.
- BattlEye owner decision: the repo still should not be described as public-server hardened without confirming production BEpath or adding real filters.

## Handoff

Future code owner:

1. Implement side-supply clamp/validation as the first economy hardening branch, e.g. `hardening/side-supply-clamp`.
2. Run source-only checks, then hosted/dedicated supply spend/reward smokes.
3. Record the validation in [Testing workflow](Testing-Debugging-And-Release-Workflow) terms.
4. Only then migrate upgrades and construction as separate branches. Do not bundle player-buy locality redesign into the clamp patch.
5. After mission edits, run `Tools/LoadoutManager` to propagate generated mission changes.

Codex/Claude follow-up:

- Review whether `Common_ChangeSideSupply.sqf` can be split into a server-local mutation helper plus a client request helper. That would reduce future direct-PV confusion.
- If owner wants public-server hardening before economy redesign, create a BattlEye posture page or filter-design handoff that covers both `publicvariable.txt` and `scripts.txt`.

## Continue Reading

Previous: [Server authority map](Server-Authority-Migration-Map) | Next: [Hardening roadmap](Hardening-Implementation-Roadmap)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
