# AICOM V2 Behaviour Spec 425: Profiles

Status: final-form research/spec for later implementation. No gameplay code.
Scope: Data-driven commander personality/profile presets for strategic weighting, without adding owner-rejected doctrine personalities.

## Owner Constraint

`AGENTS.md` says not to re-propose doctrine personalities. This lane therefore defines profiles as internal data presets for weighting V2 behaviours, not named lore personalities, not player-facing commander characters, and not a new feature pitch. Profiles exist only to avoid one-note AI and to let builders tune behaviour safely.

## Doctrine Fit

Profiles let different commanders choose different unfair angles while still following the same doctrine: commit, avoid churn, punish and remember, avoid psychic knowledge, and keep pressure alive. Profiles must not override evidence rules or create random behaviour.

## Desired V2 Behaviour

1. Profiles are weight sets:
   - Movement aggression.
   - Defense sensitivity.
   - Relocation willingness.
   - Fire-support preference.
   - Tech reserve patience.
   - Escalation threshold.
   - Third-side exploitation.
   - Churn tolerance.

2. Profiles are bounded:
   - Every profile obeys intel legality.
   - Every profile obeys owner constraints.
   - Every profile has no-dead-air fallback.
   - No profile disables defense of base/MHQ.

3. Profiles create variation without hidden cheating:
   - A cautious profile may reinforce earlier but still attacks.
   - An aggressive profile may surge earlier but still respects evidence and recovery.
   - A mobile profile relocates more readily but does not abandon crisis defense.

4. Profiles are terrain-neutral:
   - Use town graph, distances, and existing map constants.
   - Do not encode Chernarus-only route names in shared profile data.

5. Profiles are explainable:
   - Logs include active profile key and the weight that mattered for major decisions.

## V2 Layer Contract

- Profile selector chooses one profile per AI commander side or team according to existing mission setup.
- Behaviour layers receive numeric weights, not hard-coded branches.
- Intel and safety constraints run after profile weighting and can veto profile preference.
- Explainability includes profile key in transition logs.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append profile flag and selected defaults.
- `Tools/Soak/README.md`: soak comparison proves profiles vary behaviour without RPT errors or dead air.
- `version.sqf` and `WFBE_CO_FNC_LogContent`: verbose profile scoring gate.
- `initJIPCompatible.sqf:72`: HC verbose log caution.
- `AGENTS.md` owner constraints: no doctrine personalities, no GUER nerf/cap, no `WFBE_C_SIM_GATING`.

Keep V1 strengths:

- Existing side/team setup remains the source for commander identity.
- Existing difficulty/economy settings should remain authoritative.
- Existing mission constants should hold profile defaults.

## V1 Behaviour To Fix

- Every AI commander feels identical.
- Variation achieved through randomness rather than durable preference.
- Hard-coded one-off branches that make future tuning brittle.
- Profile-like behaviour invisible in logs.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_PROFILES = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_PROFILE_DEFAULT`: numeric or string key using existing constant style.
- `WFBE_C_AICOM_V2_PROFILE_RANDOMIZE = 0`: default deterministic unless owner enables random selection.
- `WFBE_C_AICOM_V2_PROFILE_LOG_WEIGHTS = 0`: verbose profile diagnostics gate under `WF_LOG_CONTENT`.

Flag-off must be inert. Do not wire `WFBE_C_SIM_GATING`.

## Profile Set

Define data-only profile keys:

- `balanced`: baseline V2 weights.
- `pressure`: lower commit threshold, higher movement/fire-support pressure, normal defense.
- `mobile`: higher relocation/interdiction, lower repeated-route tolerance.
- `defensive`: higher defense sensitivity and reserve, still keeps attack/probe pressure alive.
- `opportunist`: higher exploit and third-side opportunity weighting, normal evidence thresholds.

Do not expose these as lore personalities. Do not add voice lines, UI flavour, or doctrine names.

## Weight Contract

Each profile should set numeric weights for:

- `attackScore`
- `defenseScore`
- `relocationScore`
- `fireSupportScore`
- `escalationScore`
- `researchReserve`
- `thirdSideExploit`
- `churnPenalty`
- `recoveryUrgency`

Weights modify scores but cannot:

- Bypass evidence thresholds.
- Bypass safety checks.
- Disable lifecycle cleanup.
- Cap GUER output.
- Force all teams to one non-crisis target.

## Soak Acceptance Checks

- With profiles enabled, RPT logs active profile per AI side/team during initialization.
- Different profiles produce measurable variation in at least two decision categories during controlled soak or scripted scenario.
- All profiles keep no-dead-air guarantees.
- No profile triggers psychic decisions or bypasses intel confidence.
- No profile disables crisis defense.
- No RPT spam from per-cycle weight dumps unless verbose logging is enabled.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_PROFILES` default `0`, state profiles are internal weight presets and not doctrine personalities, prove flag-off inertness, include HC RPT profile examples, and confirm mirrors.
