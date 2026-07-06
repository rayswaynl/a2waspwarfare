# AICOM V2 Behaviour Spec 422: Defense

Status: final-form research/spec for later implementation. No gameplay code.
Scope: AI commander defense of towns, base/MHQ, staging hubs, and threatened routes.

## Doctrine Fit

Defense in V2 must be active, not passive. The commander should defend by buying time, counterattacking, relocating pressure, and making the enemy pay. It should commit to important defenses, refuse fair fights by flanking or interdicting attackers, remember repeated threats, avoid psychic pre-defense, and prevent dead air while defending.

Defense must not become global turtling. The AI should preserve pressure unless a real crisis exists.

## Desired V2 Behaviour

1. Defense has tiers:
   - `watch`: legitimate weak signal, no major response.
   - `reinforce`: send local or nearby team to threatened town.
   - `counterattack`: hit attacker flank, origin route, or adjacent enemy objective.
   - `crisis`: base/MHQ/core-town defense overrides normal priorities.
   - `recover`: rebuild after defense fails.

2. Defense uses evidence:
   - Town combat state, known contact, friendly losses, capture progress, or base/MHQ threat.
   - No pre-positioning against hidden attacks.

3. Defense keeps pressure elsewhere:
   - Minor town pressure should not pull every team.
   - Non-local teams continue attack, probe, or interdiction unless crisis is logged.

4. Defense punishes attackers:
   - If enemy repeatedly attacks from the same direction, mark route and source as threat memory.
   - Prefer interdiction or counterattack when direct defense would be a fair losing fight.

5. Defense is explainable:
   - Log defense tier changes, team assignments, and vetoes.

## V2 Layer Contract

- Intel layer reports legitimate threats.
- Defense planner scores threat tier and response shape.
- Movement layer executes reinforce/counterattack/interdict intents.
- Build/research layer adjusts local composition only when evidence threshold is met.
- Escalation layer can enter crisis for base/MHQ/core threats.
- Memory layer records repeated attack vectors.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append defense flag and tunables.
- `Tools/Soak/README.md`: use soak evidence for response timing, RPT health, and pressure continuity.
- `version.sqf` plus `WFBE_CO_FNC_LogContent`: verbose defense scoring gate.
- `initJIPCompatible.sqf:72`: HC verbose log caution.
- `AGENTS.md` owner constraints: never touch HC architecture, player enrollment/JIP flow, deploy/box scripts; do not cap GUER output.

Keep V1 strengths:

- Existing town ownership/capture/combat state remains authoritative.
- Existing base and MHQ threat knowledge should be reused, not redefined blindly.
- Existing group movement and purchase execution should remain the executor.

## V1 Behaviour To Fix

- Either no response or all-response to town pressure.
- Defensive turtling that kills map pressure.
- Repeated direct defense into the same losing approach.
- Defense reactions without visible reason.
- Perfect defense against unobserved threats.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_DEFENSE = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_DEF_WATCH_SEC`: minimum watch duration before escalation if weak evidence persists.
- `WFBE_C_AICOM_V2_DEF_REINFORCE_RADIUS`: local team radius for reinforcement.
- `WFBE_C_AICOM_V2_DEF_TEAM_SHARE_MAX`: maximum non-crisis team share for defense.
- `WFBE_C_AICOM_V2_DEF_CRISIS_RADIUS`: base/MHQ/core-town crisis radius.
- `WFBE_C_AICOM_V2_DEF_THREAT_MEMORY_SEC`: memory expiry for repeated attack vectors.
- `WFBE_C_AICOM_V2_DEF_COUNTER_MIN_SCORE`: minimum score for counterattack instead of direct reinforce.

Flag-off must be inert. Do not wire `WFBE_C_SIM_GATING`.

## Threat Scoring

Score threats using:

- Objective value.
- Capture progress or combat state.
- Known enemy contact confidence.
- Friendly losses.
- Distance from available defenders.
- Whether attacker vector has repeated recently.
- Whether a counterattack would relieve pressure faster than direct defense.

Do not score hidden enemy positions. Do not pull all teams unless crisis tier is logged.

## Response Rules

- `watch`: log only if state persists or changes; do not spam.
- `reinforce`: assign nearby suitable team and hold assignment through minimum time.
- `counterattack`: select attacker route/source or adjacent objective when evidence supports it.
- `crisis`: override movement holds, but log entry and exit.
- `recover`: if defense fails, trigger lifecycle/build recovery and record threat memory.

## Soak Acceptance Checks

- Threat tier changes appear in HC RPT with side, town/base target, tier, confidence, and reason.
- Minor threats do not pull more than configured team share.
- Crisis threats can override holds and later decay back out of crisis.
- At least one counterattack or interdiction response occurs after repeated attacks from the same vector in a representative soak.
- No pre-defense against unobserved enemy approach.
- Attack/probe pressure continues somewhere during non-crisis defense.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_DEFENSE` default `0`, prove flag-off inertness, include HC RPT defense examples, and confirm mirrors.
