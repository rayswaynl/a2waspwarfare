# AICOM V2 Behaviour Spec 424: Third-Side

Status: final-form research/spec for later implementation. No gameplay code.
Scope: AI commander behaviour around GUER/resistance/third-side pressure, without reducing GUER volume or turning third-side into a passive background system.

## Doctrine Fit

The third side should create uncertainty, opportunity, and punishment. V2 commanders should exploit, avoid, or respond to third-side pressure based on known information, not delete it. They should refuse fair fights by using third-side chaos, remember areas where GUER punished them, and keep pressure alive even when BLUFOR/OPFOR fronts stall.

Owner constraint is binding: GUER volume is the point. Do not cap or nerf GUER output.

## Desired V2 Behaviour

1. Third-side pressure is treated as battlefield reality:
   - Towns or routes with active GUER pressure influence movement, defense, relocation, and fire-support decisions.
   - Commanders can exploit third-side pressure against the enemy.
   - Commanders can avoid recently punished GUER-heavy routes if they have legitimate evidence.

2. Third-side handling is asymmetric:
   - If enemy is pinned by GUER, press adjacent objectives or interdict escape routes.
   - If friendly force is pinned by GUER, recover, flank, or choose a different objective instead of feeding the same fight.
   - If GUER pressure creates dead air risk, choose a probe or relocation rather than waiting.

3. Third-side logic is non-psychic:
   - Use town state, contact, losses, and known resistance events.
   - Do not know exact GUER units hidden in forests or towns unless V1 legitimately reports them.

4. Third-side memory exists:
   - Record GUER-punished routes/towns.
   - Record areas where GUER pressure helped create an exploit.

5. Third-side decisions are explainable:
   - Logs must distinguish `guerThreat`, `guerOpportunity`, and `guerNeutral`.

## V2 Layer Contract

- Intel layer records third-side events and confidence.
- Movement and relocation use third-side threat/opportunity scores.
- Defense uses third-side pressure to avoid overreacting to enemy if GUER is the real source.
- Escalation can exploit third-side-created windows.
- Build/research may adapt only to observed third-side threat types using the same non-psychic evidence rules.
- Explainability logs third-side influence on decisions.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append third-side flag and tunables.
- `Tools/Soak/README.md`: soak evidence must prove GUER volume was not capped or muted.
- `version.sqf` and `WFBE_CO_FNC_LogContent`: verbose third-side scoring gate.
- `initJIPCompatible.sqf:72`: HC verbose log caution.
- `AGENTS.md` owner constraints: no GUER caps or nerfs; do not re-propose forbidden content.

Keep V1 strengths:

- Existing GUER spawn/pressure systems remain authoritative.
- Existing town ownership and resistance interactions remain the legal source.
- Existing side relationships should not be rewritten by this lane.

## V1 Behaviour To Fix

- AI ignores third-side pressure until teams die.
- AI overcommits into GUER meatgrinders without memory.
- AI fails to exploit enemy being distracted by GUER.
- Third-side influence is invisible in commander logs.
- Fixes that solve difficulty by reducing GUER output, which is prohibited.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_THIRD_SIDE = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_GUER_THREAT_DECAY_SEC`
- `WFBE_C_AICOM_V2_GUER_OPPORTUNITY_DECAY_SEC`
- `WFBE_C_AICOM_V2_GUER_ROUTE_MEMORY_SEC`
- `WFBE_C_AICOM_V2_GUER_AVOID_SCORE`
- `WFBE_C_AICOM_V2_GUER_EXPLOIT_SCORE`
- `WFBE_C_AICOM_V2_GUER_MAX_TEAM_SHARE_RESPONSE`: response share cap for commander teams, not a cap on GUER output.

Flag-off must be inert. Do not wire `WFBE_C_SIM_GATING`.

## Decision Rules

Threat:

- If friendly losses or stalled movement correlate with GUER pressure, mark `guerThreat`.
- Avoid repeating the same approach until memory expires unless no legal alternative exists.
- Recovery should reroute or change composition only after legitimate evidence.

Opportunity:

- If enemy town/contact is under third-side pressure, mark `guerOpportunity`.
- Prefer adjacent pressure, interdiction, or timed assault over waiting.
- Do not assume exact enemy weakness beyond observed/town state evidence.

Neutral:

- If GUER exists in the wider mission but no local evidence exists, do not alter decisions.

## Soak Acceptance Checks

- GUER output is not capped, throttled, or reduced by this lane.
- HC RPT contains at least one third-side influence line in a representative soak where GUER contact occurs.
- AI avoids or reroutes after repeated legitimate GUER punishment.
- AI exploits a legitimate enemy/GUER pressure window when available.
- AI does not perfectly avoid hidden GUER with no evidence.
- No all-team pull to GUER response unless base/MHQ crisis is separately logged.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_THIRD_SIDE` default `0`, explicitly state GUER volume is untouched, include HC RPT examples, and confirm mirrors.
