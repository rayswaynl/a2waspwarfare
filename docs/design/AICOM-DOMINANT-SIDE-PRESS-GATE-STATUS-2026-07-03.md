# AICOM Dominant-Side Press Gate Status Audit - 2026-07-03

Lane: fleet lane 93, docs-only status audit
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Scope

The prompt row asks for a dominant-side press gate: split garrison vs maneuver
strength and gate PRESS on maneuver mass so a territorial leader with depleted
garrisons can still attack.

This pass checks current target-branch source and records status only. It does
not edit mission source because `AI_Commander_Strategy.sqf` is a hot/open-PR
AICOM surface.

## Verdict

Lane 93 is partially implemented on the checked target, but not in the literal
shape requested by the prompt row.

What exists:

- Raw `_myStr` is treated as maneuver strength.
- A territory-credited effective strength (`_myEff = _myStr + towns * townStr`)
  is used for posture telemetry and related anti-stall/round-closer logic.
- Garrison bodies are counted and emitted in POSTURE/STALL telemetry.
- Dominant-but-passive stall streaks can trigger an HQ-strike override.

What does not exist as a distinct source concept:

- No reusable "garrison strength vs maneuver strength" split object.
- No generic PRESS order-routing change that consumes garrison-vs-maneuver
  strength outside the Strategy posture/telemetry/round-closer block.

So the current target addresses the dominant-side freeze through territory
credit, telemetry, and HQ-strike override machinery. It does not implement a
fresh, separate garrison-vs-maneuver PRESS gate that should be duplicated.

## Evidence

| Surface | Current target evidence | Status |
| --- | --- | --- |
| Original problem statement | `B57-SOAK-PROPOSALS.md:103-115` records the 6:1 town leader freezing in DEFEND because raw maneuver strength fell below the concentrated enemy, and proposes either a garrison/maneuver split or town-dominance aggression weighting. `:305-311` repeats that the lever is decoupling PRESS from total strength, not changing garrison strength or economy. | Documented |
| Raw maneuver strength | `Server/AI/Commander/AI_Commander_Strategy.sqf:58-80` comments that `_myStr` is maneuver strength, sums live non-remnant team bodies, and computes `_enStr` from enemy teams. | Present |
| Last-stand effective strength | `AI_Commander_Strategy.sqf:83-84` already gates last-stand on effective strength (`_lsMyEff`, `_lsEnEff`) using `WFBE_C_AICOM_TOWN_STRENGTH`. | Present |
| Raw HQ-strike gate | `AI_Commander_Strategy.sqf:686-688` still has raw `_myStr/_enStr` HQ-strike entry/hysteresis gates. | Still present |
| Relative round-closer | `AI_Commander_Strategy.sqf:691-713` adds a relative round-closer and stall override using effective strength and a sustained dominant-stall streak. | Present |
| Sticky strike | `AI_Commander_Strategy.sqf:716-726` keeps HQ_STRIKE committed while effective strength still dominates, plus a minimum hold window. | Present |
| Posture effective strength | `AI_Commander_Strategy.sqf:952-960` computes `_myEff`/`_enEff` from raw strength plus town credit and uses it for DEFEND/HOLD/PRESS posture telemetry. The local comment calls this a posture gate only. | Present, local posture |
| Losing-side overlap | `AI_Commander_Strategy.sqf:963-979` is the lane 89 losing-side PRESS floor, using `_myEff >= 0.8 * _enEff` and base-threat checks. | Separate related path |
| Garrison telemetry | `AI_Commander_Strategy.sqf:982-995` counts `garBodies` from town occupation teams and emits it in POSTURE telemetry. The source comment says this is pure observation. | Present, telemetry-only |
| Dominant stall telemetry | `AI_Commander_Strategy.sqf:999-1020` increments `wfbe_aicom_stall_streak` when a side has sustained town dominance and emits STALL telemetry only for the passive subset. | Present |
| Constants | `Common/Init/Init_CommonConstants.sqf:480-489` defines relative round-closer/stall-override knobs; `:599` defines `WFBE_C_AICOM_HQSTRIKE_MIN_HOLD=600`; `:1047` defines `WFBE_C_AICOM_TOWN_STRENGTH=2`. | Present |

## Maintained-Root Parity

The relevant source copies match across the maintained roots checked:
`Missions/[55-2hc]warfarev2_073v48co.chernarus`,
`Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`, and
`Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad`.

| File | SHA-256 in Chernarus/Takistan/Zargabad |
| --- | --- |
| `Server/AI/Commander/AI_Commander_Strategy.sqf` | `BEC4C40780D8C3440A7170C4059CFA741F581720F600BB91F652829DF57F8806` |
| `Common/Init/Init_CommonConstants.sqf` | `0259B5AFC676AEC0397EE962AD6E4C8C9F72BB70329C6C0E6E4BC00138D7F29C` |

Compact scan counts also match across all three roots:

| Root | `TOWN_STRENGTH` def | `_myEff` refs | `_enEff` refs | `garBodies` refs | POSTURE logs | STALL logs | Stall streak refs | strat-mode writes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Chernarus | 1 | 9 | 9 | 5 | 1 | 1 | 5 | 4 |
| Takistan | 1 | 9 | 9 | 5 | 1 | 1 | 5 | 4 |
| Zargabad | 1 | 9 | 9 | 5 | 1 | 1 | 5 | 4 |

## BI Command References

The relevant Arma 2 OA command family is the standard variable, group/unit
counting, alive-state, and logging API used by the existing code:

- https://community.bistudio.com/wiki/getVariable
- https://community.bistudio.com/wiki/setVariable
- https://community.bistudio.com/wiki/units
- https://community.bistudio.com/wiki/alive
- https://community.bistudio.com/wiki/count
- https://community.bistudio.com/wiki/diag_log
- https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands

## Recommendation

Treat lane 93 as partially covered on `claude/build84-cmdcon36`. Do not add a
second set of effective-strength or stall-override logic on top of the current
Strategy code.

If more behavior is still desired, the follow-up should be a coordinated AICOM
source lane that first decides where the value should be consumed:

- posture telemetry only,
- `wfbe_aicom_strat_mode`/HQ-strike state,
- allocator target choice,
- or team assignment/order routing.

Runtime validation should watch POSTURE and STALL telemetry for `myStr`,
`enStr`, `myEff`, `enEff`, `garBodies`, and `HQ_STRIKE_STALL_OVERRIDE` events in
a match where one side reaches a large town lead.

## Verification

- Read `CLAUDE.md` and `JOURNAL.md` before the audit.
- Scanned lane 93 prompt text, active wiki claims, recent events, and open PRs
  before claiming the lane.
- Scanned Strategy raw-strength, effective-strength, posture, garrison-body,
  stall-streak, and HQ-strike override paths.
- Verified `AI_Commander_Strategy.sqf` and `Init_CommonConstants.sqf` have
  matching SHA-256 hashes across maintained roots.
- Verified this lane is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
