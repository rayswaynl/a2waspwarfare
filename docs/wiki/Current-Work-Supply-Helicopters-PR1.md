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

## Claude review pass — questions answered (source-cited)

Verified against the full `master..feat/supply-helicopter` diff (commits `08664ebc`, `1faf738d`). Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

| Review question | Verdict | Evidence |
| --- | --- | --- |
| Can a non-supply heli trigger the action? | **No.** Eligibility is double-gated. | The `addAction` `condition` in `Client/Module/Skill/Skill_Apply.sqf` requires `cursorTarget` ∈ `WFBE_C_SUPPLY_TRUCK_TYPES`, or ∈ `_T2` with Supply upgrade ≥2, or ∈ `_T3` with ≥3. `supplyMissionStart.sqf` re-computes `_eligible` independently before loading. |
| Do upgrade gates match the class lists? | **Yes.** | Constants added in `Common/Init/Init_CommonConstants.sqf`: `_T2` (light, ≥2) = `UH60M_EP1, MH60S, Mi17_*`; `_T3` (heavy, ≥3, +20% payload) = `CH_47F_EP1, CH_47F_BAF, BAF_Merlin_HC3_D`. The gate expressions in both `Skill_Apply.sqf` and `supplyMissionStart.sqf` use the same `WFBE_UP_SUPPLYRATE` thresholds. |
| Can interdiction double-award? | **No (within one death).** | `supplyMissionStarted.sqf` `Killed` EH awards `round(_amt*0.25)` then immediately `_veh setVariable ["SupplyAmount",0,true]`. If handlers are stacked (see below), the first zeroes the amount; later handlers read `0` (nil-guarded) and skip. |
| Do repeated reloads stack duplicate `Killed` handlers? | **Yes — confirmed defect.** | `supplyMissionStarted.sqf` calls `_associatedSupplyTruck addEventHandler ["Killed", …]` unconditionally inside the `WFBE_Server_PV_SupplyMissionCompleted`-adjacent start handler, with no `removeAllEventHandlers "Killed"` and no "already-tracked" guard. A vehicle that runs N supply missions accumulates N `Killed` EHs. Impact is bounded (interdiction can't double-pay due to the zeroing above), but it is an EH leak and any future side-effect added to that EH *would* multiply. Recommended fix: guard with a `wfbe_supply_killed_eh_set` object variable, or `removeAllEventHandlers` before adding. |
| Do cash-run funds reach the right account? | **Yes.** | `supplyMissionCompleted.sqf`: `_cashRun = _byHeli && (_upgradeLevel >= 3)`. If cash-run, funds go to `(_sidePlayer) call WFBE_CO_FNC_GetCommanderTeam` via `ChangeTeamFunds`; if no commander, banked as side supply via `ChangeSideSupply`. Note the **design tradeoff**: on a cash run the side supply pool receives nothing — the value is diverted to commander team funds (plus the pilot's personal +25%). |
| Do labels/messages read sensibly for both? | **Yes.** | Label generalized to `LOAD SUPPLIES` (`Skill_Apply.sqf`); messages switch on `_byHeli` to read `"HELI"`/`"truck"` and append `" (cash run)"`; "truck" wording in load/too-far messages changed to "vehicle". |

### Net-new constants introduced by this PR

`Init_CommonConstants.sqf` gains `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES_T2`, `WFBE_C_SUPPLY_HELI_TYPES_T3`, `WFBE_C_SUPPLY_HELI_TYPES` (= T2+T3), and `WFBE_C_SUPPLY_VEHICLE_TYPES` (all supply-capable, used for the buy-menu highlight). These centralize what was previously a hard-coded classname array duplicated across `Skill_Apply.sqf` and `supplyMissionStart.sqf` — a genuine quality improvement.

### Cross-reference

This PR is built on the stable supply-mission flow documented in [Supply mission architecture](Supply-Mission-Architecture). It deliberately does **not** add AI-flown supply helicopters; that is gated by a separate, partially-broken AI logistics path — see the sharpened note in [Feature status register](Feature-Status-Register).

