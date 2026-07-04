# Design: AICOM aircraft - airfield spawn and research-gate status

**Ray (2026-07-02, live):** "I now own an airfield and the AI commander just spawns high-tier helicopters
at base. (1) They should spawn on the airstrip at the airport owned by the faction. (2) They should respect
factory levels — I had no Aircraft Factory 1 researched and it still built aircraft."

Fleet diagnosis `a2a87bb4` (read-only, validated against code). The original plan is preserved below as
historical context; the current live status follows first.

## Build 86 live status (2026-07-02)

Bug 1 is implemented. Bug 2 is still a balance/research-policy decision, not a safe one-line cleanup.

Live anchors:
- `Server/AI/Commander/AI_Commander_Teams.sqf:1078-1089` now detects any air template with `_isAirTeam` and
  sends helicopters as well as planes to an owned airfield.
- `Server/AI/Commander/AI_Commander_Teams.sqf:1092-1103` finds the owned airfield/hangar and prefers nearby `HeliH`
  pads for helicopter spawns while keeping runway heading / fly-start behavior plane-only.
- `Common/Init/Init_CommonConstants.sqf:380` still defaults `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI = 1`, so a held
  Aircraft Factory can waive the air research gate for helis.
- `Common/Init/Init_CommonConstants.sqf:388` still defaults `WFBE_C_AICOM_AIRFIELD_FREE_AIR = 1`, so a captured
  airfield can waive air research for airfield-origin air buys.
- `Server/AI/Commander/AI_Commander_Teams.sqf:289-353` contains the live airfield/free-buy and Aircraft Factory heli
  waiver logic, including template and per-unit AIR gate waivers.
- `Server/AI/Commander/AI_Commander_Teams.sqf:433-435` exempts air templates from the town-count strip when the
  captured-airfield or Aircraft Factory heli waiver applies.
- `Server/AI/Commander/AI_Commander.sqf:520-677` can eventually buy AIR through the wealth-driven upgrade sink, but
  that is not the deliberate Aircraft Factory research accelerator described in the original plan.

Open follow-up:
- Do not flip `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI` to `0` by itself; that risks suppressing AICOM helicopter
  use until AIR research happens through a separate path.
- If strict research gating is desired, pair the flag flip with a deliberate AIR research rule gated on held Aircraft
  Factory or captured airfield, then soak to prove AICOM still flies from the owned airfield.
- PR `#151` (`claude/cmdcon42-ah6x`) and PR `#172` (`claude/cmdcon42-tkair`) were merged into
  `claude/build84-cmdcon36` on 2026-07-02, so treat their aircraft roster/EASA changes as part of the current
  baseline rather than open blockers.
- Recheck current open PRs for aircraft/AICOM overlap at claim time before editing the live aircraft path.

Drift sweep note (2026-07-02):
- Lane 68 rechecked this doc, `SPREAD-AND-HOLD.md`, and `REAL-BASE-ASSAULT.md` against
  `origin/claude/build84-cmdcon36@6f2fc4bd10c8339fd13be087d327717ff58c85e8`. The spread/hold and real-base-assault
  live-status anchors still matched source; this file needed only the PR-state and line-anchor refresh above.

## Historical diagnosis

## Bug 1 — helis spawn at BASE, not the owned airfield
The founding spawn-position block `AI_Commander_Teams.sqf:1039-1066` gates the airfield relocation on
`_isJetTeam = ({_x isKindOf "Plane"} count _template) > 0` (line 1039/1050). Helis are `"Helicopter"`,
never `"Plane"`, so they never enter the airfield block → `_spawnPos` stays the base factory pad.
The owned/captured airfield is a town object carrying `wfbe_is_airfield` / `wfbe_hangar` /
`wfbe_airfield_hangar_obj`, tagged on capture in `server_town.sqf:312-329,560-573` (carriers
`Init_NavalHVT.sqf:306-318`); side match `(_x getVariable ["sideID",-1]) == _sideID`.

**Fix (2 small edits, A2-safe):**
- After `Teams.sqf:1039`, add a heli-OR-plane predicate:
  ```sqf
  private ["_isAirTeam"];
  _isAirTeam = ({(typeName _x == "STRING") && {_x isKindOf "Air"}} count _template) > 0;
  ```
  (`isKindOf "Air"` = the A2-OA superclass of Helicopter + Plane; the `typeName == "STRING"` guard mirrors
  the existing idiom at Teams.sqf:304.)
