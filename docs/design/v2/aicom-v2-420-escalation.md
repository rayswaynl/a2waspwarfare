# AICOM V2 Behaviour Spec 420: Escalation

Status: final-form research/spec for later implementation. No gameplay code.
Scope: Commander escalation from probes to committed assaults, tech pressure, heavier compositions, defense emergencies, and late-game finishing behaviour.

## Doctrine Fit

Escalation makes V2 feel like a war that changes shape. The commander should start with useful pressure, recognize when a bigger commitment is justified, refuse fair fights by escalating asymmetrically, remember failed escalations, avoid psychic counters, and prevent late-game dead air.

Escalation is not a license to spam GUER caps, nerf resistance output, or introduce forbidden munitions. GUER volume is the point and must not be capped or reduced.

## Desired V2 Behaviour

1. Escalation has levels:
   - `probe`: low-cost pressure, scouting by contact, and flank testing.
   - `commit`: multiple teams or stronger composition assigned to a real objective.
   - `surge`: time-limited concentration to break or exploit a key front.
   - `crisis`: base/MHQ/core-town defense or recovery from severe loss.
   - `finish`: late-game pressure to end stalemate or exploit dominant position.

2. Escalation requires triggers:
   - Repeated probe success.
   - Enemy defense blocks normal attack.
   - Friendly town/base/MHQ under known pressure.
   - Research or economy milestone reached.
   - Enemy force loss observed.
   - Stalemate timer reached.

3. Escalation is time-boxed:
   - A surge has an end condition and fallback.
   - Crisis ends when threat decays or recovery is complete.
   - Finish mode must still respect evidence and defense needs.

4. Escalation is asymmetric:
   - If a direct assault failed, escalate through flank, interdiction, fire support, tech, or relocation before repeating.
   - Do not simply send more of the same into the same loss pattern.

5. Escalation is readable:
   - RPT should tell why the side escalated, what objective it selected, and when the escalation ended.

## V2 Layer Contract

- Strategic director owns side escalation level.
- Build/research, movement, defense, and fire-support layers consume escalation level as a weight, not as absolute override.
- Memory layer records failed and successful escalations.
- Intel layer prevents escalation from using hidden enemy knowledge.
- Explainability layer emits start, update, and end lines.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append the flag and escalation tunables.
- `Tools/Soak/README.md`: soak acceptance surface for no dead air, RPT health, and battle progression.
- `version.sqf` and `WFBE_CO_FNC_LogContent`: verbose diagnostics gate.
- `initJIPCompatible.sqf:72`: HC verbosity caveat.
- `AGENTS.md` owner constraints: never cap or nerf GUER output; never wire owner-rejected `WFBE_C_SIM_GATING`; never reopen forbidden munition proposals.

Keep V1 strengths:

- Existing economy/tech/capture state remains authoritative for what escalation can legally do.
- Existing commander routines already understand side and town state; V2 should add escalation state, not bypass legal checks.

## V1 Behaviour To Fix

- Flat pacing where early, mid, and late game feel the same.
- Stalemate without a declared attempt to change the shape of battle.
- Panic over-response that pulls every team to one event.
- Repeating the same failed attack with more bodies.
- Lack of RPT evidence for why the AI got stronger or backed down.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_ESCALATION = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_ESC_PROBE_MIN_SEC`
- `WFBE_C_AICOM_V2_ESC_COMMIT_MIN_SEC`
- `WFBE_C_AICOM_V2_ESC_SURGE_MAX_SEC`
- `WFBE_C_AICOM_V2_ESC_CRISIS_DECAY_SEC`
- `WFBE_C_AICOM_V2_ESC_STALEMATE_SEC`
- `WFBE_C_AICOM_V2_ESC_FAILURE_MEMORY_SEC`
- `WFBE_C_AICOM_V2_ESC_TEAM_SHARE_SURGE_MAX`

Flag-off must be inert and byte-identical to HEAD.

## Escalation Rules

Probe to commit:

- Trigger when a probe reaches contact, captures progress, or finds low resistance.
- Also trigger when no better pressure exists and dead-air timer would otherwise expire.

Commit to surge:

- Trigger only for valuable objective, repeated block, or exploit window.
- Require enough local force or support plan to make the surge meaningful.
- Limit share of teams so the rest of the map does not die.

Any level to crisis:

- Trigger on known base/MHQ/core-town threat.
- Crisis may override non-emergency hold times.
- Crisis must end when threat evidence decays or defense stabilizes.

Surge to recover:

- Trigger on heavy loss, timeout, or objective failure.
- Record the failed vector/composition for memory.

Finish:

- Trigger late-game dominance, long stalemate, or enemy collapse.
- Finish should increase pressure and exploitation, not disable defense or evidence rules.

## Soak Acceptance Checks

- Each side logs escalation level within the opening window.
- At least one level transition occurs in a representative long soak unless the game ends too quickly.
- Surge has start and end lines; no permanent surge without logged renewal.
- Crisis can override holds but ends after threat decay.
- Escalation does not pull all teams to one non-emergency objective.
- Repeated failed surge on the same vector is suppressed until memory expiry unless no legal alternative exists.
- GUER output is not capped or nerfed.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_ESCALATION` default `0`, prove flag-off inertness, include HC RPT escalation examples, and confirm mirrors.
