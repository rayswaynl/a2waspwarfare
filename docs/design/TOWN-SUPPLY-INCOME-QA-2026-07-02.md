# Town Supply / Income QA - 2026-07-02

Lane: 61, town supply/income QA
Branch: `codex/61-town-supply-income-qa`
Base checked: `origin/claude/build84-cmdcon36@6f2fc4bd1`
Scope: docs-only source audit of town supply accrual, side-supply banking, player/team income display, supply mission credit, no-player stagnation, and maintained Chernarus/Takistan parity.

## Summary

The current default economy path is mostly coherent:

- Server town ticks use `GetTownsSupply`, gate ongoing town supply income with `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT`, and credit banked side supply through `ChangeSideSupply`.
- Banked side supply is clamped server-side by `Server_ChangeSideSupply.sqf` against `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT`, which is the live cap parameter from `Rsc\Parameters.hpp`.
- The RHUD supply-rate display mirrors the same town-supply gate used by the server tick.
- The headless-client phantom-player case is already documented and mitigated by reseating the HC to civilian before the no-player stagnation code counts `isPlayer` units.
- The core Chernarus and Takistan town-income files checked in this lane are byte-identical for the maintained roots.

Two follow-ups remain. One is a real server-trust boundary in the helicopter supply mission completion path. The other is a legacy-configuration risk: income systems 1/2 still rely on a client-local periodic player-money drip instead of the server/team payout path used by the default commander economy.

## Findings

| ID | Priority | Finding | Evidence | Recommended follow-up |
| --- | --- | --- | --- | --- |
| TSI-QA-01 | P2 | Helicopter supply mission completion trusts the side supplied by the client payload for side-pool and commander credit. | Truck auto-completion is server-originated as `[_playerObject, _associatedSupplyTruck, side _playerObject]` in `Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Module\supplyMission\supplyMissionStarted.sqf:103`, but helicopter unload sends `[player, _associatedSupplyTruck, sideJoined]` from the client in `Client\Module\supplyMission\supplyMissionUnload.sqf:70`. The server handler reads `_sidePlayer = _v select 2` in `Server\Module\supplyMission\supplyMissionCompleted.sqf:6-12`, then uses `_sidePlayer` for the completion broadcast, commander tithe, and `ChangeSideSupply` side-pool credit at lines 31-46. | In `supplyMissionCompleted.sqf`, derive the credited side server-side from the player object, group, loaded vehicle/source town, or server-side mission state. Reject null/non-player objects, invalid sides, and side mismatches before sending the completion message or calling `ChangeSideSupply`. |
| TSI-QA-02 | P3 | Legacy income systems 1/2 still pay player income through a client-local loop. This does not affect the default commander economy, but it makes those selectable systems harder to reason about and verify. | `Client\Init\Init_Client.sqf:862-864` starts `Client\FSM\resources_cli.sqf` only when `WFBE_C_ECONOMY_INCOME_SYSTEM` is not in `[3,4]`. That client FSM sums owned town supply and calls `ChangePlayerFunds` locally in `Client\FSM\resources_cli.sqf:12-20`. The server resource FSM separately pays non-player team leaders for systems 1/2 in `Server\FSM\updateresources.sqf:101-112`, while default system 3 uses the server commander/team path. | If systems 1/2 remain supported, move the periodic player payout to a server-authoritative path or explicitly mark systems 1/2 as legacy/local. While touching this path, make the system-2 half-income rounding match the displayed value from `Client_GetIncome.sqf`. |

## Verified Non-Findings

### Banked side-supply cap

`WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` is not the banked side-supply cap. The current comments in `Common\Init\Init_CommonConstants.sqf:1179-1184` correctly describe it as the town-income gate/reference ceiling. The banked cap is `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT`, sourced from `Rsc\Parameters.hpp:186-190` and enforced in `Server\Functions\Server_ChangeSideSupply.sqf:35-41`.

### Server town supply tick

`Server\FSM\updateresources.sqf` recalculates owned-town supply per side each tick (`GetTownsSupply` at line 65), applies the ongoing-income gate, and credits side supply via `ChangeSideSupply` at line 96. Currency-system/team-money branches are separate from the banked side-supply credit.

The later AI-commander funds branch can still run when `_supply >= _supply_max_limit`, but that branch is about AI commander cash/funds, not banked side-supply growth.

### RHUD supply-rate display

`Client\Client_UpdateRHUD.sqf:452-476` displays banked supply plus the expected per-tick rate. It uses `GetTownsSupply`, excludes GUER, and applies the same `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` gate before showing the `+rate`. That matches the server-side town supply tick.

### No-player stagnation and headless clients

`Common\Functions\Common_StagnateSupplyIncomeNoPlayers.sqf:38-70` counts `isPlayer` units by side and only tracks west/east no-player ticks. The historic HC issue is already covered by `Headless\Init\Init_HC.sqf:18-22` and the civilian reseat loop that keeps the HC out of WEST/EAST groups before the stagnation counter sees it.

### GUER economy scope

The server resource tick loops `WFBE_PRESENTSIDES - [resistance]`, so GUER is intentionally outside the west/east town supply and commander economy loop. GUER rewards/stipends use separate paths and were not changed in this lane.

### Chernarus/Takistan maintained-root parity

The following files were hash-checked between the maintained Chernarus and Takistan roots and matched:

- `Server\FSM\updateresources.sqf`
- `Client\FSM\resources_cli.sqf`
- `Common\Functions\Common_GetTownsIncome.sqf`
- `Common\Functions\Common_GetTownsSupply.sqf`
- `Common\Functions\Common_StagnateSupplyIncomeNoPlayers.sqf`

## Suggested Fix Shape

1. Patch `Server\Module\supplyMission\supplyMissionCompleted.sqf` so the handler treats the payload side as advisory at most.
2. Derive `_creditedSide` server-side, validate it is west/east or another explicitly supported side, and use only `_creditedSide` for completion messages, commander tithe, and `ChangeSideSupply`.
3. For helicopters, verify the associated vehicle still has positive `SupplyAmount`, still points at the expected `SupplyFromTown`, and is still near the credited side command center before crediting.
4. Decide whether systems 1/2 are still supported gameplay. If yes, move their periodic player income to the server/team path; if no, document them as legacy and avoid expanding test surface around them.

## Verification

- Reviewed maintained Chernarus source paths for town supply ticks, client income display, side-supply mutation, supply mission start/unload/completion, town initialization, capture bounties, RHUD economy display, marker display, and headless-client reseating.
- Hash-checked the core income/stagnation files against maintained Takistan paths.
- No mission source files changed in this lane.
- `LoadoutManager` was not run because this is a docs-only QA report.
