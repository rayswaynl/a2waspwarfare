# Resistance Supply Scaffold

Status: partially scaffolded, effectively unsupported for live economy play. This page owns the source evidence for the resistance/GUER side-supply gap.

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

This is not a clean "unsupported by design" feature. The common economy layer contains resistance/GUER scaffolding:

- `Init_CommonConstants.sqf:157-159` defines starting supplies for west, east and GUER.
- `Common_GetSideSupply.sqf:36-48` can read resistance supply.
- `Init_Common.sqf:274-282` builds `WFBE_PRESENTSIDES` from `WFBE_L_BLU`, `WFBE_L_OPF` and `WFBE_L_GUE` when side owner logics exist.

But the server temp-channel receiver is only wired for west/east:

- `Common_ChangeSideSupply.sqf:28-30` formats a generic `wfbe_supply_temp_<side>` public variable.
- `Server_ChangeSideSupply.sqf:1-23` registers `wfbe_supply_temp_west`.
- `Server_ChangeSideSupply.sqf:25-47` registers `wfbe_supply_temp_east`.
- No `wfbe_supply_temp_resistance` handler is registered.

Source Chernarus also does not define `WFBE_L_GUE` as a present economy-side owner logic in `mission.sqm`; it has resistance start/respawn markers, but no present-side owner logic matching west/east.

## Why It Matters

If resistance remains only a defender/ambient side, the missing temp channel is mostly latent. If a map or feature adds `WFBE_L_GUE` or enables a true three-way resistance economy, resource ticks can reach `ChangeSideSupply` through `Server/FSM/updateresources.sqf:49,72`, but the resulting `wfbe_supply_temp_resistance` event has no server PVEH to consume it.

That creates a silent economy failure: code can appear to award or debit resistance supply, while the server never applies the change.

## Evidence

| File | Evidence |
| --- | --- |
| `Common/Functions/Common_ChangeSideSupply.sqf:16-30` | Applies positive-income stagnation, computes `_change`, then publishes `wfbe_supply_temp_<side>` with `[_side, _amount, _reason]`. |
| `Server/Functions/Server_ChangeSideSupply.sqf:1-47` | Registers west/east temp-channel handlers only; both trust payload `_side` and broadcast resulting side supply. |
| `Server/Init/Init_Server.sqf:82` | Compiles/registers `Server_ChangeSideSupply.sqf`. |
| `Common/Functions/Common_GetSideSupply.sqf:36-48` | Contains resistance supply read branch. |
| `Common/Init/Init_CommonConstants.sqf:157-159` | Defines west/east/GUER starting supply constants. |
| `Common/Init/Init_Common.sqf:274-282` | Builds `WFBE_PRESENTSIDES` from BLU/OPF/GUE owner logics. |
| `mission.sqm:3855,3874` | Defines BLU/OPF owner logics. |
| `mission.sqm:4621,4839` | Contains resistance start/respawn markers, but not a `WFBE_L_GUE` owner logic. |

## Patch Shape

If resistance economy is intentionally enabled:

1. Add and register a `wfbe_supply_temp_resistance` server PVEH.
2. Validate the payload side; do not accept a west/east payload on the resistance channel or vice versa.
3. Clamp negative floors and overspend behavior consistently with west/east.
4. Make resistance side logic ownership explicit in mission setup.
5. Add three-way economy smoke before enabling any true resistance commander/economy mode.

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
