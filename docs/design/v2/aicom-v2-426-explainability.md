# AICOM V2 Behaviour Spec 426: Explainability

Status: final-form research/spec for later implementation. No gameplay code.
Scope: RPT-readable commander reasoning, event taxonomy, debug verbosity, soak traceability, and acceptance evidence for all AICOM V2 behaviour lanes.

## Doctrine Fit

Explainability is how V2 stays debuggable. The commander can be aggressive, adaptive, and unfair, but every major transition must leave a concise reason trail. Logs should show commitment, anti-churn, punishment memory, non-psychic evidence, and no-dead-air recovery without flooding the HC RPT.

This lane is not a UI feature and does not add gameplay behaviour by itself. It defines the logging and reporting contract that later builder lanes must use.

## Desired V2 Behaviour

1. Every major state transition logs once:
   - Side phase change.
   - Team intent change.
   - Movement target change.
   - Relocation start/end/fail.
   - Fire-support fire/deny/cancel.
   - Escalation start/end.
   - Lifecycle cleanup/recovery.
   - Defense tier change.
   - Research/build doctrine change.
   - Third-side influence.
   - Profile selection.

2. Logs use stable reason codes:
   - Human-readable enough for RPT inspection.
   - Stable enough for soak parsing.
   - Compact enough for HC.

3. Verbosity is layered:
   - Always-on one-line transition logs for major state changes and failures.
   - Verbose scoring dumps only through `WFBE_CO_FNC_LogContent` gated by `WF_LOG_CONTENT`.
   - No per-frame or per-unit spam.

4. Logs prove non-psychic behaviour:
   - Each decision cites evidence source and confidence when relevant.
   - If no evidence exists, log `noEvidence` and pick only behaviours allowed without evidence, such as probe or pressure fallback.

5. Logs support soak acceptance:
   - Every lane can be validated from HC `ArmA2OA.RPT` scoped to the current `MISSINIT` boundary.

## V2 Layer Contract

- Explainability helper receives normalized event fields from all V2 behaviour layers.
- It formats one-line RPT records consistently.
- It routes verbose details through existing LogContent conventions.
- It never changes gameplay decisions.
- It never requires client UI, JIP changes, or deploy/box changes.

## V1 Evidence To Keep

Use these anchors:

- `WFBE_CO_FNC_LogContent`: existing content logging function named in `AGENTS.md`.
- `version.sqf`: `WF_LOG_CONTENT` defines verbose log availability.
- `initJIPCompatible.sqf:72`: HC forces LogContent on for every HC, so verbose logs must be bounded.
- `Tools/Soak/README.md`: soak KPI/reporting surface.
- `Common/Init/Init_CommonConstants.sqf`: append explainability flag and log verbosity tunables.
- `AGENTS.md`: always use HC `ArmA2OA.RPT`, not `arma2oaserver.RPT`, for AICOM team logs; scope reads to current `MISSINIT`.

Keep V1 strengths:

- Existing logging function should be reused.
- Existing RPT workflow remains the verification target.
- Existing `WF_LOG_CONTENT` convention remains the verbose gate.

## V1 Behaviour To Fix

- Major AI decisions with no RPT reason.
- Verbose logs tied to the wrong flag.
- HC log spam caused by LogContent always being active.
- Soak results that cannot connect behaviour to decision inputs.
- Reason text that changes too often to parse.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_EXPLAIN = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_EXPLAIN_ALWAYS = 1`: major transition lines enabled when lane flag is on.
- `WFBE_C_AICOM_V2_EXPLAIN_VERBOSE = 0`: extra details only if both this and `WF_LOG_CONTENT` allow it.
- `WFBE_C_AICOM_V2_EXPLAIN_RATE_SEC`: minimum seconds between repeated identical non-critical logs.
- `WFBE_C_AICOM_V2_EXPLAIN_MAX_DETAIL`: optional detail-length bound if the codebase has a pattern for it.

Flag-off must be inert. Do not wire `WFBE_C_SIM_GATING`.

## Event Format

Use a stable single-line shape equivalent to:

`AICOM_V2 side=<side> team=<team> lane=<lane> event=<event> old=<old> new=<new> target=<target> reason=<reason> evidence=<source> confidence=<n> profile=<profile>`

Fields may be `na` when not applicable. Avoid dumping arrays or object handles in always-on lines.

Required fields:

- `side`
- `lane`
- `event`
- `reason`

Required when applicable:

- `team`
- `target`
- `old`
- `new`
- `evidence`
- `confidence`
- `profile`

## Reason Code Starter Set

Use stable lower-camel or compact names:

- `openingComplete`
- `deadAirFallback`
- `knownThreat`
- `baseCrisis`
- `mhqThreat`
- `townPressure`
- `probeSuccess`
- `routePunished`
- `frontStale`
- `supportNoEvidence`
- `supportNoExploit`
- `playerProximityRelaxed`
- `playerHardBlock`
- `churnSuppressed`
- `counterEvidenceMet`
- `guerThreat`
- `guerOpportunity`
- `noEvidence`

Builders may add reason codes, but must document them in the PR body or the spec appendix they update.

## Soak Acceptance Checks

- HC `ArmA2OA.RPT` contains `AICOM_V2` transition lines for every enabled lane that changes state.
- Logs are scoped to the current `MISSINIT` boundary for reporting.
- Verbose logs do not appear unless `WF_LOG_CONTENT` and the V2 verbose setting allow them.
- Repeated identical non-critical events are rate-limited.
- Every fire-support, defense, build counter, and relocation decision includes evidence source or `noEvidence`.
- No log line depends on A3-only commands or unsupported formatting.
- No RPT spam that makes soak reports unusable.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_EXPLAIN` default `0`, prove flag-off inertness, include representative HC RPT lines, and confirm mirrors.
