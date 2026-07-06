# AICOM V2 Behaviour Spec 421: Lifecycle And Cleanup

Status: final-form research/spec for later implementation. No gameplay code.
Scope: AI team lifecycle, stuck detection, dead/empty vehicle cleanup, recovery from broken orders, despawn/recycle policy, and RPT-visible cleanup decisions.

## Owner Clarification

The owner authorized relaxing the stuck-vehicle player-proximity despawn guard. V2 must parameterize proximity instead of treating nearby players as an absolute hard block. The cleanup system may despawn or recycle stuck AI assets near players only when configured conditions are met and the action is logged. The default-off flag still preserves V1 behaviour when disabled.

## Doctrine Fit

Lifecycle and cleanup keep the war moving. The AI should commit to teams long enough for them to matter, recover from broken states, refuse dead-air caused by stuck vehicles, remember repeated stuck locations, avoid deleting active threats unfairly, and explain every visible cleanup action.

Cleanup must be conservative around player experience, but it must not let one stuck vehicle freeze a team forever.

## Desired V2 Behaviour

1. Teams have explicit lifecycle states:
   - `forming`: being purchased or assembled.
   - `active`: executing movement/combat intent.
   - `stalled`: no meaningful progress but not confirmed stuck.
   - `stuck`: repeated progress failures or immobilized key asset.
   - `recovering`: rerouting, dismounting, rebuilding, or recycling.
   - `retired`: intentionally cleaned up or replaced.

2. Stuck detection uses multiple signals:
   - Position progress below threshold across samples.
   - Vehicle damage, fuel, crew, or mobility state if available in V1.
   - Time since last meaningful waypoint progress.
   - Combat state and nearby known enemy/friendly/player presence.

3. Recovery escalates before deletion:
   - Retry movement or route.
   - Dismount infantry if useful and legal in V1.
   - Reassign intent or fallback.
   - Recycle/despawn only after configured thresholds.

4. Player proximity is a policy parameter:
   - Nearby player presence increases caution and logging.
   - It does not permanently block cleanup.
   - Cleanup near players requires stricter age/stuck thresholds, optional line-of-sight/engagement checks if V1 has them, and a clear RPT reason.

5. Cleanup feeds memory:
   - Repeated stuck locations become route punishment inputs for movement and relocation.

## V2 Layer Contract

- Lifecycle monitor samples team progress and asset state.
- Movement layer receives stuck/recovery events.
- Build/research layer receives replacement requests.
- Memory layer records stuck location, route, asset class if safe to log, and expiry.
- Explainability layer logs state transitions and cleanup actions.

## V1 Evidence To Keep

Use these anchors:

- `Common/Init/Init_CommonConstants.sqf`: append lifecycle flag and tuning parameters only here.
- `Tools/Soak/README.md`: soak acceptance for stuck recovery, no dead air, and RPT health.
- `version.sqf` and `WFBE_CO_FNC_LogContent`: verbose lifecycle sampling must be gated by `WF_LOG_CONTENT`.
- `initJIPCompatible.sqf:72`: HC LogContent is always active, so sample logs must not spam.
- `docs/AGENT-HANDBOOK.md`: confirm A2 OA syntax and avoid forbidden A3 commands such as `getPosVisual`.
- `AGENTS.md` owner constraints: do not touch deploy/box scripts, HC architecture, or player enrollment/JIP flow.

Keep V1 strengths:

- Existing cleanup/despawn routines should remain the executor where possible.
- Existing vehicle/team ownership should remain authoritative.
- Existing player safety checks should be reused, then parameterized under the V2 policy.

## V1 Behaviour To Fix

- AI team dead air caused by stuck vehicles or broken waypoints.
- Player proximity acting as an infinite cleanup blocker.
- Silent deletion or recycling with no RPT explanation.
- Repeated stuck incidents in the same place without route memory.
- Cleanup that removes still-useful combat pressure too early.

## Builder Requirements

Add one default-off flag:

- `WFBE_C_AICOM_V2_LIFECYCLE = 0`

Recommended parameters:

- `WFBE_C_AICOM_V2_LIFE_SAMPLE_SEC`: progress sample interval.
- `WFBE_C_AICOM_V2_LIFE_STALLED_SEC`: time before active team becomes stalled.
- `WFBE_C_AICOM_V2_LIFE_STUCK_SEC`: time before stalled team becomes stuck.
- `WFBE_C_AICOM_V2_LIFE_RECOVER_SEC`: recovery attempt window before recycle/despawn.
- `WFBE_C_AICOM_V2_LIFE_PROGRESS_MIN`: minimum meaningful movement progress.
- `WFBE_C_AICOM_V2_LIFE_PLAYER_RADIUS`: radius for player proximity caution.
- `WFBE_C_AICOM_V2_LIFE_PLAYER_GRACE_SEC`: extra stuck age required when player proximity exists.
- `WFBE_C_AICOM_V2_LIFE_PLAYER_HARD_BLOCK = 0`: optional compatibility switch. `0` means proximity is caution only; `1` restores hard-block behaviour for testing or owner preference.
- `WFBE_C_AICOM_V2_LIFE_STUCK_MEMORY_SEC`: memory expiry for stuck route/location.

Flag-off must be inert and byte-identical. Do not wire `WFBE_C_SIM_GATING`.

## Cleanup Decision Matrix

Cleanup is allowed when all are true:

- Team or asset is in `stuck` or `recovering` beyond configured threshold.
- It has no useful active combat contribution.
- Re-route/reassign attempts failed or are not applicable.
- Cleanup executor is legal V1 cleanup path.
- Player proximity policy allows cleanup.

If player is within `WFBE_C_AICOM_V2_LIFE_PLAYER_RADIUS`:

- Add `WFBE_C_AICOM_V2_LIFE_PLAYER_GRACE_SEC` before cleanup.
- Require an always-on RPT line before cleanup.
- If `WFBE_C_AICOM_V2_LIFE_PLAYER_HARD_BLOCK > 0`, block cleanup and log `playerHardBlock`.
- If hard block is `0`, allow cleanup after grace and log `playerProximityRelaxed`.

Cleanup is denied when:

- Asset is actively engaging or recently engaged.
- Asset is carrying critical player-facing state that V1 cleanup cannot safely preserve.
- The only evidence is a transient low-progress sample.

## Soak Acceptance Checks

- Lifecycle state transitions appear in HC RPT for at least one stalled/stuck/recovered team in a forced or natural soak.
- No team remains stuck beyond `stuck + recover + player grace` when cleanup is legal.
- When a player is near, cleanup is either delayed by grace or hard-blocked by parameter, with explicit log reason.
- Stuck location memory is generated and later movement avoids the punished route where alternatives exist.
- No active combat unit is deleted solely due to one low-progress sample.
- No A3-only lint failures or RPT script errors.

## Report Requirements For Builder PR

The later PR must cite GUIDE-REV `GR-2026-07-03a`, name `WFBE_C_AICOM_V2_LIFECYCLE` default `0`, call out the parameterized player-proximity policy, prove flag-off inertness, include HC RPT cleanup examples, and confirm mirrors.
