# AI Supply-Truck Net-New Design

Date: 2026-07-12
Fleet task: wasp-ai-supplytruck-net-new-20260712
Owner ruling: d022, AUTHOR-NET-NEW-DEFAULT-OFF
Design base: origin/master@1270b0a0e5d9a915c8215d40332ea52afd876485

## Decision

Build one bounded, server-owned AI logistics convoy per WEST/EAST side behind
WFBE_C_AI_SUPPLY_TRUCK_ENABLE, default 0. Implement it as an explicit SQF state
worker by replacing the dead body of Server/AI/AI_UpdateSupplyTruck.sqf. Do not
create or call a new FSM.

The legacy worker is not an implementation to revive. Its three maintained
terrain copies are byte-identical (SHA-256
00FA442CE88E21CE5F8DD275C01357CF870C8E8AD8311C942E46B3EA633BEB98, Git blob
52fe36176922af4e1f653da5f4b73866f4d824f2) and only poll a maximum before
calling the missing Server/FSM/supplytruck.fsm. No reachable Git object or ref
contains that FSM. Commit fb3084c28e989f5eefe128b6b430f34182ace375 explicitly
disabled the path; its compile was already commented in the parent.

This is the design-first gate. It changes no runtime behavior and authorizes no
live deploy, restart, merge, or flag flip.

## Mechanic boundary

Current source contains two different mechanics with similar names:

1. Classic truck-economy mode is WFBE_C_ECONOMY_SUPPLY_SYSTEM == 0. Help text
   says to reload at the MHQ or Service Point, drive to a town, and raise that
   town's Supply Value. Automatic town-SV growth in server_town.sqf runs only
   in mode 1.
2. The newer SpecOps mission is the reverse trip: a player client stamps cargo
   at a town and brings it to a Command Center for side supply, cash, personal
   rewards, and supply-run statistics.

The AI convoy belongs to the first mechanic. It raises an owned town's
supplyValue. It never calls the player completion path, never sets SupplyAmount
or SupplyFromTown, and never emits a supply-run, delivery, or synthetic-UID
statistic. Canonical unit/vehicle killed handlers remain intact, so ordinary
combat attribution for destroying convoy assets is intentionally unchanged.

## Activation disclosure

Truck mode is not currently selectable in Rsc/Parameters.hpp. Every maintained
mission assignment sets WFBE_C_ECONOMY_SUPPLY_SYSTEM to 1. Therefore the new
feature flag alone cannot activate V1.

A flag-1 evaluation also needs an explicit, owner-authorized mode-0 test preset
or test-only constant override. That preset is separate from this feature
commit and must not be smuggled into a production/default change. The runtime
worker still double-gates on both the feature flag and mode 0.

## Enablement and bounds

The worker may start only when all of these are true:

- the new flag is positive;
- supply mode is 0 (trucks);
- the AI commander is enabled;
- the side is WEST or EAST;
- townInit is complete;
- the side has a living, deployed HQ;
- an owned, non-contested, land-based, non-naval town is below maxSupplyValue;
- eight additional non-player AI fit below the existing side-AI ceiling;
- one additional group fits below WFBE_C_AICOM_GROUP_CAP.

Use the already-published population tier/caps. Do not count HCs as players and
do not add a player-count statistic. The old forced maximum of five is legacy
provenance, not the V1 limit. Five eight-person convoys would add forty AI per
side. V1 is strictly one convoy per side.

## Ownership and registry

The whole lifecycle stays local to the dedicated server:

- create the group with WFBE_CO_FNC_CreateGroup;
- create the truck and crew with canonical mission helpers;
- found exactly eight living AI: one driver and seven escorts/cargo;
- lock the truck against player entry before publishing it;
- immediately define server-local wfbe_trashable=false, then publish the
  truck into the side registry before any yield or client-visible stamp; the
  collector treats the variable's presence, not its boolean value, as owned;
- stamp the group wfbe_persistent=true and wfbe_ai_supply_group=true;
- stamp the truck wfbe_ai_supplytruck=true with broadcast enabled as a client
  affordance, not as server authority;
- prune only objNull registry entries; every non-null managed hull, alive or
  dead, remains cleanup-owned and blocks replacement until safely deleted;
- treat server-local membership in a WEST/EAST registry as authoritative;
- never append the group to wfbe_teams or stamp wfbe_aicom_hc;
- never transfer the group to an HC.

This keeps allocator/team KPIs uncontaminated and leaves HC architecture
unchanged. Ordinary combat stats from canonical killed handlers remain; there
are no AI delivery/player-reward/HC-stat rows.

## Lifecycle

The explicit phases are:

WAIT -> SPAWN -> RELOAD -> OUTBOUND -> DELIVER -> RETURN -> RELOAD

CONTACT is a temporary overlay on either travel leg. Every phase has a bounded
timeout and a single cleanup owner. Common_TrashObject consults the same
server-local WEST/EAST registry authority before removing handlers and again
immediately before deletion. A registry member is handed back to the lifecycle;
RequestOnUnitKilled remains unchanged and therefore completes ordinary combat
attribution, statistics, and bounty flow.

### WAIT and SPAWN

