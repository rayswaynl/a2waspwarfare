# Lane 97 - HC Top-Up Status Audit

Date: 2026-07-03
Target: `claude/build84-cmdcon36` @ `b1608b096eb4a02d7c213d794e22b8bc59df8df0`
Scope: docs-only status audit; no mission source changed.

## Summary

Lane 97 asks for the HC team top-up worker: under-strength HC-resident AICOM teams should receive replacement infantry on the owning HC, behind a safe flag and a verified HC-side consumer.

The current live target is in a mixed state:

- The draft worker file exists in Chernarus, Takistan, and Zargabad.
- `WFBE_C_AICOM_HC_TOPUP_ENABLE` defaults to `1` in all three maintained mission roots.
- The AICOM supervisor has a nil-guarded call site for `WFBE_SE_FNC_AI_Com_HCTopUp`.
- `Init_Server.sqf` does not compile `AI_Commander_HCTopUp.DRAFT.sqf` into `WFBE_SE_FNC_AI_Com_HCTopUp`, so the call site is inert.
- `Client/PVFunctions/HandleSpecial.sqf` has the HC merge consumer, `aicom-team-merge`, but no `aicom-team-topup` consumer.

Result: the top-up flag looks enabled, but the actual top-up worker is unreachable on this target.

## Evidence

| Check | Current anchor | Status |
| --- | --- | --- |
| Top-up default | `Common/Init/Init_CommonConstants.sqf:1075` in Chernarus, Takistan, and Zargabad | `WFBE_C_AICOM_HC_TOPUP_ENABLE = 1` |
| Merge default | `Common/Init/Init_CommonConstants.sqf:1074` in Chernarus, Takistan, and Zargabad | `WFBE_C_AICOM_HC_MERGE_ENABLE = 0` |
| Supervisor gate | `Server/AI/Commander/AI_Commander.sqf:423-428` in Chernarus, Takistan, and Zargabad | Reads merge/top-up flags and calls only if `WFBE_SE_FNC_AI_Com_HCTopUp` is non-nil |
| Compile hook | `Server/Init/Init_Server.sqf:82-86` in Chernarus, Takistan, and Zargabad | AICOM helpers compile, but no `WFBE_SE_FNC_AI_Com_HCTopUp` compile was found |
| Draft worker | `Server/AI/Commander/AI_Commander_HCTopUp.DRAFT.sqf:1-31` | Header still labels the worker draft/not wired and says the HC-side top-up consumer is still to write |
| Merge consumer | `Client/PVFunctions/HandleSpecial.sqf:57` in Chernarus, Takistan, and Zargabad | `case "aicom-team-merge"` exists |
| Top-up consumer | `Client/PVFunctions/HandleSpecial.sqf` in Chernarus, Takistan, and Zargabad | No `case "aicom-team-topup"` found |
| Draft top-up send path | `AI_Commander_HCTopUp.DRAFT.sqf:251-253` | Worker can emit `aicom-team-topup`, but no live consumer handles it |

## Interpretation

The live branch has enough scaffolding to confuse future work:

1. The top-up constant is default-on, so reading constants alone suggests lane 97 is active.
2. The supervisor nil guard prevents any runtime call because the worker function is never registered.
3. The existing client `aicom-team-merge` case only covers depleted-team merging, not top-up creation.
4. The draft worker's bottom comment still says the missing `aicom-team-topup` consumer must be written before enabling.

This should not be treated as a simple "flip the compile line" lane. Compiling the worker without the HC-side top-up consumer would route requests to a missing `HandleSpecial` case. Enabling a top-up path also needs owner confirmation because this target currently ships the top-up flag as `1`, contrary to the fleet default-off rule for new behavior.

## Recommended Next Slice

For a future source PR, keep it separate from this docs audit and do all of these together:

1. Decide the owner default for `WFBE_C_AICOM_HC_TOPUP_ENABLE`; safest grading shape is default `0` until smoke proves it.
2. Add the HC-local `case "aicom-team-topup"` consumer in `Client/PVFunctions/HandleSpecial.sqf`, adjacent to `delegate-aicom-team` and `aicom-team-merge`.
3. Route top-up requests directly to live HC owners with the same `SendToClient` shape used by `delegate-aicom-team`, instead of relying on a server broadcast path.
4. Compile the worker only after the consumer and routing contract are present.
5. Run a two-HC smoke with RPT proof that under-strength HC infantry teams climb back toward the 8-12 band without spawning near players or in combat.

## Verification

- `rg` found `WFBE_C_AICOM_HC_TOPUP_ENABLE = 1` and `WFBE_C_AICOM_HC_MERGE_ENABLE = 0` in all three maintained mission roots.
- `rg` found no `WFBE_SE_FNC_AI_Com_HCTopUp` or `AI_Commander_HCTopUp` compile hook in all three `Server/Init/Init_Server.sqf` files.
- `rg` found `case "aicom-team-merge"` but no `case "aicom-team-topup"` in all three `Client/PVFunctions/HandleSpecial.sqf` files.
- Docs-only change; no SQF source edited.
- LoadoutManager not run because no mission source changed.
- No package, deploy, or live-server action.
