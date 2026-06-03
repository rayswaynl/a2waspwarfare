# Resistance Supply Scaffold

This page owns the current resistance/GUER supply scaffold status. It is a routing and owner-decision page, not a claim that resistance economy is live.

## Current Status

| Area | Status |
| --- | --- |
| Common supply helper shape | `Common_ChangeSideSupply.sqf` formats `wfbe_supply_temp_<side>` generically, and `Common_GetSideSupply.sqf` plus constants contain GUER/resistance scaffolding. |
| Server temp-channel receivers | `Server_ChangeSideSupply.sqf` registers west/east temp-channel public-variable handlers, but no resistance temp-channel receiver is currently documented as live. |
| Economy-side owner logic | Source Chernarus lacks `WFBE_L_GUE` as a present economy-side owner logic in the current feature-status trace. |
| Live support posture | Partially scaffolded but effectively unsupported for live economy play. |

## Owner Decision

| Option | Gate |
| --- | --- |
| Keep dormant | Leave the scaffold documented as unsupported and avoid surfacing resistance economy in player-facing flows. |
| Revive | Add `wfbe_supply_temp_resistance`, validate side/amount payloads, establish the resistance economy owner logic and smoke three-way supply reads/writes. |
| Remove | Delete or comment stale resistance supply affordances after confirming no supported scenario depends on them. |

## Validation Pack

| Check | Expected evidence |
| --- | --- |
| West/east regression | Existing west/east supply temp-channel updates still work after any helper changes. |
| Resistance channel | Resistance updates have their own handler and cannot be spoofed through west/east channels. |
| Owner logic | GUER/resistance supply reads and writes resolve to an intentional owner, not a missing logic object. |
| Three-way smoke | West, east and resistance values remain independent during a local mission smoke. |

## Continue Reading

Previous: [Feature status register](Feature-Status-Register) | Next: [Economy authority first cut](Economy-Authority-First-Cut)

Main map: [Home](Home) | Risk register: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
