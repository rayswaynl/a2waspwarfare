# Design: SPREAD + HOLD - capture tuning status

Fleet `wg2d9lgvs` (2 Explore analyses + synthesis), line-verified against build84 Chernarus.

## Build 86 live status (2026-07-02)

This design is implemented on the build84/cmdcon36 line. The sections below remain useful as the original
diagnosis and rollback notes, but they are no longer a pending morning patch.

Live anchors:
- `Common/Init/Init_CommonConstants.sqf:642` defaults `WFBE_C_AICOM2_FIST_TOWNS = 2`.
- `Common/Init/Init_CommonConstants.sqf:813-816` defaults spread and hold on: `WFBE_C_AICOM_SPREAD_MODE = 1`,
  `WFBE_C_AICOM2_FIST_PERTOWN = 4`, `WFBE_C_AICOM_HOLD_MODE = 1`, `WFBE_C_AICOM_HOLD_SECS = 180`.
- `Server/AI/Commander/AI_Commander_Allocate.sqf:237-239`, `:280-298` apply the cap-aware fist assignment.
- `Server/AI/Commander/AI_Commander_AssignTowns.sqf:247-265` preserves a live holder's assignment and clears stale latches.
- `Common/Functions/Common_RunCommanderTeam.sqf:1960-1984` claims the first-captor hold and emits `HOLD-CLAIM`.
- `Client/GUI/GUI_Menu_Command.sqf:393-411` and `Server/Functions/Server_HandleSpecial.sqf:664-704` already understand
  `wfbe_aicom_holding_town`.

Open follow-up:
- Soak a full commander round and confirm captures distribute across more than one front town, `HOLD-CLAIM` appears
  after flips, and owned-town count climbs instead of see-sawing at one town per side.
- Keep `NO-TOWN-UNCAPTURABLE.md` shelved unless post-soak evidence proves a specific town is still uncrackable; the
  old escalation design fights this spread cap by concentrating too many teams on one town.

## Historical design plan

**Context:** cmdcon40 CONFIRMED the AI captures towns (CAPTURED=6). Remaining live problems at match-min 60:
(A) **dogpile** — ~7 teams funnel onto ONE enemy town (Khelm); (B) **no hold** — every captor immediately
retargets+leaves → town flips back → see-saw → territory stuck at 1/side even with a 2:1 strength lead.
**Both are pure AICOM orchestration tuning — NO `server_town.sqf` change** (drain is linear in attackers;
the garrison system exists + re-arms on capture at `server_town.sqf:282-284`). Design only; implement in the
morning, all flag-gated for instant rollback.

## (1) SPREAD — distribute teams across 2-3 enemy towns
**Root is the ALLOCATOR, not AssignTowns.** With `WFBE_C_AICOM2_ALLOCATE_ENABLE=1` (live),
`AI_Commander_Allocate.sqf:270-271` funnels every offense team onto `_fist` with NO per-town cap, and
`WFBE_C_AICOM2_FIST_TOWNS=1` makes `_fist` a single town → the pile-up. (AssignTowns:457-464 honors the
Allocator and bypasses the legacy `_perTown` cap at L489.) Two levers, do BOTH:

**1a — widen the fist (config-only, primary)** `Init_CommonConstants.sqf:560`:
```
if (isNil "WFBE_C_AICOM2_FIST_TOWNS") then {WFBE_C_AICOM2_FIST_TOWNS = 2};  //--- was 1 (steamroller); 2-3 = spread front
```
Makes `Allocate.sqf:149-153` pick 2-3 top-scored front towns; the L270 nearest-in-reach pick then splits teams
by proximity. Least risk. But L270 still has no cap → pair with 1b.

**1b — per-town cap in the Allocator fist assignment (the real fix)** `AI_Commander_Allocate.sqf`:
- Before the `forEach _teams` loop (~L232, beside `_assigned = 0`):
```sqf
private ["_fistCounts"]; _fistCounts = []; { _fistCounts set [_forEachIndex, 0] } forEach _fist;
_capPerFist = missionNamespace getVariable ["WFBE_C_AICOM2_FIST_PERTOWN", 4];
```
- Replace the fist pick at **L270-271** (wrap `if (WFBE_C_AICOM_SPREAD_MODE>0){new}else{old}`): cap-aware
  nearest pick — skip a fist town already at cap; on overflow fall through to the LEAST-LOADED fist town so no
  team idles; increment `_fistCounts` for the chosen town. (A2-safe: `count`, array `set/select`, `distance`,
  `getVariable`.) Full snippet in fleet output `wg2d9lgvs`.

