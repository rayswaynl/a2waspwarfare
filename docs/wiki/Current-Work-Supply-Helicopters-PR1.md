# Current Work: Supply Helicopters PR #1

PR: <https://github.com/rayswaynl/a2waspwarfare/pull/1>

Branch: `feat/supply-helicopter`

Base: `master`

Status at indexing: open, not draft, mergeable, no status checks reported by GitHub.

## Summary

PR #1 extends player-run supply missions from trucks to transport helicopters. The stable `master` flow is vehicle-object based on the server, so the PR mostly expands client eligibility, action labels, upgrade gating, rewards and completion messaging.

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

