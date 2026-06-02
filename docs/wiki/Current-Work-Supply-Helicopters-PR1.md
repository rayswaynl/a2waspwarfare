# Current Work: Supply Helicopters PR #1

PR: <https://github.com/rayswaynl/a2waspwarfare/pull/1>

Branch: `feat/supply-helicopter`

Base: `master`

Status at indexing: open, not draft, mergeable, no status checks reported by GitHub.

## Summary

PR #1 extends player-run supply missions from trucks to transport helicopters. The stable `master` flow is vehicle-object based on the server, so the PR mostly expands client eligibility, action labels, upgrade gating, rewards and completion messaging.

Linnaeus' second-pass source reconciliation confirmed the branch is additive, not a rewrite. `master` remains a truck-based, client-started, server-completed flow; PR #1 adds heli tiers, cash-run routing and interdiction rewards on the same object-variable trust model.

## Files Changed

- `Client/Functions/Client_UIFillListBuyUnits.sqf`
- `Client/Module/Skill/Skill_Apply.sqf`
- `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf`
- `Client/Module/supplyMission/supplyMissionStart.sqf`
- `Common/Init/Init_CommonConstants.sqf`
- `Server/Module/supplyMission/supplyMissionCompleted.sqf`
- `Server/Module/supplyMission/supplyMissionStarted.sqf`

## Mechanics From The PR

- SpecOps players can buy transport helicopters and use `LOAD SUPPLIES`.
- WEST examples include CH-47F/UH-60M class families already present in lift vehicle lists.
- EAST examples include Mi-17 family transports.
- Light supply helicopters require Supply upgrade level 2.
- Heavy supply helicopters require Supply upgrade level 3.
- Heavy helicopters haul +20 percent.
- Supply upgrade level 3 can convert heli deliveries into team funds for the commander team.
- Air delivery gives the pilot +25 percent funds/score reward.
- Destroying a loaded enemy supply vehicle awards the killer's side 25 percent of cargo value.
- Buy menu highlights supply helicopters similarly to supply trucks.

## Why The Server Flow Can Work

On `master`, server delivery already tracks a vehicle object and checks command-center proximity. The server completion code is not intrinsically truck-only. The PR carries a `SupplyByHeli` flag end-to-end to distinguish rewards and cargo behavior.

## Authority And Reward Notes

| Topic | Current reading |
| --- | --- |
| Start authority | Still client initiated. The client performs eligibility checks and writes object variables before the server tracking loop starts. |
| Completion authority | Server verifies proximity to a command center, then trusts vehicle state such as `SupplyAmount`, `SupplyFromTown` and PR #1's `SupplyByHeli`. |
| Cooldown | Still town-var based; the existing `lastSupplyMissionRun` / `LastSupplyMissionRun` casing mismatch remains a master and PR concern. |
| Cash runs | Heavy-heli supply upgrade level 3 can route value to commander team funds when a commander exists; otherwise completion falls back to side supply. |
| Interdiction | Destroying a loaded enemy supply vehicle pays a fraction of cargo value. Stacked handlers are muted today because the handler clears `SupplyAmount`, but the event-handler leak remains real. |

## Deferred Work

Autonomous AI-flown supply helicopters are intentionally deferred. The upstream AI supply truck path is incomplete: `AI_UpdateSupplyTruck.sqf` references missing `Server/FSM/supplytruck.fsm`, and the compile line is commented out on `master`.

## Suggested Review Focus

- Confirm action eligibility cannot be triggered by non-supply helicopters.
- Confirm upgrade gates match light/heavy class lists.
- Confirm loaded vehicle kill handler cannot double-award interdiction rewards.
- Confirm repeated loading of the same vehicle does not stack duplicate `Killed` event handlers.
- Confirm cash-run funds go to the intended commander/team account.
- Confirm action labels and completion messages still make sense for trucks and helicopters.
- Run LoadoutManager after merge to propagate Chernarus source changes to Takistan/generated targets.

## Claude Review Pass

Claude verified the review questions against the `master..feat/supply-helicopter` diff. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| Question | Verdict | Evidence |
| --- | --- | --- |
| Can a non-supply helicopter trigger the action? | No. | `Client/Module/Skill/Skill_Apply.sqf` gates the action by truck class or supply-heli class plus upgrade level, and `supplyMissionStart.sqf` recomputes eligibility before loading. |
| Do upgrade gates match the class lists? | Yes. | `Init_CommonConstants.sqf` adds T2 light heli classes gated at Supply upgrade >=2 and T3 heavy heli classes gated at >=3. |
| Can interdiction double-award? | No for one death. | The `Killed` EH awards `round(_amt * 0.25)` and immediately sets `SupplyAmount` to `0`, so later stacked handlers see zero. |
| Do repeated reloads stack handlers? | Yes. | `Server/Module/supplyMission/supplyMissionStarted.sqf` adds a `Killed` EH every mission start with no guard or removal. This is a real event-handler leak even though double payment is currently prevented. |
| Do cash-run funds reach the intended account? | Yes. | Heavy-heli cash runs move value to commander team funds through `ChangeTeamFunds`; without a commander, value falls back to side supply. Side supply receives nothing on a successful cash run by design. |
| Do messages still read sensibly? | Yes. | Labels use `LOAD SUPPLIES`; messages distinguish `"HELI"` and `"truck"` and append `" (cash run)"` where appropriate. |

### New Constants Introduced By PR #1

`Init_CommonConstants.sqf` gains `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES_T2`, `WFBE_C_SUPPLY_HELI_TYPES_T3`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES`. This centralizes class lists that were previously duplicated in action and mission-start logic.

### Confirmed Follow-Up Defect

Repeatedly loading the same vehicle stacks `Killed` event handlers. Recommended fix: set an object variable such as `wfbe_supply_killed_eh_set`, or remove the previous `Killed` handler before adding a new one. Do not add future side effects to that handler until this is fixed.

## Continue Reading

Previous: [Supply mission architecture](Supply-Mission-Architecture) | Next: [AI/headless/performance](AI-Headless-And-Performance)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
