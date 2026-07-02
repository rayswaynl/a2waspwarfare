# Victory Paths QA - 2026-07-02

Lane: 64, victory paths QA
Base checked: `origin/claude/build84-cmdcon36@ff4641a38`
Scope: docs-only audit of the live match-end path. No mission source was changed because the current branch has already fixed the older winner-inversion/double-fire class, and the remaining issues need an owner decision on victory-mode semantics.

## Summary

The live target no longer matches the older June victory atlas in the most important ways. `Server/FSM/server_victory_threeway.sqf` now computes `_winSide`, sends the winner side to clients, writes `WF_Winner`, emits `WASPSTAT ROUNDEND`, and calls `WFBE_CO_FNC_LogGameEnd` with the same winner side (`server_victory_threeway.sqf:167-198`). `Client/Client_EndGame.sqf:5-11` also documents that the payload is the winner and no longer inverts it.

Victory startup and shutdown are still owned by the same server FSM: `Init_Server.sqf:955-956` starts `Server\FSM\server_victory_threeway.sqf`, `initJIPCompatible.sqf:102` initializes `WFBE_GameOver`, and the end tail waits `WFBE_C_ENDGAME_HOLD` before `failMission "END1"` (`server_victory_threeway.sqf:208-249`). Chernarus and generated Takistan copies are identical for the checked victory path files on this base.

## Findings

| ID | Severity | Finding | Evidence | Recommended follow-up |
| --- | --- | --- | --- | --- |
| VICT-QA-01 | P2 | The lobby `Victory Condition` parameter is not the match-end authority. Selecting Annihilation, Assassination, Supremacy or Towns does not select a corresponding server victory mode. | `Rsc/Parameters.hpp:358-363` exposes `WFBE_C_GAMEPLAY_VICTORY_CONDITION` with four choices and default `2`. The fallback is set at `Common/Init/Init_CommonConstants.sqf:1285`. The victory FSM does not read that variable; current references are the repair-HQ action gate at `Common/Init/Init_Unit.sqf:65` and no match-end branch. The match-end FSM instead reads legacy `WFBE_C_VICTORY_THREEWAY` at `server_victory_threeway.sqf:3` and then uses fixed HQ/factory, all-towns and territorial triggers at lines `54-159`. | Decide whether the parameter is intended to be live. Either wire it deliberately into match-end semantics with explicit smoke cases, or rename/remove it from the player-facing lobby surface and document that current victory is supremacy plus territorial dominance. |
| VICT-QA-02 | P2 | If a side is both eliminated and satisfies all-towns or territorial victory in the same 80-second poll, the town/territorial branch wins because trigger priority is implicit. | The award condition is a single OR at `server_victory_threeway.sqf:159`: own HQ dead plus zero factories, or all towns, or `_terrWin`. In the branch body `_terrWin` wins first (`:167-171`), then `_towns == _total` wins (`:173-174`), and only otherwise does the code treat the evaluated side as the loser (`:175-177`). | Split the trigger booleans and encode owner-approved priority. If "HQ gone and cannot recover is finished" remains the rule, own-elimination should trump same-tick all-towns/territorial completion. If territory is meant to trump, document that rule in briefing/wiki and smoke the edge. |
| VICT-QA-03 | P3 | The win logger is still two-side defensive code. This is not a live GUER victory bug today, but it is fragile if future victory modes ever allow resistance to win. | `Server_LogGameEnd.sqf:14-18` maps every non-west winner to west as the loser. Current winner detection excludes `WFBE_DEFENDER` (`server_victory_threeway.sqf:119,200`), while the client stats banner already has a resistance label at `GUI_EndOfGameStats.sqf:8-9`. | Either add an explicit resistance branch/unsupported assertion in `Server_LogGameEnd.sqf`, or keep future GUER-win modes blocked at the server award path. |

## Verified Non-Findings

- The old winner/loser inversion is fixed on this target. `_winSide` is selected at `server_victory_threeway.sqf:167-178`, broadcast at line `179`, stored at line `186`, logged in `WASPSTAT` at line `195`, and passed to `WFBE_CO_FNC_LogGameEnd` at line `198`.
- Same-tick double award is guarded in the current Chernarus/Takistan path. The side loop exits when `WFBE_GameOver` is already true (`server_victory_threeway.sqf:129-132`), and the award condition also requires `!WFBE_GameOver` at line `159`.
- The old `WFBE_C_VICTORY_THREEWAY` non-zero trap no longer disables standard victory detection. `_victory` is still assigned at `server_victory_threeway.sqf:3`, but the old `_victory == 0` gate is gone.
- Territorial victory is implemented, not only documented: defaults live at `Init_CommonConstants.sqf:868-870`, clock start/milestone/broken handling lives at `server_victory_threeway.sqf:54-120`, and completed clocks feed the existing award block through `_terrWin`.
- Chernarus and generated Takistan are identical for `server_victory_threeway.sqf`, `Client_EndGame.sqf`, `GUI_EndOfGameStats.sqf`, and `Server_LogGameEnd.sqf` on this base.

## Suggested Source Shape

Keep a future source lane small:

1. Introduce named booleans in `server_victory_threeway.sqf`: `_sideEliminated`, `_sideWonAllTowns`, `_sideWonTerritorial`.
2. Encode explicit priority before assigning `_winSide`.
3. Add one log line that names the winning trigger for smoke review.
4. Treat `WFBE_C_GAMEPLAY_VICTORY_CONDITION` separately: either make it authoritative, or remove/retire the misleading lobby row.
5. If source changes touch Chernarus mission files, run `Tools\LoadoutManager\dotnet run -c Release` and remove package artifacts.

## Verification

- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only QA lane.
- Key Chernarus/Takistan victory files were hash-checked and matched on `origin/claude/build84-cmdcon36@ff4641a38`.
