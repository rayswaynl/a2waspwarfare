# AICOM V2 Behaviour Spec 419: Fire Support

Status: final-form research/spec for later implementation. No gameplay code.
Scope: AI commander use of existing artillery, air, indirect, and support-style pressure tools already present in V1.

## Doctrine Fit

Fire support in V2 must make the commander punish exposed enemies and break stalemates without becoming omniscient or oppressive. It should commit support to a purpose, refuse fair fights by shaping the fight before assault, remember waste and punishment, avoid hidden knowledge, and keep pressure alive when direct movement stalls.

This spec does not authorize new munitions or owner-rejected proposals. Do not re-propose EMP, WP, DECOY SCUD munitions, satchel AI, TPWCAS, ACR content, or doctrine personalities.

## Desired V2 Behaviour

1. Fire support is intent-driven:
   - `prepAssault`: soften a known defended town before a committed push.
   - `breakDefense`: punish a known static or clustered defense that has blocked movement.
   - `counterPush`: disrupt known enemy pressure on a friendly town.
   - `interdictRoute`: hit a route or staging area with recent legitimate contact.
   - `finishWindow`: exploit a known enemy wipe or immobilized vehicle cluster.

2. Fire support requires legitimate evidence:
   - Recent visual/contact report, town combat state, friendly losses, or known base/MHQ threat.
   - No strikes on hidden groups solely because the engine knows their position.

3. Fire support is coordinated:
   - Do not spend major support on a town if no friendly team can exploit it within a window.
   - Do not stack all support types on the same low-value target unless an emergency or escalation condition is logged.

4. Fire support has memory:
   - Track misses, waste, friendly danger, and repeated blocked assaults.
   - Cool down target areas that were just struck unless battle state justifies repeat.

5. Fire support is explainable:
   - Always-on line when support is requested, denied, fired, cancelled, or withheld by evidence rules.
   - Verbose target scoring only behind `WF_LOG_CONTENT`.

## V2 Layer Contract

- Strategic director declares where support can alter the battle.
- Intel layer provides known target confidence.
- Fire-support planner selects support intent, target area, danger radius, exploit window, and cooldown.
- Existing support executors fire only legal V1 support assets.
- Memory layer records target area results.
- Explainability layer logs decisions with evidence source and confidence.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append flags and tuning values only here.
- `version.sqf`: `WF_LOG_CONTENT` gates verbose support diagnostics.
- `initJIPCompatible.sqf:72`: HC forces LogContent on, so verbose support scoring must be bounded.
- `Tools/Soak/README.md`: use soak checks for RPT errors, support cadence, and no dead air.
- `docs/AGENT-HANDBOOK.md`: confirm A2 OA command legality before future SQF edits.
- `AGENTS.md` owner constraints: do not reopen shelved munitions or owner-rejected concepts.

Keep V1 strengths:

- Existing support availability, costs, cooldowns, and asset ownership remain authoritative.
- Existing friendly-fire or safety checks must not be bypassed.
- Existing GUER pressure must not be capped or nerfed by support throttles.

## V1 Behaviour To Fix

- Support fired without an exploiting movement plan.
- Support held forever because confidence is never perfect.
- Repeated strikes into the same stale area without result memory.
- Perfect strikes against enemies that should be unknown.
- Support decisions invisible in HC RPT.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_FIRE_SUPPORT = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_FS_CONFIDENCE_MIN`: minimum legitimate target confidence.
- `WFBE_C_AICOM_V2_FS_EXPLOIT_WINDOW_SEC`: time window in which friendly pressure must be able to exploit.
- `WFBE_C_AICOM_V2_FS_AREA_COOLDOWN_SEC`: cooldown for repeated strikes in the same area.
- `WFBE_C_AICOM_V2_FS_WASTE_MEMORY_SEC`: memory duration for support that produced no effect.
- `WFBE_C_AICOM_V2_FS_FRIENDLY_SAFE_RADIUS`: minimum friendly safety distance unless V1 executor already has stricter checks.
- `WFBE_C_AICOM_V2_FS_EMERGENCY_BYPASS_SCORE`: score threshold for base/MHQ/town emergency support.

Flag-off must be inert. Do not wire `WFBE_C_SIM_GATING`.

## Evidence Model

Target confidence may come from:

- Recent known contact timestamp.
- Friendly loss report near the target area.
- Town combat or capture pressure state.
- Observed vehicle/static presence if V1 exposes it legitimately.
- Known enemy base/MHQ threat if V1 state makes that public.

Target confidence must decay over time. If confidence decays below threshold, support can still choose a probe/interdiction action only if the support type is appropriate and the log states stale evidence.

## Denial Reasons

Every support denial should use one reason code:

- `noEvidence`
- `noExploit`
- `cooldown`
- `friendlyDanger`
- `assetUnavailable`
- `costReserve`
- `staleTarget`
- `lowerPriorityEmergency`

These reason codes should feed explainability and soak analysis.

## Soak Acceptance Checks

- Support request/firing/denial lines appear in HC RPT with side, intent, target area, confidence, and reason.
- No fire-support decision uses hidden enemy position without a logged legitimate evidence source.
- At least one support action is paired with a friendly movement/exploit intent inside the configured window during a representative soak.
- Repeated support on the same area respects cooldown unless emergency bypass is logged.
- Friendly danger denials occur when friendly teams are too close.
- No owner-rejected munitions or new classnames are introduced.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_FIRE_SUPPORT` default `0`, prove flag-off inertness, include HC RPT examples of fire-support fire and denial, and confirm mirrors.
