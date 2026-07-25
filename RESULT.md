# Territorial victory countdown chip — result

- PR: [#1422](https://github.com/rayswaynl/a2waspwarfare/pull/1422)
- Branch: `codex/territorial-hud-20260725`
- Commit: `49f4889faf`
- Live server: not deployed; the flag remains at its default `0`.

## Files touched

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_victory_threeway.sqf`
- The same three files mirrored byte-for-byte to maintained Takistan and Zargabad roots.
- `Tools/Lint/test_territorial_hud_contract.py`

## Existing variables read

The new server publication reads:

- `WFBE_PRESENTSIDES`
- `WFBE_DEFENDER`
- `WFBE_C_VICTORY_TERRITORIAL`
- `WFBE_C_VICTORY_TERRITORIAL_MINS`
- `WFBE_TERRITORIAL_CLOCK_<sideID>`

The client maps the published side ID with:

- `WFBE_C_WEST_ID`
- `WFBE_C_EAST_ID`
- `WFBE_C_GUER_ID`

New state introduced by this PR is limited to `WFBE_C_TERRITORIAL_HUD` (default `0`) and the single public snapshot `WFBE_TERRITORIAL_HUD` (`[sideID, endTime]`).

## Verification

- Contract tests: `3/3` passed.
- Added-line SQF lint/trap gate: `0 findings`.
- LoadoutManager propagation completed with `A2WASP_SKIP_ZIP=1`.
- TK/ZG LoadoutManager dry-run: `drift: none`.
- CH/TK/ZG version-template verifier: PASS.
- CH/TK/ZG feature-file parity: confirmed.
- No `_MISSIONS.7z`, `nul`, line-ending churn, or live deployment.

## Limitations

No in-engine Arma 2/OA runtime session was available in this lane, so the HUD placement and clock display were validated through source contracts, A2 lint gates, mirror parity, and independent review rather than a live render.
