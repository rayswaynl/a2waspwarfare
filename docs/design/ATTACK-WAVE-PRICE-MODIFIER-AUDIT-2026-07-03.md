# Attack-Wave Price Modifier Audit - 2026-07-03

## Scope

Lane 99 tracks AI4, the historical risk that concurrent heavy attack waves
could clobber each other through a shared `ATTACK_WAVE_PRICE_MODIFIER` global.
This pass checked the current `claude/build84-cmdcon36` target and found the
lane already resolved in source. No mission source, generated terrain mirror,
package artifact, or live server state was changed.

## Verdict

Current target status: **already fixed on target**.

`Server/Functions/Server_AttackWave.sqf` computes a spawn-local discount and
publishes `ATTACK_WAVE_DETAILS = [_side, _discountPercentage,
_attackWaveLength]`. It does not stash the discount in the bare
`ATTACK_WAVE_PRICE_MODIFIER` server global during the active wave.

`Server/PVFunctions/AttackWave.sqf` receives the side-bearing details payload
and stores the modifier in side-specific state:

- `ATTACK_WAVE_WEST_PRICE_MODIFIER`
- `ATTACK_WAVE_EAST_PRICE_MODIFIER`

The server then sends the `"attack-wave"` client update only to the affected
side. Clients still keep a local `ATTACK_WAVE_PRICE_MODIFIER`, but that value is
side-targeted presentation/purchase state, not shared server truth.

## Evidence

| Path | Lines | Evidence |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AttackWave.sqf` | 19-29 | Comments document the AI4 fix; the active wave writes `_discountPercentage` into `ATTACK_WAVE_DETAILS` with `_side`, not into the bare price global. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AttackWave.sqf` | 39-42 | Wave end also publishes `[_side, 1, 0]` through `ATTACK_WAVE_DETAILS`, preserving the side key on reset. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/AttackWave.sqf` | 23-25 | The receiver unpacks `_side`, `_priceModifier`, and `_attackLength` from the details payload. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/AttackWave.sqf` | 32-38 | Active waves set `ATTACK_WAVE_ACTIVE_WEST` plus `ATTACK_WAVE_WEST_PRICE_MODIFIER`, or the EAST equivalents. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/AttackWave.sqf` | 42 | The active modifier is sent via `HandleSpecial` to `_side` only. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/AttackWave.sqf` | 50-58 | Wave end resets only the side-specific active flag/modifier and sends `_side` the return-to-1 update. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/HandleSpecial.sqf` | 226 | The client-local global is set from the side-targeted `"attack-wave"` payload. |

## Maintained Roots

The same side-specific receiver anchors are present in all maintained roots:

| Root | WEST modifier lines | EAST modifier lines |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus` | 8, 34, 52 | 12, 37, 55 |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | 8, 34, 52 | 12, 37, 55 |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad` | 8, 34, 52 | 12, 37, 55 |

`git diff --no-index` also found no Chernarus-vs-Takistan drift in
`Server/Functions/Server_AttackWave.sqf` or `Server/PVFunctions/AttackWave.sqf`.

## Boundary

Open draft PR #205 (`codex/136-attackwave-shape-guard`) is a separate lane. It
guards malformed `ATTACK_WAVE_DETAILS` payloads in the same receiver family, but
it does not own lane 99's historical shared-price-global question.

This audit also does not close broader direct-public-variable authority work.
`ATTACK_WAVE_INIT` requester validation, side membership, and forged supply
input remain outside this lane unless covered by a separate security PR.

## Verification

- Searched current `claude/build84-cmdcon36@b1608b096` for
  `ATTACK_WAVE_PRICE_MODIFIER`, `ATTACK_WAVE_WEST_PRICE_MODIFIER`,
  `ATTACK_WAVE_EAST_PRICE_MODIFIER`, and `"attack-wave"` send paths.
- Confirmed the only live `ATTACK_WAVE_PRICE_MODIFIER = (_args select 0)`
  assignments are client `HandleSpecial` receivers in the three maintained
  roots.
- Confirmed `Server/PVFunctions/AttackWave.sqf` side-specific modifier lines
  match across Chernarus, Takistan, and Zargabad.
- Changed-file scope is docs-only; LoadoutManager was not run because no
  mission source changed.
