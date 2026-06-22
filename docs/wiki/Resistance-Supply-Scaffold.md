# Resistance Supply Scaffold

Status: branch-sensitive scaffold, not release-ready live economy support. This page owns the source evidence for the resistance/GUER side-supply gap and the B69/B74 Chernarus-only candidate.

All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## What To Read

- `Common/Functions/Common_ChangeSideSupply.sqf`
- `Server/Functions/Server_ChangeSideSupply.sqf`
- `Common/Functions/Common_GetSideSupply.sqf`
- `Common/Init/Init_CommonConstants.sqf`
- `Common/Init/Init_Common.sqf`
- `Server/FSM/updateresources.sqf`
- `mission.sqm`
- [Economy authority first cut](Economy-Authority-First-Cut)
- [Server authority migration map](Server-Authority-Migration-Map)

## Current Shape

This is not a clean "unsupported by design" feature. The common economy layer contains resistance/GUER scaffolding, but the runtime support differs by branch:

- `Init_CommonConstants.sqf:157-159` defines starting supplies for west, east and GUER.
- `Init_Common.sqf` builds `WFBE_PRESENTSIDES` from `WFBE_L_BLU`, `WFBE_L_OPF` and `WFBE_L_GUE` when side owner logics exist.
- Current stable, B69 and adjacent B74 define `WFBE_L_GUE` owner logic in Chernarus and maintained Vanilla; docs/Miksuu/perf/historical refs checked here do not.
- Current stable, B69 and adjacent B74 make the resistance supply read branch non-blocking and funds-only by returning a `0` default, while docs/Miksuu/perf/historical refs still use the blocking `REQUEST_SUPPLY_VALUE` wait path for resistance.

The write path is still incomplete unless the target branch is B69/B74 Chernarus:

- `Common_ChangeSideSupply.sqf:28-30` formats a generic `wfbe_supply_temp_<side>` public variable.
- Current stable, docs/Miksuu/perf/historical refs and B69/B74 maintained Vanilla register only `wfbe_supply_temp_west` and `wfbe_supply_temp_east`.
- B69/B74 Chernarus registers `wfbe_supply_temp_resistance` at `Server_ChangeSideSupply.sqf:25-45`, but it still trusts `_side` from the payload and has no channel/requester validation.

## Current Branch Matrix

| Ref | Resistance owner logic | Supply read behavior | Temp-channel receiver |
| --- | --- | --- | --- |
| Docs branch `e46a7330` | No `WFBE_L_GUE` mission logic found in Chernarus or maintained Vanilla; Chernarus only has `WFBE_L_BLU` / `WFBE_L_OPF` at `mission.sqm:3855,3874`. | Resistance branch still reaches `REQUEST_SUPPLY_VALUE` / `waitUntil` at `Common_GetSideSupply.sqf:36-44`. | West/east only at `Server_ChangeSideSupply.sqf:1,25`; no resistance handler. |
| Current stable `origin/master@0139a346` | Chernarus `mission.sqm:4928,4931` and Vanilla `mission.sqm:4198,4201` define `LocationLogicOwnerResistance` / `WFBE_L_GUE`; `Init_Common.sqf:290` includes it in the present-side loop. | `Common_GetSideSupply.sqf:36-40` marks GUER funds-only and returns a non-blocking `0` default. | West/east only at `Server_ChangeSideSupply.sqf:1,25`; no resistance handler; arithmetic floor still old-shape at `:12,36`. |
| Current Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f`, historical `a96fdda2` | No `WFBE_L_GUE` mission logic found in checked maintained roots; only the `Init_Common.sqf:280` present-side loop references the variable. | Resistance branch still uses the blocking request/wait path at `Common_GetSideSupply.sqf:36-44`. | West/east only. Perf fixes Chernarus arithmetic only, not Vanilla and not resistance wiring. |
| Current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` | B69..B74 has no checked side-supply path delta. Chernarus and maintained Vanilla define `WFBE_L_GUE` and include resistance in the present-side loop. | Chernarus and Vanilla use the current-stable funds-only `0` default read branch. | Chernarus adds `wfbe_supply_temp_resistance` at `Server_ChangeSideSupply.sqf:25-45` and floors west/resistance/east negatives to `0` at `:12,36,60`; maintained Vanilla remains west/east only and old-shape at `:12,36`. |

