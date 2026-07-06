# AICOM V2 Behaviour Spec 423: Intel

Status: final-form research/spec for later implementation. No gameplay code.
Scope: What the AI commander may know, how confidence decays, how reports feed behaviour, and how to prevent psychic decisions.

## Doctrine Fit

Intel is the guardrail that keeps V2 believable. The commander should punish and remember what it legitimately learns, refuse fair fights from known information, commit with imperfect but sufficient evidence, and keep pressure alive without using hidden engine truth.

Every other behaviour lane depends on intel. If a later builder is unsure whether a fact is legitimate, the fact must not drive V2 behaviour until the source is proven from V1 code.

## Desired V2 Behaviour

1. Intel records have source and confidence:
   - Contact report.
   - Friendly loss report.
   - Town combat/capture state.
   - Base/MHQ threat state.
   - Public side/tech state if V1 exposes it.
   - Stuck/route failure memory.

2. Intel decays:
   - Old contact becomes stale.
   - Stale reports can justify probe or caution, not perfect strikes or counters.
   - Recent repeated reports raise confidence.

3. Intel separates known, inferred, and forbidden:
   - Known: directly available from legitimate V1 state.
   - Inferred: derived from known events, such as armor likely after repeated vehicle losses.
   - Forbidden: hidden enemy position/composition known only by engine/global arrays with no observation path.

4. Intel feeds all behaviour layers:
   - Movement target confidence.
   - Fire support target confidence.
   - Defense threat tier.
   - Build/research counter confidence.
   - Relocation punishment.
   - Escalation triggers.

5. Intel is explainable:
   - Behaviour logs cite the evidence source or state `noEvidence`.
   - Verbose intel dumps stay behind `WF_LOG_CONTENT`.

## V2 Layer Contract

- Intel collector converts V1 events/state into normalized reports.
- Intel store holds reports by side, area/town, type, confidence, timestamp, and source.
- Decay function reduces confidence over time.
- Query helpers return confidence and evidence source to behaviour layers.
- Explainability consumes the same source data used for decisions.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append intel flag and tunables.
- `version.sqf` and `WFBE_CO_FNC_LogContent`: verbose intel output gate.
- `initJIPCompatible.sqf:72`: HC LogContent always active, so avoid high-volume contact spam.
- `Tools/Soak/README.md`: soak checks for no psychic behaviour, RPT health, and no dead air.
- `docs/AGENT-HANDBOOK.md`: A2 OA syntax and command rules.
- `AGENTS.md`: group `getVariable [name, default]` is forbidden; use the documented safe pattern if storing group intel state.

Keep V1 strengths:

- Existing town/capture/base state is legitimate strategic information.
- Existing contact/combat events, if present, are preferable to new global scans.
- Existing side arrays and team structures should remain authoritative for friendly state.

## V1 Behaviour To Fix

- Perfect response to hidden enemies.
- No confidence distinction between fresh and stale contact.
- Lack of shared memory across movement, defense, support, and build decisions.
- RPT lines that say what happened but not why the AI believed it.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_INTEL = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_INTEL_CONTACT_DECAY_SEC`
- `WFBE_C_AICOM_V2_INTEL_LOSS_DECAY_SEC`
- `WFBE_C_AICOM_V2_INTEL_TOWN_DECAY_SEC`
- `WFBE_C_AICOM_V2_INTEL_ROUTE_DECAY_SEC`
- `WFBE_C_AICOM_V2_INTEL_STALE_CONFIDENCE`
- `WFBE_C_AICOM_V2_INTEL_COUNTER_CONFIDENCE`
- `WFBE_C_AICOM_V2_INTEL_SUPPORT_CONFIDENCE`

Flag-off must be inert. Do not wire `WFBE_C_SIM_GATING`.

## Intel Record Shape

The later builder should implement records equivalent to:

- `side`: observing side.
- `subjectSide`: enemy/friendly/resistance side if known.
- `kind`: contact, loss, town, baseThreat, tech, route, stuck.
- `area`: town id/name or approximate position bucket.
- `confidence`: numeric confidence.
- `source`: concise source code, such as `townCombat`, `friendlyLoss`, `visualContact`, `routeStuck`.
- `time`: mission time of report.
- `expiry`: report expiry.
- `details`: small optional payload. Avoid large object references.

This is a data contract, not required SQF syntax.

## Allowed And Forbidden Knowledge

Allowed:

- Current town ownership and capture/combat state.
- Friendly team state.
- Recent friendly losses.
- Enemy contact reported by V1 legitimate detection.
- Public base/MHQ threat state if V1 already exposes it.
- Public tech/economy state only if V1 already exposes it to commander logic.

Forbidden:

- Direct hidden enemy unit scans to drive decisions without an observation source.
- Exact composition counters before observation.
- Fire support on positions known only from global object lists.
- Route avoidance because an unseen enemy is waiting there.

## Soak Acceptance Checks

- Every V2 behaviour decision log includes an evidence source or `noEvidence`.
- Confidence decays in logs for stale contacts when verbose logging is enabled.
- Fire support, defense, and counter-tech do not trigger from forbidden hidden knowledge.
- Stale intel can trigger probes but not perfect counters.
- Repeated legitimate reports raise response confidence.
- No RPT spam from per-unit intel dumps on HC.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_INTEL` default `0`, prove flag-off inertness, include HC RPT examples showing evidence source and confidence, and confirm mirrors.
