# AICOM D4 Target-Aware Composition Status

Date: 2026-07-03
Lane: 102
Target branch: `claude/build84-cmdcon36`

## Verdict

D4 target-aware team compositions are not live on the current target branch.

The maintained mission roots have the current AICOM type-mix, town-punch, mechanized, air-time, config-cost, and dismount-carrier weighting, but they do not have the D4 target-aware constants or telemetry that would reweight founding templates by target-town shape.

## Current target behavior

Current commander team founding first buckets eligible templates by stored type and rolls an infantry/light/heavy/air class from the maturity-ramped type mix:

- Chernarus: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:657`
- Takistan: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf:657`
- Zargabad: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf:657`

Those bucket weights are then nudged by doctrine, town-punch, mechanized/motorized bias, air-time bias, and the request-unit hook before empty buckets are zeroed:

- `WFBE_C_AICOM_TOWNPUNCH_HEAVY_MULT` and `WFBE_C_AICOM_TOWNPUNCH_LIGHT_MULT` are applied around `AI_Commander_Teams.sqf:683`.
- `WFBE_C_AICOM_MECH_BIAS` and `WFBE_C_AICOM_MOTOR_BIAS` are applied around `AI_Commander_Teams.sqf:683`.
- `WFBE_C_AICOM_AIR_TIME_BIAS_*` is applied around `AI_Commander_Teams.sqf:685`.

After a bucket is chosen, the current branch chooses a template inside that bucket from config combat cost plus `WFBE_C_AICOM_DISMOUNT_BIAS`:

- Chernarus: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:732`
- Takistan: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander_Teams.sqf:732`
- Zargabad: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander_Teams.sqf:732`

The relevant existing constants are mirrored across all three roots at:

- `Init_CommonConstants.sqf:440` for `WFBE_C_AICOM_TYPE_MIX`
- `Init_CommonConstants.sqf:446-450` for early/mid/late mix maturity tiers
- `Init_CommonConstants.sqf:491` for `WFBE_C_AICOM_MECH_BIAS`
- `Init_CommonConstants.sqf:496` for `WFBE_C_AICOM_DISMOUNT_BIAS`
- `Init_CommonConstants.sqf:1069-1070` for town-punch multipliers

## Missing D4 signals

A target-wide search across Chernarus, Takistan, and Zargabad found no live matches for:

- `WFBE_C_AICOM_TARGET_AWARE_COMP`
- `AICOMCOMP`
- `COMP_GARRISON`
- `COMP_OPEN`
- `COMP_ATMG`
- `COMP_MECH`

That means the current target does not yet have a switch-gated pass that says, for example, "this target has many camps/garrisons, bias AT/MG or armor-piercing composition templates" or "this is an open low-supply village, bias light/mechanized templates."

## Route PR

The live route for this lane is draft PR #307:

- PR: `https://github.com/rayswaynl/a2waspwarfare/pull/307`
- Title: `[fable] AICOM D4: target-aware team compositions (flag, default 0)`
- Head: `fable/aicom-d4-target-aware-comp`
- Head OID: `41a7c2cafb19808df8b25a11a8986c672203222d`
- State at audit time: open draft, clean, mergeable

PR #307 adds the intended default-off constants (`WFBE_C_AICOM_TARGET_AWARE_COMP = 0`, garrison/open-town thresholds, and ATMG/mech multipliers) and reweights the pre-random within-tier template draw based on the target town. It changes Chernarus and Takistan only, so Zargabad propagation should be reviewed before treating the lane as fully landed for all maintained mission roots.

## Lane boundary

This lane intentionally makes no source changes. It records the current status so fleet workers can avoid duplicate D4 implementation attempts and route any source review through PR #307.