**Flags** `Init_CommonConstants.sqf` (~L560):
```
if (isNil "WFBE_C_AICOM2_FIST_PERTOWN") then {WFBE_C_AICOM2_FIST_PERTOWN = 4};  //--- max teams stacked per fist town before spilling
if (isNil "WFBE_C_AICOM_SPREAD_MODE")   then {WFBE_C_AICOM_SPREAD_MODE   = 1};  //--- 0 = legacy uncapped pile-up (rollback)
```
FIST_TOWNS=2 + FIST_PERTOWN=4 → a 7-team side puts ~4 on town A, ~3 on town B.

## (2) HOLD — first captor holds the town on DEFEND; others still retarget
Today the capture-success block `Common_RunCommanderTeam.sqf:1212-1227` has EVERY captor null its goto +
re-enter the towns gate → town empty → see-saw. Fix: the FIRST team to flip a town claims a short DEFEND hold
via a **latch on the town object** (`_townObj` is in scope on the HC; `_logik` is NOT — same locality caveat),
stamped with an expiry so it self-heals; later captors retarget as now.

**2a — capture block** (`Common_RunCommanderTeam.sqf:1212`, inside `if (_townFlipped)`): if
`WFBE_C_AICOM_HOLD_MODE>0` and `time > _townObj getVariable ["wfbe_aicom_hold_until",0]` → claim: set
`wfbe_aicom_hold_until = time + WFBE_C_AICOM_HOLD_SECS`, put THIS team on DEFEND at `getPos _townObj`
(`SetTeamMoveMode "defense"` + `SetTeamMovePos`), set `wfbe_aicom_holding_town = _townObj`, do NOT null the goto.
Else → the existing verbatim L1223-1227 release (retarget).

**2b — AssignTowns skip-retarget-for-holder** (before `AI_Commander_AssignTowns.sqf:187`): if the team has a
live `wfbe_aicom_holding_town` whose `sideID==_sideID` and `time < hold_until` → set `_explicitMode = true`
(the existing "don't auto-retarget" path the base-garrison block at L182 uses); else clear the latch → normal flow.

**Flags** `Init_CommonConstants.sqf`:
```
if (isNil "WFBE_C_AICOM_HOLD_MODE") then {WFBE_C_AICOM_HOLD_MODE = 1};    //--- 0 = every captor leaves (legacy see-saw)
if (isNil "WFBE_C_AICOM_HOLD_SECS") then {WFBE_C_AICOM_HOLD_SECS = 180};  //--- first captor holds the centre this long (garrison re-arm window)
```
**Why hold the captor, not spawn a garrison:** zero-spawn (no frametime spike / budget-cap conflict), reuses the
proven DEFEND path, keeps a body in the 40m ring so `server_town_ai.sqf` re-activation stays warm, self-releases.
Cost: 1 team tied ~180s per fresh capture — fine at 7 teams.

## (3) Mechanical blocker? NONE — garrison re-arms on capture; drain linear. Pure orchestration.

## (4) SHELVE `NO-TOWN-UNCAPTURABLE.md` — its escalation is the OPPOSITE of SPREAD
That design *raises* per-town quota to `MAXCONC=12` and keeps an escalated town in the pool → it deliberately
concentrates the whole army on one town = the dogpile, escalated. Its overflow-spread guard only triggers past
12 teams (never, at 7/side). **Marked SHELVED — superseded by SPREAD+HOLD.** HOLD + the cmdcon39 drain-wait
address "town won't fall" better. If post-soak a town is still genuinely uncrackable, re-scope escalation
narrowly as "+1-2 teams for ONE flagged town, capped well below the spread cap" — never 12.

## Rollback / boot-smoke
SPREAD off: `WFBE_C_AICOM2_FIST_TOWNS=1` + `WFBE_C_AICOM_SPREAD_MODE=0`. HOLD off: `WFBE_C_AICOM_HOLD_MODE=0`.
Files: `AI_Commander_Allocate.sqf:232,268-272`, `Init_CommonConstants.sqf:560`, `Common_RunCommanderTeam.sqf:1212-1227`,
`AI_Commander_AssignTowns.sqf:187`. Boot-smoke 0-errors, then soak: myTowns should climb past 1 (territory
accumulates), captures spread across 2-3 towns, see-saw stops.

> Also still relevant for the see-saw: the **dominant-side-not-pressing** gap (EAST 95 vs 40 str, posture=HOLD,
> 1 town) — once SPREAD+HOLD let territory accumulate, re-check whether the stance machine presses a 2:1 lead.
