# Victory Winner Audit

Date: 2026-07-02
Lane: 135 - victory logs the loser as winner
Branch: `codex/lane135-victory-winner-audit`
Base: `claude/build84-cmdcon36`

## Verdict

Lane 135 is already fixed on the current target. No source change is needed.

The prompt row described `server_victory_threeway.sqf` as persisting or announcing the losing side as
the winner, with Chernarus only partially patched and Vanilla/Takistan still stale. Current source has
the winner-side correction in both maintained roots, and the client outro and match-end logger consume
the corrected winner payload.

## Evidence

- Chernarus `Server/FSM/server_victory_threeway.sqf:160-176` explicitly distinguishes the evaluated side from the real winner: town/territorial wins keep `_winSide = _x`, while HQ-loss wins flip west/east because `_x` is the defeated side.
- Takistan `Server/FSM/server_victory_threeway.sqf:160-176` has the same winner-selection block.
- Chernarus/Takistan `Server/FSM/server_victory_threeway.sqf:179-198` passes `_winSide` into the endgame client event, `WF_Winner`, WASPSTAT `ROUNDEND`, and `WFBE_CO_FNC_LogGameEnd`.
- Chernarus/Takistan `Client/Client_EndGame.sqf:5-8` documents that the incoming payload is already the winner and no longer inverts west/east.
- Chernarus/Takistan `Server/Functions/Server_LogGameEnd.sqf:7-12` reads the first argument as `_winnerTeam` and logs that team as the match winner.
- Chernarus/Takistan `Server/Functions/Server_LogGameEnd.sqf:22-34` increments the `_winnerTeam` profile counter and initializes the opposite `_loserTeam` counter to zero when missing.
- `git diff --no-index` shows the Chernarus and Takistan copies of `server_victory_threeway.sqf`, `Client_EndGame.sqf`, and `Server_LogGameEnd.sqf` match for this lane's relevant files.
- `docs/PATCHLOG-EXPERITAL.md:67` already records the victory log fix as shipped.

## Scope Notes

- No mission source was changed.
- This does not re-run lane 64's broader victory-path QA; it only checks the stale loser-as-winner claim.
- `Server_LogGameEnd.sqf` still uses legacy `*_WIN_CHERNARUS` profile keys and the "on Chernarus" summary string in both roots. That is a separate map-label/stat-key cleanup, not evidence of loser/winner inversion.
- No LoadoutManager run was needed because this is docs-only.

## Suggested Smoke

Owner/operator smoke in a disposable match:

- Force or observe a WEST win by total towns, and confirm the endgame banner, `WF_Winner`, WASPSTAT `ROUNDEND`, and `LogGameEnd.sqf` all name WEST.
- Force or observe an EAST win by destroying WEST HQ plus factories, and confirm the same four surfaces name EAST rather than WEST.
- Repeat once on Takistan to confirm the maintained Vanilla root follows the same winner payload.
