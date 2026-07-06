# AICOM V2 Behaviour Spec 418: Relocation

Status: final-form research/spec for later implementation. No gameplay code.
Scope: Strategic relocation of commander assets, staging centers, team rally points, and fallback pressure when current geography is stale or punished.

## Doctrine Fit

Relocation is how V2 avoids repeating the same losing fight. The commander should commit to a front, but when that front is punished or strategically stale, it should move the pressure base, rally point, or attack axis with a visible reason. Relocation must be deliberate, not twitchy, and must never rely on hidden enemy knowledge.

This spec does not authorize touching HC architecture, player enrollment/JIP flow, deploy scripts, or box scripts. Those are owner-forbidden in `AGENTS.md`.

## Desired V2 Behaviour

1. Relocation is triggered by strategic conditions:
   - Repeated losses on a route or front.
   - Captured town creates a better staging hub.
   - Friendly town under sustained pressure needs a closer reaction point.
   - Current staging area has no useful outgoing pressure.
   - Base/MHQ threat requires a fallback or defensive reposition based on known contact.

2. Relocation has a commitment window:
   - Once a relocation begins, teams do not instantly return to the old front unless emergency criteria fire.
   - Relocation failure is logged and remembered.

3. Relocation chooses unfair angles:
   - Prefer a flank, cut-off, or under-defended adjacent chain over a direct repeat.
   - If enemy pressure is strong at one town, look for the next objective that forces enemy movement.

4. Relocation is bounded:
   - Do not march every team across the map for a minor event.
   - Do not abandon base or core towns when known enemy pressure exists.
   - Do not encode terrain-specific magic positions in shared logic.

5. Relocation is explainable:
   - Log source, destination, reason, expected role, and expiry.

## V2 Layer Contract

- Strategic director identifies stale or punished fronts.
- Relocation planner selects new staging hub, affected teams, and hold time.
- Movement layer moves selected teams.
- Defense layer can veto relocation when a critical defense emergency exists.
- Memory layer tracks punished fronts and relocation outcomes.
- Explainability layer emits one always-on line per relocation start/end/failure.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append flags and relocation tunables.
- `docs/AGENT-HANDBOOK.md`: confirm terrain mirror and A2 command constraints before future SQF edits.
- `Tools/LoadoutManager`: any future SQF edit to Chernarus source must be mirrored to Takistan and Zargabad.
- `Tools/Soak/README.md`: soak evidence must verify no dead air and no RPT regressions.
- `WFBE_CO_FNC_LogContent` plus `version.sqf`: verbose relocation diagnostics must be gated by `WF_LOG_CONTENT`.
- `initJIPCompatible.sqf:72`: HC LogContent is always active, so relocation logs must stay compact.

Keep V1 strengths:

- Existing town graph, ownership state, and side base state remain the legal relocation substrate.
- Existing move execution remains responsible for actual group movement.
- Existing defense/base threat logic should be respected if present; V2 relocation should not bypass it.

## V1 Behaviour To Fix

- Stale fronts where AI keeps pushing one direct lane.
- Overcorrection where AI abandons all pressure to respond to one contact.
- Relocation without memory, causing repeated failed marches.
- Silent relocation decisions that cannot be debugged from HC RPT.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_RELOCATION = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_RELOCATE_MIN_SEC`: minimum time between non-emergency relocations.
- `WFBE_C_AICOM_V2_RELOCATE_HOLD_SEC`: minimum hold after relocation starts.
- `WFBE_C_AICOM_V2_FRONT_STALE_SEC`: time without useful pressure before a front is stale.
- `WFBE_C_AICOM_V2_FRONT_PUNISH_LOSSES`: loss threshold to mark a front punished.
- `WFBE_C_AICOM_V2_RELOCATE_TEAM_SHARE_MAX`: maximum share of teams allowed to relocate for non-emergency reasons.
- `WFBE_C_AICOM_V2_RELOCATE_MEMORY_SEC`: outcome memory expiry.

Flag-off must be inert and byte-identical. Do not wire `WFBE_C_SIM_GATING`.

## Relocation Candidate Rules

Candidate staging hubs should be legal friendly towns, safe known positions, or already-valid V1 staging concepts. Score by:

- Distance to pressure opportunity.
- Distance from known enemy threat.
- Ability to threaten an enemy flank or supply route.
- Friendly defense coverage.
- Recent punishment on the source front.
- Terrain-neutral viability using existing town positions, not hard-coded map spots.

Reject candidates if:

- They require hidden knowledge.
- They pull too many teams from a known emergency.
- They rely on a player-only deploy/box flow.
- They would strand teams with no follow-up objective.

## Soak Acceptance Checks

- At least one relocation is triggered during a long soak when a front is stale or punished.
- Relocation logs include side/team set, old front, new hub, reason, and hold expiry.
- Non-emergency relocations do not exceed configured team share.
- A team under relocation does not immediately churn back to the old target inside hold time.
- If a defense emergency blocks relocation, RPT logs the veto reason.
- No new RPT errors, no A3-only lint failures, and no mirror/template drift after later code work.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_RELOCATION` default `0`, state flag-off inertness, include HC RPT relocation examples, and confirm mirrors.