Prune objNull registry entries first. Any non-null registry member, alive or
dead, remains lifecycle-owned and blocks replacement until it is safely deleted
or confirmed objNull. Re-check the flag, mode, AICOM, side-AI, group-cap, HQ,
and eligible-town gates immediately before creating anything. If any gate fails, wait on the bounded supervisor cadence without
creating new state.

Preserve HEAD's existing truck-mode compatibility baseline when the feature is
off: side logic still initializes wfbe_ai_supplytrucks to an empty array and
emits the existing legacy-disabled warning verbatim. Gate the new worker and
AISUPPLY transitions; do not rewrite that flag-off baseline.

Create the configured WFBE_%1SUPPLYTRUCK near the living HQ, then create one
persistent server-local group and enough side soldiers to reach eight. Put one
in the driver seat and the others in cargo where seats exist. Any partial
creation failure goes directly to exact-once cleanup and leaves no vehicle,
unit, group, or live registry entry.

### RELOAD and target selection

Select one reloadAnchor for the current cycle: prefer an alive friendly Service
Point when the existing structure lookup supplies one, otherwise use the living
deployed HQ. Use that same anchor for the return leg. A short dwell represents
reload without inventing a player cargo variable.

Choose an owned, non-contested, land-based town with supplyValue below
maxSupplyValue. Prefer the largest SV deficit, using objective distance only
as a deterministic tie-breaker. Offshore/naval-HVT towns are ineligible.

### OUTBOUND and DELIVER

Lay a live MOVE route with the existing waypoint helper. Arrival radius is a
town-centre gameplay rule, not a simulation gate. On arrival, atomically
re-check:

- truck and driver still live and no player occupies the hull;
- the town is still owned by the convoy side;
- the town is not contested or naval;
- supplyValue and maxSupplyValue are numeric;
- current SV is still below its cap;
- this trip token has not already delivered.

Clamp the side's Supply Rate upgrade index into the valid
WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK array range, then apply:

after = min(maxSupplyValue, before + truckRate)

Broadcast the town's new supplyValue once and latch the trip token before the
DELIVER log. No direct side-bank award occurs.

### RETURN

Return to the selected reloadAnchor, revalidating it during the leg. If that
anchor dies, recompute once from the current Service Point/HQ state. A driver
death may reseat one living escort once. At the anchor, clear the trip token,
dwell, and select the next deficient town.

HQ loss/undeploy, town loss, immobility, leg timeout, flag/mode/AICOM change,
or game over enters cleanup. Do not teleport a working convoy.

## Contact doctrine

Transit posture is SAFE / YELLOW / NORMAL / COLUMN. Install A2-OA-safe
FiredNear and Hit handlers on server-local convoy entities. Both handlers must
validate a live hostile-side source; friendly fire, the convoy's own fire, and
collision-only hits do not latch CONTACT.

On first validated hostile contact:

- set AWARE / RED / FULL;
- allow escorts to dismount and fight;
- keep a live route and grant bounded contact grace;
- emit one CONTACT transition.

After the latch expires with no live hostile contact, remount survivors where
possible, restore transit posture, reissue the route, and emit one CLEAR
transition. Contact never spawns reinforcements.

There is no player-proximity enablement, enableSimulation toggle, hide/show
path, background sim manager, or distance-based activation. Objective arrival
and hostile-contact radii are gameplay semantics, not sim gating. Antistack is
untouched.

## Economy and caps

The immediate delivery cap is each town's maxSupplyValue. Raising town SV feeds
the existing aggregation in Common_GetTownsSupply.sqf and updateresources.sqf.

The real side-bank ceiling remains lobby parameter
WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT in Rsc/Parameters.hpp (default 50,000), enforced
by the existing server supply handler. Do not edit it and do not confuse it
with WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT, which is an income gate/reference
rather than the bank clamp.

The convoy never calls plain server-side ChangeSideSupply. Apart from being the
wrong V1 mechanic, that helper publishes through publicVariableServer, which
does not fire the server's own PVEH. Any future direct bank-credit design needs
WFBE_SE_FNC_HandleSideSupplyChange and a separate owner decision.

## Cleanup and administrative respawn

One lifecycle owner clears persistence, removes handlers, deletes managed AI and
a safe server-local hull, confirms the hull objNull, removes that registry entry,
and deletes the empty group. Cleanup is idempotent across partial spawn, death, timeout,
HQ loss, ownership flip, feature/mode change, and game over. Generic trash never
becomes a second hull owner: its early registry fence covers normal calls, while
its pre-delete fence catches a call that began before lifecycle registration.
The worker keeps wfbe_trashable defined and retains registry membership until the
hull is deleted locally or confirmed objNull; it never prunes a non-null dead
current truck merely because alive is false.

The truck is locked and the server rejects player crew/cargo. As a final safety
fence, cleanup never deletes a player-occupied or non-server-local hull. Test
player occupancy without an alive filter because dead player crew can remain in a
wreck. If impossible/stale state shows either condition, emit one throttled
ABORT, defer deletion, keep wfbe_trashable plus the registry ownership latch, and
retry after the player leaves/locality returns; never transfer cleanup authority
and never add a TTL that can force-delete an occupant.

