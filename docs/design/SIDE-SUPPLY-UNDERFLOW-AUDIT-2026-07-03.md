# Side-Supply Underflow Audit - 2026-07-03

Lane: fleet lane 74, SG3
Base checked: `origin/claude/build84-cmdcon36@b1608b096`

## Scope

The fleet prompt flags the old side-supply clamp bug where an overdraw could
turn into a supply windfall. The historical shape was:

`_change = _currentSupply - _amount`

When `_amount` was negative and larger than the current balance, that fallback
added supply instead of flooring the balance at zero.

This pass checks the current target's side-supply helper and authoritative
server handler across the three maintained roots:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad`

No mission source, generated mirror output, live runtime settings, package
artifacts, side-supply balance values, or economy defaults are changed here.

## Verdict

Lane 74 is already fixed on the current target.

`Common_ChangeSideSupply.sqf` no longer tries to compute the authoritative
post-change value. It publishes structured side-supply data through the temp
public variable channel, and the server handler recomputes the new value.

`Server_ChangeSideSupply.sqf` now applies the expected arithmetic:

`_change = _currentSupply + _amount`

It then floors negative results to zero and caps values at
`WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT`. That means a spend/overdraw amount can no
longer become a positive supply grant through the old subtraction fallback.

The prompt's line references are stale for this target: the code comments mark
the B66 removal of dead helper clamp arithmetic and the server-side floor at 0.

## Evidence Table

| Surface | Evidence | Result |
| --- | --- | --- |
| Common helper arithmetic | `Common/Functions/Common_ChangeSideSupply.sqf:20-22` states that dead helper clamp arithmetic was removed, and `:24-26` only publishes `[_side, _amount, _reason]` through `wfbe_supply_temp_%1`. | The old client/common-side `_currentSupply - _amount` fallback is gone from the live path. |
| Server payload shape guard | `Server/Functions/Server_ChangeSideSupply.sqf:9-30` rejects non-array payloads, short payloads, non-`SIDE` sides, channel/side mismatches, and non-scalar amounts. | Malformed side-supply payloads do not reach the arithmetic branch. |
| Server arithmetic | `Server/Functions/Server_ChangeSideSupply.sqf:37-41` reads current supply, defaults nil to 0, computes `_change = _currentSupply + _amount`, floors `_change < 0` to 0, and caps `_change > _maxSupplyLimit`. | The SG3 underflow/windfall shape is fixed. |
| Side channels | `Server/Functions/Server_ChangeSideSupply.sqf:53-64` registers west, resistance, and east temp-channel handlers. | The B67 GUER side-supply channel is present alongside west/east. |
| Fix lineage | `git log -S"_currentSupply - _amount"` points to `6de5626b9` (B66) and `7e29f801c` (B67) before later build folds. `git log -S"floor supply at 0 on overdraw"` points to the same B66/B67 lineage plus the Build 83 fold. | Current target includes the consolidated B66/B67 side-supply fix history. |

## Out Of Scope

This audit is distinct from lane 37, which handled side-supply public-state
publication by explicit key. It is also distinct from broader economy authority
lanes such as direct-PV requester validation. This lane only checks the SG3
arithmetic underflow/windfall bug and the immediate server-side guards around
that calculation.

No claim is made here about the balance design of individual callers, town
supply rates, GUER supply economy pacing, or future sender-authority hardening.

## Verification

- `rg` confirmed the current side-supply arithmetic is `_currentSupply +
  _amount` followed by `_change < 0` floor-to-zero and max-supply capping in
  Chernarus, Takistan, and Zargabad.
- `rg` confirmed `Common_ChangeSideSupply.sqf` only publishes structured temp
  payloads and no longer performs the dead helper clamp calculation.
- `rg` confirmed server-side malformed payload, short payload, side type,
  channel mismatch, and amount type guards are present in all three roots.
- `git diff --no-index` confirmed Chernarus/Takistan parity for both checked
  side-supply files; Chernarus/Zargabad parity was checked the same way.
- This PR is docs-only. LoadoutManager was not run because no mission source or
  generated mirror source changed.
