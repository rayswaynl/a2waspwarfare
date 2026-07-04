# Lane 251: Endgame Economy Stats No-Change

<!-- GUIDE-REV: GR-2026-07-03a -->

## Verdict

No mission source change is included in this lane.

Build84 already exposes the player's end-of-round economy snapshot in the endgame screen:
score, current funds, and income per minute are rendered through `PlayerSummaryText`.
The side-wide economy counters assumed by the lane prompt, such as
`westSupplySpent` and `eastSupplySpent`, do not exist in the live lane. Adding a UI
read for absent `WF_Logic` variables would create misleading zero or nil-derived
text instead of real economy totals.

## Evidence

| Surface | Finding |
| --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf` | `PlayerSummaryText` is read at IDC `90010`; the summary uses `GetPlayerFunds` and `GetIncome` before rendering score, funds, and income. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/GUI/GUI_EndOfGameStats.sqf` | Mirror has the same player-summary path. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/GUI/GUI_EndOfGameStats.sqf` | Mirror has the same player-summary path. |
| `Rsc/Titles.hpp` on all three terrains | `EndOfGameStats` includes `PlayerSummaryText` with IDC `90010`. |
| Mission-source grep | No current source hit for `westSupplySpent`, `eastSupplySpent`, `supplySpent`, or `WFBE_C_ENDGAME_ECONOMY_STATS`. |

The existing side stats in `GUI_EndOfGameStats.sqf` are the already-maintained
unit and vehicle created/lost counters. There is no server-side accumulator for
side-wide supply or funds spent totals to display beside them.

## Why This Is A No-Change Lane

The prompt's simple UI change assumes pre-existing `WF_Logic` counters:

```sqf
WF_Logic getVariable "westSupplySpent"
WF_Logic getVariable "eastSupplySpent"
```

Those counters are not present. A credible implementation needs a server-side
accounting lane first, not a cosmetic UI read. That lane should define:

- The authoritative mutation points for player, commander, AI team, upgrade,
  wildcard, and supply-spending paths.
- Whether the totals mean funds spent, supply spent, or both.
- How resistance/GUER and neutral economy events should be counted.
- Whether totals are only endgame UI data or also part of the match-report and
  soak telemetry surfaces.
- A default-off UI flag such as `WFBE_C_ENDGAME_ECONOMY_STATS` only after the
  counters exist and have trustworthy semantics.

## Validation

- Refreshed against `claude/build84-cmdcon36` before this branch.
- Checked open PRs, remote branches, and wiki worklog/status before claiming
  lane 251.
- Confirmed no current mission-source hits for the requested side economy
  counters or flag.
- Inspected the Chernarus, Takistan, and Zargabad endgame GUI paths for the
  existing player score/funds/income summary.
- No SQF or mission-source files changed; LoadoutManager was not required.

## Out Of Scope

- Server economy accumulators.
- Stats flush or match-report schema changes.
- Endgame GUI or `Rsc/Titles.hpp` edits.
- Constant/default registration for a future UI flag.