## Why It Matters

If resistance remains only a defender/ambient side, the missing temp channel is mostly latent. If a map or feature adds `WFBE_L_GUE` or enables a true three-way resistance economy, resource ticks can reach `ChangeSideSupply` through `Server/FSM/updateresources.sqf:49,72`, but the resulting `wfbe_supply_temp_resistance` event has no server PVEH to consume it.

That creates a silent economy failure: code can appear to award or debit resistance supply, while the server never applies the change.

## Evidence

| File | Evidence |
| --- | --- |
| `Common/Functions/Common_ChangeSideSupply.sqf:16-30` | Applies positive-income stagnation, computes or forwards the change depending on branch, then publishes `wfbe_supply_temp_<side>` with `[_side, _amount, _reason]`. |
| `Server/Functions/Server_ChangeSideSupply.sqf:1-47` | Docs/current-stable/Miksuu/perf/historical refs register west/east temp-channel handlers only; both trust payload `_side` and broadcast resulting side supply. |
| B69/B74 Chernarus `Server/Functions/Server_ChangeSideSupply.sqf:25-45` | Adds a resistance temp-channel handler, but still trusts payload `_side`; B69/B74 Vanilla does not carry this handler. |
| `Server/Init/Init_Server.sqf:82` / current-stable `:98` / B69/B74 Chernarus `:100` | Compiles/registers `Server_ChangeSideSupply.sqf`; B69/B74 Vanilla uses `:98`. |
| `Common/Functions/Common_GetSideSupply.sqf:36-44` | Docs/Miksuu/perf/historical refs still block on the request/wait branch for resistance. Current stable/B69/B74 use `:36-40` to return a funds-only `0` default instead. |
| `Common/Init/Init_CommonConstants.sqf:157-159` | Defines west/east/GUER starting supply constants. |
| `Common/Init/Init_Common.sqf:280` / current-stable `:290` / B69/B74 `:291` | Builds `WFBE_PRESENTSIDES` from BLU/OPF/GUE owner logics. |
| Docs branch `mission.sqm:3855,3874` | Defines BLU/OPF owner logics but no `WFBE_L_GUE` owner logic in checked Chernarus source. |
| Current stable/B69/B74 Chernarus `mission.sqm:4928,4931`; Vanilla `:4198,4201` | Defines `LocationLogicOwnerResistance` / `WFBE_L_GUE`, so resistance can be present even while the write/read supply economy remains incomplete. |

## Patch Shape

If resistance economy is intentionally enabled:

1. Add and register a `wfbe_supply_temp_resistance` server PVEH on every target maintained root, or explicitly scope B69-style work as Chernarus-only.
2. Validate the payload side and channel; do not accept a west/east payload on the resistance channel or vice versa.
3. Clamp negative floors and overspend behavior consistently with west/east.
4. Decide whether the resistance read branch should remain a funds-only `0` default or return live `wfbe_supply_resistance` state.
5. Make resistance side logic ownership explicit in mission setup.
6. Add three-way economy smoke before enabling any true resistance commander/economy mode.

If resistance economy is not intended:

1. Document resistance supply as unsupported.
2. Guard or log any call that tries to mutate resistance side supply.
3. Avoid adding `WFBE_L_GUE` owner logic casually.

## Validation

Source-only:

- Search proves whether `wfbe_supply_temp_resistance` exists.
- Search proves whether `WFBE_L_GUE` owner logic is present in the mission being tested.
- Direct-channel validation covers side and amount.

Arma smoke, only if resistance economy is enabled:

- Resistance supply increases from town/resource income.
- Resistance supply debits do not become windfalls.
- West/east temp channels still work.
- JIP clients see the expected current supply values.

## Continue Reading

Previous: [Economy authority first cut](Economy-Authority-First-Cut) | Next: [Server authority migration map](Server-Authority-Migration-Map)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
