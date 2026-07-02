# No-Town-Uncapturable Follow-through (lane 67)

Source base: `origin/claude/build84-cmdcon36@24604e9f74a1f67b23727748327fc2f35c8aecf6`

## Verdict

Do not implement the old no-town escalation ladder on the current live line.

`NO-TOWN-UNCAPTURABLE.md` is already marked shelved and superseded by
`SPREAD-AND-HOLD.md`. The live mission source has the SPREAD+HOLD anti-dogpile
defaults and follow-through logic enabled, while the old escalation constants
and `TARGET_ESCALATE` event are absent from mission source. Adding the shelved
ladder now would reintroduce the concentrated-team behavior SPREAD+HOLD was
created to avoid.

## Evidence

| Area | Current finding |
| --- | --- |
| Shelved design | `docs/design/NO-TOWN-UNCAPTURABLE.md` opens with the 2026-07-02 warning that the design is superseded by `SPREAD-AND-HOLD.md`; it keeps only the drain verdict and says to re-scope narrowly after SPREAD+HOLD soak if a specific town is proven uncrackable. |
| Replacement design | `docs/design/SPREAD-AND-HOLD.md` marks SPREAD+HOLD live on the build84/cmdcon36 line and lists only soak follow-up as open. |
| Defaults | `Common/Init/Init_CommonConstants.sqf:642` sets `WFBE_C_AICOM2_FIST_TOWNS = 2`; `:811-816` enables stall advance, spread, per-town cap, and hold defaults; `:836` keeps journey commit enabled. |
| Allocator | `Server/AI/Commander/AI_Commander_Allocate.sqf:233-280` builds per-fist counts and uses the cap-aware nearest pick when `WFBE_C_AICOM_SPREAD_MODE > 0`. |
| AssignTowns follow-through | `Server/AI/Commander/AI_Commander_AssignTowns.sqf:247-266` honors active hold claims; `:328-342`, `:409-454`, and `:598-617` use per-team and side blacklist/abandon logic with an empty-pool guard so a team can retarget instead of idling forever. |
| Captor hold | `Common/Functions/Common_RunCommanderTeam.sqf:1968-1984` lets the first captor hold a newly flipped town and emits `HOLD-CLAIM`. |
| Uncapturable release | `Common/Functions/Common_RunCommanderTeam.sqf:2018-2027` releases empty uncapturable depots and retargets; it does not escalate extra teams onto the same town. |
| Escalation absence | Targeted source search finds no `WFBE_C_AICOM_ESCALATE_*` constants or `TARGET_ESCALATE` event in mission source. The remaining escalation text is the shelved design note, while unrelated source hits are patrol escalation variables. |

## What Remains Valid

- The old drain conclusion remains useful: capture drain is linear, so there is
  no current evidence-backed reason to change `server_town.sqf` for this lane.
- The next proof should be runtime soak, not implementation: confirm captures
  distribute across more than one front town, `HOLD-CLAIM` appears, owned-town
  count climbs, and `TARGET_ABANDON` stays low and isolated.
- If soak shows a specific town is still genuinely stuck after SPREAD+HOLD, open
  a new narrow lane with RPT evidence for that town.

## Do Not Implement From The Shelved Ladder

- Do not add `WFBE_C_AICOM_ESCALATE_*` defaults to the live mission.
- Do not raise concentration toward the old 12-team per-town ceiling.
- Do not rename or convert `TARGET_ABANDON` into `TARGET_ESCALATE`.
- Do not change `server_town.sqf` without fresh runtime proof that the drain
  model is the actual fault.

## If Future Soak Proves A Town Is Genuinely Stuck

Re-scope as a tiny, default-off follow-up: add only +1 or +2 temporary teams for
one flagged town, keep the cap below the current SPREAD cap behavior, cite the
RPT evidence in the PR, and update all map variants through the normal
LoadoutManager path if mission source changes are required.

This lane made no mission source changes and requires no Takistan mirror
generation.
