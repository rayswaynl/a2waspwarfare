# V2 Squad Micro Layer — per-unit orders inside existing groups

*Lane: claude-gaming (Fable) → execution items open to codex, stacked on #713's driver work.*
*Ray-approved 2026-07-04 ("1/2/3/4/5 i love these ideas"). GUIDE-REV GR-2026-07-03a applies.*

## The primitive

A2-OA lets a unit be ordered individually WITHOUT leaving its group: `doStop _u` detaches it
from formation-following (group membership, group cap, unit count all unchanged), `doMove`/
`orderGetIn`/`doWatch` steer it, `doFollow _u` returns it to formation. All of it must run on
the HC where the group is local (same locality rule as the existing order contract), issued
from the driver (`Common_RunCommanderTeam.sqf`) on the driver cadence — event-driven, never
per-frame.

## THE HARD RULE (non-negotiable)

**Every detached unit carries a TTL watchdog.** Snap-back via `doFollow` on: task complete,
timeout, leader dead, or team order change. A leaked `doStop` = a soldier frozen in a field
forever = the one thing we never ship (standing owner mandate). Any PR in this lane must show
the watchdog path in its diff.

## The five approved behaviors (build order)

1. **Camp-split capture** (FIRST — small, self-contained, serves Ray's #1 priority).
   On begin_capture at a 2+-camp town: split members across camps simultaneously, 2 units
   hold depot/center. Target: ~halve town capture time. Touches only the capture branch.
2. **Dismount/pickup choreography** (foundation the air lane reuses).
   Driver picks dismount point via garrison standoff (R-score data); infantry exits into
   cover positions (`doStop`+`doMove`) while the vehicle repositions; pickup = staggered
   `orderGetIn` with 2-unit overwatch. Heli variant: sequenced ejects + post-landing rally.
3. **Micro-retreat**: individual mauled units (low health/ammo) fall back to transport/rear
   while healthy members fight on; team disbands (50% salvage refund queued next patch) when
   below threshold and refit travel is too expensive.
4. **AT overwatch**: position the launcher carrier on the armor approach vector pre-assault.
   Movement micro only — do NOT micro targeting (COMBAT-mode leader AI fights you).
5. **Per-unit unstuck**: nudge the single wedged soldier instead of recycling the whole team's
   recovery machinery.

Perf: orders are one-shot engine calls; ~4-8 extra individual path solves per team per EVENT.
Watchdogs = array scans on driver cadence on the HCs (<1 fps there, zero on server). Items
2/3/5 are net FPS-POSITIVE (shorter fights, fewer standing units, cheaper recoveries).
Stagger simultaneous doMoves over 2 driver ticks on Zargabad (dense path mesh).

## Approved extensions (Ray 2026-07-04, second wave — build after the five above)

6. **Road-march pacing** — `setBehaviour "CARELESS"` + `setSpeedMode "FULL"` + `setFormation
   "COLUMN"` for transit legs; flip to `"COMBAT"`+`"WEDGE"` at standoff distance from the target
   (reuse the R-score standoff). COMBAT-mode bounding/crawling is a major cause of slow cross-map
   legs; this likely cuts transit time more than any routing fix shipped so far. Watchdog analog:
   the flip-to-COMBAT trigger must be unmissable (distance OR contact OR timeout) — a team that
   arrives at a defended town still CARELESS is dead.
7. **Fire discipline** — `enableAttack false` while mounted/in transit so transports DRIVE THROUGH
   contact instead of stopping to fight every patrol (re-enable at the objective); `setCombatMode
   "GREEN"` hold-fire for ambush/infiltration postures; `allowFleeing 0` on regulars so assaults
   don't rout mid-push.
8. **Economy of force** — `joinSilent` field-merge of two mauled teams into one full team
   (group-count reduction = the #1 server-FPS lever; natural partner of retreat-or-disband +
   the 50% salvage refund); `selectLeader` promotes the best survivor after losses (no panicking
   rifleman inheriting command); `setVehicleAmmo`/`setFuel` for depot refits without service
   infrastructure.
9. **Air insertion modes** — `_heli land "GET OUT"` (low hover drop) vs `land "LAND"` (full
   landing) vs para eject, plus `flyInHeight` for transit vs run-in. These are the three execution
   modes the insertion learner (owner ask: "learn where/when to land vs parachute") picks between —
   the learner chooses, these commands execute.

## Remaining primitive catalog (not yet scheduled; same cost class, A2-OA-verified, none banned)

Movement & pacing:
- `setBehaviour "CARELESS"` + `setSpeedMode "FULL"` + `setFormation "COLUMN"` for road
  marches → dramatically faster transit; flip to `"COMBAT"`+`"WEDGE"` at standoff distance.
- `limitSpeed` on lead vehicles = convoy cohesion; `forceSpeed` for synchronized assault release.

Fire discipline:
- `enableAttack false` on the group = leader stops auto-assigning targets → convoys DRIVE
  THROUGH contact instead of stopping to fight; re-enable at the objective.
- `setCombatMode "GREEN"/"BLUE"` = hold-fire: ambush teams that don't fire until sprung,
  infiltration approaches.
- `allowFleeing 0` on regulars (never rout mid-assault); leave militia flee-able for flavor.

Posture & perception:
- `setUnitPos "DOWN"/"MIDDLE"/"UP"` — prone overwatch, crouched assault, standing march.
- `doWatch` — sector watching for overwatch elements / the AT gunner on the approach vector.
- `knowsAbout`/`nearTargets` (HC-side) — live threat sensing feeding the R-score + ambush detect.

Air insertion knobs (the "how to land" half):
- `_heli land "GET OUT"` (low hover drop) vs `land "LAND"` (full landing) vs para eject —
  the three insertion modes the learner picks between; `flyInHeight` for transit vs run-in.
- `setUnloadInCombat` — stop cargo AI bailing under fire mid-transit.

Structure & economy:
- `join`/`joinSilent` — field-MERGE two mauled teams into one full team (group-count
  reduction; pairs with retreat-or-disband doctrine).
- `selectLeader` — promote the best survivor after losses; vehicle commander leads in transit.
- `buildingPos`/`nearestBuilding` — garrison units INSIDE buildings (towns feel occupied at
  zero extra units); capture micro clears building positions.
- `setVehicleAmmo`/`setFuel` — instant depot refit without service infrastructure.
- `setSkill [skill, value]` per-subskill (aimingAccuracy vs spotDistance vs courage) —
  veteran teams / garrison quality by town tier without adding units.

## Non-goals

No group splits (144/side cap), no new units, no per-frame loops, no targeting micro in
COMBAT mode, no defensive tasking for maneuver teams (owner ruling: commanders are
offense-only; garrisons are the defense layer).