- Widen the relocation gate at `Teams.sqf:1050` from `if (_isJetTeam && {_hasAirfield})` to
  `if (_isAirTeam && {_hasAirfield})`. Inside, keep `_spawnPos = getPos _haObj` for all air.
  **Keep the runway-heading / FLY air-start (lines 1058-1064, dispatch arg 1079) PLANE-only** — a heli should
  spawn GROUNDED on the airfield pad (its existing `"FORM"` path in `Common_CreateTeam.sqf:130-144` is correct).
- Optional: for a heli, prefer an airfield `HeliH` pad — `_haObj nearObjects ["HeliH", 80]` → `getPos` that,
  fallback `getPos _haObj`, so it lands on tarmac.
- Optional defence-in-depth: the server-local refill path `Server_BuyUnit.sqf` (spawns at factory, line 32/55)
  could also route `isKindOf "Air"` refills to the airfield hangar pos. Not required — most AICOM air is founded.

Risk: LOW (additive predicate + one gate widen). Ships independently of Bug 2.

## Bug 2 — helis build without the aircraft factory being RESEARCHED
By design: `AI_Commander_Teams.sqf:278-290` sets `_airHeliWaive = _hasAirFactory && {WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI > 0}`
(default 1), and lines 305/310/320 waive the `WFBE_UP_AIR` research tier gate for helis whenever the side
HOLDS the aircraft-factory STRUCTURE. And the structure is built on town-count only (`AI_Commander_Base.sqf:404-414`,
`_ownTowns >= WFBE_C_AICOM_AIR_MIN_TOWNS` = 4), independent of research. So helis flow from a level-0
(unresearched) factory. High-tier selection is the price-weighted tier draw (`AI_Commander_AssignTypes.sqf:232-246`,
`WFBE_C_AICOM_TIER_BIAS_EXP` 1.5 → biases expensive hulls).

**Fix — respect the researched tier (needs a PAIRED change, do NOT flip alone):**
1. Set `WFBE_C_AICOM_AIR_FACTORY_ENABLES_HELI = 0` → helis must pass the normal `WFBE_UP_AIR` tier gate
   (Teams.sqf:310/320: template air-tier must be `<= (_upgrades select WFBE_UP_AIR)` → "only the tier the level
   allows" is then automatic; tier-1 heli needs `WFBE_UP_AIR >= 1`, etc.).
2. **CRITICAL PAIRING:** the AICOM research program currently NEVER queues an AIR upgrade (Teams.sqf:269-276
   comment). So flipping the flag ALONE suppresses AICOM air ENTIRELY (builds the factory, never researches it,
   never flies). Must ALSO add `WFBE_UP_AIR` (→ level 1, then higher) to the AICOM research queue in
   `AI_Commander.sqf`, gated on holding the aircraft factory. **OPEN ITEM: confirm the research-queue insertion
   point in `AI_Commander.sqf` before implementing** (not fully traced this pass).
3. Consider whether to also set `WFBE_C_AICOM_AIRFIELD_FREE_AIR = 0` (the captured-airfield free-buy waive).
   Keeping it = "hold the actual airfield → may fly", which matches Ray's intent (air comes from the owned airport).

Recommend gating the whole thing behind a flag so it's reversible; behind that, flip the heli-waive + add the
research step together, boot-smoke, and soak (confirm AICOM still eventually flies — from the airfield — after
researching air, not before).

## Key refs
Founding spawn pos (Bug 1): `AI_Commander_Teams.sqf:1039-1066`, dispatch `:1079`. Heli waive (Bug 2):
`AI_Commander_Teams.sqf:278-320`. Structure build gate: `AI_Commander_Base.sqf:404-414`. Tier draw:
`AI_Commander_AssignTypes.sqf:232-246`. Air cap: `Teams.sqf:426-459`. Upgrade const `WFBE_UP_AIR=3`:
`Init_CommonConstants.sqf:40`. Airfield tagging: `server_town.sqf:312-329,560-573`.
