# AICOM V2 Behaviour Spec 415: Movement

Status: final-form research/spec for later implementation. No gameplay code.
Scope: AI commander movement decisions for town attacks, reinforcements, staging, bypassing, retreat, and route recovery.

## Doctrine Fit

Movement in V2 must make AI teams look committed and opportunistic without becoming psychic. The commander should commit to a plan, move with a readable intent, refuse fair fights when a better angle exists, remember punishment, and keep the map alive with no dead air. Movement must be explainable from known intel, town ownership, force state, and recent contact only.

The movement layer is not a micro-pathfinding rewrite. It is a strategic and tactical intent layer over existing Arma 2 OA group movement commands and Warfare routines. Builders must stay inside A2 OA 1.64 syntax and avoid all A3-only commands listed in `AGENTS.md` GUIDE-REV `GR-2026-07-03a`.

## Desired V2 Behaviour

1. Teams receive a movement intent, not just a destination:
   - `probe`: move toward a likely weak town or flank route, break off if contact is too strong.
   - `commit`: attack a selected town or enemy route until a timeout, retreat trigger, or objective transition.
   - `reinforce`: move to a friendly town, MHQ area, or active defense hotspot.
   - `interdict`: move to cut enemy travel, supply, or likely reinforcement lines based on observed contact.
   - `retreat`: leave a losing fight toward a survivable fallback, not to a random far objective.

2. Movement should use staging:
   - Pick a staging position outside direct objective center when committing to a town.
   - Advance from staging to assault only after enough local group mass exists, timeout expires, or enemy weakness is observed.
   - Do not churn between staging and objective every cycle. Use a minimum intent hold time.

3. Movement must avoid fair frontal repeats:
   - If the same approach vector caused heavy losses recently, mark that vector as punished.
   - Try a different flank, adjacent town, or interdiction target before repeating the same lane.
   - If no alternate exists, commit visibly rather than oscillating.

4. Movement must remain non-psychic:
   - Enemy positions used for movement must come from known contact, town capture state, base/MHQ public knowledge, or recent friendly loss reports.
   - Do not route around an unseen minefield, unit stack, or base defense unless V1 already has legitimate knowledge.

5. Movement must keep pressure alive:
   - If no valid attack target exists, choose a probe, reinforcement, or interdiction movement.
   - AICOM should never idle because the perfect target is unavailable.

## V2 Layer Contract

- Strategic director selects an intent and target family.
- Movement planner translates that intent into a destination, staging radius, timeout, and retreat fallback.
- Existing executor routines issue A2 OA-compatible move/waypoint/order commands.
- Memory layer records recent route punishment by side, source town, target town, approximate approach sector, and expiry.
- Explainability layer logs one always-on transition line per team intent change and verbose diagnostics only through `WFBE_CO_FNC_LogContent`.

## V1 Evidence To Keep

Use these anchors as implementation homes and guardrails:

- `Common/Init/Init_CommonConstants.sqf`: append any feature flags and numeric tuning defaults here only.
- `version.sqf`: `WF_LOG_CONTENT` gates verbose `WFBE_CO_FNC_LogContent`; do not use `WF_Debug` for verbose movement dumps.
- `initJIPCompatible.sqf:72`: HC forces LogContent on, so verbose movement output can become noisy on HC if not explicitly bounded.
- `docs/AGENT-HANDBOOK.md`: use the A2 OA command/trap taxonomy before selecting any movement command.
- `Tools/Soak/README.md`: soak reporting is the acceptance surface for dead air, churn, and RPT health.
- Existing global/client hotkey convention lives in `Client/Init/Init_Client.sqf`; movement explain/debug hotkeys, if ever added, belong in a separate later UI lane, not in this behaviour spec.

Keep V1 strengths:

- Current Warfare terrain ownership and town lists are the source of objective truth.
- Existing group-level move execution should remain the executor; V2 should provide better targets and state, not replace every waypoint primitive.
- Existing side/team ownership data should remain authoritative for legal targets and friendly fallback positions.

## V1 Behaviour To Fix

- Objective churn: teams repeatedly change destination before they can create contact or pressure.
- Dead air: teams wait because no ideal target passes filters.
- Fair-fight loops: teams re-enter the same losing approach without memory.
- Overreaction: every contact report can pull teams away from strategic pressure.
- Non-explainable moves: RPT does not show why a team abandoned or selected a target.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_MOVEMENT = 0`

Append it only to `Common/Init/Init_CommonConstants.sqf`. With the flag at `0`, mission files must be byte-identical in behaviour and generated mirrors.

Recommended parameters under the same constants section:

- `WFBE_C_AICOM_V2_MOVE_INTENT_MIN_SEC`: minimum seconds before changing a non-emergency movement intent.
- `WFBE_C_AICOM_V2_MOVE_STAGING_MIN`: minimum distance from objective center for staging.
- `WFBE_C_AICOM_V2_MOVE_STAGING_MAX`: maximum distance from objective center for staging.
- `WFBE_C_AICOM_V2_ROUTE_MEMORY_SEC`: expiry for punished route memory.
- `WFBE_C_AICOM_V2_MOVE_DEAD_AIR_SEC`: maximum time a live AI team may hold no useful movement intent.

Do not introduce new classnames. Do not use `WFBE_C_SIM_GATING`; it is owner-rejected.

## Target Selection Rules

Movement target scoring should consider:

- Distance from current team or assigned town.
- Strategic value of the target town.
- Known enemy pressure nearby.
- Friendly pressure nearby.
- Recent losses on the same route.
- Whether the move creates an unfair advantage: flank, isolation, reinforcement timing, or base pressure.

Movement target scoring must not consider:

- Unspotted enemy unit positions.
- Exact enemy composition unless observed or inferred from legitimate public state.
- Future player intentions.

Tie-breakers should prefer action over idleness:

1. Reinforce active friendly defense if a friendly town is under real pressure.
2. Commit to a vulnerable enemy or neutral town.
3. Probe a flank or adjacent town.
4. Interdict a route with recent contact.
5. Relocate toward a better staging area.

## State Model

Each AI commander team should have a compact movement state:

- Current intent.
- Intent start time.
- Target town or target position.
- Staging position.
- Fallback position.
- Last meaningful contact time.
- Last movement progress sample.
- Punished route key and expiry if applicable.

Use mission namespace or existing team variables consistently with V1 patterns. If storing on a group, do not use group `getVariable [name, default]`; `AGENTS.md` requires `WFBE_CO_FNC_GroupGetBool` or one-argument `getVariable` plus `isNil` handling for group receivers.

## Soak Acceptance Checks

Run a soak with the movement flag enabled and compare to flag-off baseline:

- No RPT errors from A2-only syntax traps.
- No `NSSETVAR3`, group getVariable default, A3 command, or bracket lint failures.
- For each AI side, at least one live combat team has a non-idle movement intent within `WFBE_C_AICOM_V2_MOVE_DEAD_AIR_SEC` after commander initialization.
- A team must not change non-emergency movement intent more than once inside the configured hold time.
- At least one RPT transition line appears per intent change, with team, side, intent, target, and reason.
- A punished route is not selected again until expiry unless no legal alternative exists; if reused, log the reason.
- GUER pressure volume must not be capped or nerfed.

## Report Requirements For Builder PR

The later PR body must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_MOVEMENT` as default `0`, explain why flag-off is inert, confirm mirrors, and include soak evidence from HC `ArmA2OA.RPT` scoped to the current `MISSINIT` boundary.