RequestSpecial carries no authenticated sender identity. Appending client-
supplied player/team objects cannot secure RespawnST because a malicious client
can nominate the real commander object. V1 therefore retires remote RespawnST
while the new feature is enabled:

- the Economy GUI disables the control and sends no request;
- the server rejects every remote RespawnST request when the feature is on;
- the lifecycle's timeout/death/driver-reseat cleanup is the only recovery path;
- feature flag 0 preserves HEAD's legacy empty-list behavior.

A future remote control requires a separate server-minted, targeted-private,
compare-and-consume capability bound to owner/UID plus an atomic cooldown.

## Player supply-mission boundary

Maintained WEST/EAST AI truck classes are also accepted by the player load
action. The broadcast wfbe_ai_supplytruck stamp provides the client message,
but it is not a security boundary.

Server-side guards must check authoritative membership in both WEST/EAST
side-logic wfbe_ai_supplytrucks registries:

- the client load action rejects the broadcast stamp for immediate UX;
- supplyMissionStarted rejects registry members before cooldown, killed-EH, or
  cargo mutation;
- the top of WFBE_SE_FNC_HandleSupplyMissionCompleted rejects registry members
  before stats, economy, messages, or vehicle-state mutation, closing the
  direct completion-PV bypass.

The AI convoy never enters player cargo, cooldown, interdiction, completion,
personal reward, or supply-run-stat paths.

## Planned runtime file set

1. Common/Init/Init_CommonConstants.sqf: register the new default-zero flag.
2. Common/Functions/Common_TrashObject.sqf: defer twice to authoritative
   registry ownership, before handler removal and immediately before deletion.
3. Server/AI/AI_UpdateSupplyTruck.sqf: replace the dead launcher with the
   explicit server-owned lifecycle; remove the missing ExecFSM dependency.
4. Server/Init/Init_Server.sqf: compile, preserve the flag-off empty registry
   and warning, and double-gate one worker for each present WEST/EAST side.
5. Client/Module/supplyMission/supplyMissionStart.sqf: reject stamped AI trucks
   for immediate client UX.
6. Server/Module/supplyMission/supplyMissionStarted.sqf: reject authoritative
   registry members before any start-side mutation.
7. Server/Module/supplyMission/supplyMissionCompleted.sqf: reject authoritative
   registry members at the central handler entry before every side effect.
8. Client/GUI/GUI_Menu_Economy.sqf and
   Server/Functions/Server_HandleSpecial.sqf: disable/reject remote RespawnST
   while the feature is enabled; preserve flag-off behavior.
9. Tools/Lint/test_ai_supply_truck_contract.py: static default-off, authority,
   registry, no-FSM, no-player-cargo, and SV-clamp contract tests.

Only Chernarus source is edited directly. LoadoutManager generates Takistan and
Zargabad mirrors. Rsc/Parameters.hpp is not changed by this task.

## Acceptance gates

- Flag 0 has zero behavioral delta versus HEAD: preserve the existing empty
  registry initialization and legacy warning; produce no worker, convoy,
  AISUPPLY transition, object/group/SV delta, or new statistic.
- Flag 1 with automatic supply mode produces no worker or convoy.
- Flag 1 plus an explicit owner-authorized mode-0 test preset produces exactly
  one locked, server-local eight-person convoy per eligible WEST/EAST side,
  with no HC ownership or wfbe_teams entry.
- Valid delivery raises only a still-owned town by the clamped truck-rate
  index, never beyond maxSupplyValue, and cannot replay a trip token.
- Ownership flip before arrival yields no SV increase.
- Valid hostile contact produces one escalation and one clear; friendly/self
  events do not latch, and no units appear.
- Driver death reseats once; repeated death, timeout, HQ loss, and game over
  return managed units, vehicles, groups, handlers, and registry to baseline.
- No client can remotely invoke RespawnST while the feature is enabled.
- Players cannot load, start, or directly complete a supply mission with an AI
  convoy; the server check uses registry membership.
- No AI supply-run/delivery/synthetic-UID statistic appears. Canonical ordinary
  combat kill attribution remains unchanged, while generic trash defers both
  before handler removal and before deletion for authoritative registry members.
- A forged client UX stamp alone never suppresses generic cleanup; a flag flip,
  dead player in crew, or non-local hull retains lifecycle ownership until safe.
- No missing supplytruck.fsm call, sim/distance gating, antistack edit, direct
  bank mint, HC-stat path, deployment, restart, or live mutation.
- Full SQF lint, delimiter/CRLF checks, LoadoutManager generation, CH/TK/ZG
  parity, flag-off checks, and independent review pass before draft PR/Fleet
  completion.

## Telemetry

Use one always-on transition family and no per-tick spam:

AISUPPLY|v1|side|minute|SPAWN/DISPATCH/CONTACT/CLEAR/DELIVER/RETURN/ABORT/CLEANUP|...

DELIVER records town, before, after, max, rate, and trip token.
ABORT/CLEANUP record reason plus remaining crew/vehicle/group counts.
HC identifiers, delivery stats, and synthetic player fields are absent.
