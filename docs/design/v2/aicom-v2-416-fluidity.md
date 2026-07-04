# AICOM V2 Behaviour Spec 416: Fluidity

Status: final-form research/spec for later implementation. No gameplay code.
Scope: Commander pacing, decision cadence, anti-churn rules, and smooth transitions between attack, defense, recovery, and exploitation.

## Doctrine Fit

Fluidity is the layer that makes V2 feel alive without becoming random. The AI commander should change plans when the battlefield changes, but not thrash. It should commit long enough to create consequences, refuse fair fights by shifting pressure, punish and remember bad trades, avoid psychic reactions, and prevent dead air.

Fluidity must not mean faster polling everywhere. It means better state transitions, visible reasons, and bounded cool-downs around existing decision loops.

## Desired V2 Behaviour

1. Commander decisions use a small set of explicit phases:
   - `opening`: secure first expansion and avoid early paralysis.
   - `pressure`: push towns, probes, and routes.
   - `contest`: respond to active enemy pressure without abandoning the whole front.
   - `exploit`: reinforce success after a town falls or enemy force collapses.
   - `recover`: replace losses, regroup, or relocate after punishment.

2. Phase transitions require reasons:
   - Town captured or lost.
   - Known enemy force detected or destroyed.
   - Friendly team wiped or stuck beyond threshold.
   - Economy or tech milestone reached.
   - Base/MHQ threat known.
   - No useful pressure has happened for too long.

3. Decisions use hysteresis:
   - A team may react immediately to emergencies.
   - Non-emergency phase changes require minimum hold time.
   - Repeated flip-flops between two targets are suppressed by a churn penalty.

4. Recovery must be active:
   - Recovering teams should rearm, rebuild, relocate, reinforce, or probe.
   - They must not wait silently for perfect conditions.

5. Exploitation must be timely:
   - When a side creates a local advantage, nearby idle or recovering teams should help convert it into town capture, route pressure, or defense.
   - Do not pull every team into one blob; use local scope and role profiles.

## V2 Layer Contract

- Strategic director owns side-wide phase.
- Team intent layer owns team-specific movement/combat intent.
- Fluidity layer mediates transitions and applies hold times, emergency overrides, and churn penalties.
- Memory layer supplies recent punishment and success history.
- Explainability layer emits phase and intent transition reasons.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: all new flags and tunables go here.
- `WFBE_CO_FNC_LogContent`: existing content logging function; verbose fluidity dumps must stay behind `WF_LOG_CONTENT`.
- `version.sqf`: `WF_LOG_CONTENT` is the verbose-log gate.
- `initJIPCompatible.sqf:72`: HC always activates LogContent, so logs must be low-volume.
- `Tools/Soak/README.md`: use soak KPIs to prove no dead air and no RPT regressions.
- `docs/AGENT-HANDBOOK.md`: confirm A2 OA-compatible syntax and command choices.

Keep V1 strengths:

- Existing commander loops already have legal access to side, town, economy, and team state.
- Existing team purchase, order, and town logic should remain the source of truth.
- The current mission has multiple maintained terrains; fluidity must not encode Chernarus-only distances without terrain parameters.

## V1 Behaviour To Fix

- Churn after contact: teams abandon an attack too soon.
- Passive recovery: teams sit after losing vehicles or infantry.
- Over-centralization: too many teams answer one event, leaving the rest of the map quiet.
- Under-explaining: no clear RPT reason for major strategic pivots.
- Same-tempo behaviour: early game, mid game, and late game feel similar.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_FLUIDITY = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_PHASE_MIN_SEC`: minimum side phase hold time.
- `WFBE_C_AICOM_V2_INTENT_MIN_SEC`: minimum team intent hold time.
- `WFBE_C_AICOM_V2_EMERGENCY_RADIUS`: radius for base/MHQ/town emergency classification.
- `WFBE_C_AICOM_V2_CHURN_WINDOW_SEC`: time window for counting repeated target flips.
- `WFBE_C_AICOM_V2_CHURN_PENALTY_SEC`: cooldown applied after repeated churn.
- `WFBE_C_AICOM_V2_RECOVERY_MAX_IDLE_SEC`: maximum time a recovering team may lack a useful action.

Flag-off must be inert and byte-identical to HEAD. Do not wire `WFBE_C_SIM_GATING`.

## Transition Rules

Side-wide phase transitions:

- `opening -> pressure`: first expansion goal reached or opening timeout hit.
- `pressure -> contest`: enemy pressure threatens a valuable friendly town, base, or MHQ with known contact.
- `contest -> exploit`: enemy attack breaks or nearby enemy town becomes weak from legitimate known state.
- `contest -> recover`: local force loss crosses threshold and no immediate defense is possible.
- `recover -> pressure`: rebuilt force has enough strength, or recovery timeout requires a probe.

Team intent transitions:

- Emergency defense can override hold time.
- Wipe recovery can override attack commitment.
- Exploit can override probe but not active base defense.
- Repeated flips between the same two targets are suppressed unless one is an emergency.

## Anti-Churn Rules

Track per-team:

- Last three intents.
- Last three targets.
- Transition timestamps.
- Reason code for each transition.

If a team alternates between two non-emergency targets within `WFBE_C_AICOM_V2_CHURN_WINDOW_SEC`, apply a churn penalty to both targets for that team. During penalty, choose commit, reinforce, or probe elsewhere.

## Soak Acceptance Checks

- RPT contains side phase transition lines with side, old phase, new phase, reason, and time.
- RPT contains team intent transition lines with team, old intent, new intent, target, and reason.
- No team performs more than the allowed non-emergency transitions per hold window.
- At least one recovery action occurs after a detected wipe or heavy loss.
- At least one exploit action occurs after a town capture or enemy attack collapse during a representative soak.
- No global pull causes all teams to converge on a single town unless base/MHQ emergency is logged.
- No A3-only lint failures and no new RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_FLUIDITY` default `0`, state flag-off inertness, include HC RPT phase examples, and confirm no mirror/template drift.
