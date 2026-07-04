# AI Commander Base Artillery Threat Scan Audit - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@b2dbab5f3070c2bc8cacc79c06b9ca5ac20a2493`.

Scope: fleet lane 114, which flagged `AI_Commander_Base.sqf` for a hard-coded
`nearestObjects [_scanPos, [...], 10000]` scan. This pass is docs-only because
the current build84 target already carries a default-off radius tuning guard in
both maintained mission roots.

No mission source, generated Takistan files, AI commander behavior, scan cadence,
scan classes, default radius, lobby parameters, live deploy, or package artifacts
are changed here.

## Verdict

Lane 114 is already implemented on the checked target as a default-preserving
tuning hook.

The current behavior remains the legacy 10000 metre scan unless
`WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE` is explicitly set above 0. When the
flag is enabled, `AI_Commander_Base.sqf` reads
`WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS`; negative configured values are clamped to
0 before the `nearestObjects` call.

The scan is also now anchored at the enemy HQ, not the local HQ. That preserves
the counter-battery intent while avoiding a blind 10km sweep around the wrong
base.

## Evidence

| Surface | Chernarus evidence | Takistan evidence | Status |
| --- | --- | --- | --- |
| Default-off enable flag | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:430` sets `WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE = 0` if nil. | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:430` has the same fallback. | Legacy 10000 metre behavior is preserved by default. |
| Tunable radius fallback | `Init_CommonConstants.sqf:431` sets `WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS = 10000` if nil. | `Init_CommonConstants.sqf:431` has the same fallback. | Opt-in radius value exists without changing default behavior. |
| Enemy-HQ scan anchor | `AI_Commander_Base.sqf:504-510` documents and uses the enemy HQ as `_scanPos`. | `AI_Commander_Base.sqf:504-510` matches. | The cond-c scan targets the enemy base area instead of the local base area. |
| Radius gate | `AI_Commander_Base.sqf:511-515` initializes `_artyScanRadius = 10000`, then reads the configurable radius only when the enable flag is `> 0`, clamping negative values to 0. | `AI_Commander_Base.sqf:511-515` matches. | Tuning is available, default-off, and bounded. |
| Object scan | `AI_Commander_Base.sqf:527` calls `nearestObjects [_scanPos, ["StaticWeapon","Tank","Car"], _artyScanRadius]`. | `AI_Commander_Base.sqf:527` matches. | The old literal `10000` is no longer embedded in the call site. |

`git diff --no-index` reports no content diff between the maintained Chernarus
and Takistan copies of the checked `AI_Commander_Base.sqf` and
`Init_CommonConstants.sqf` files.

## Non-Findings

- The default value is still 10000 metres. That is intentional compatibility
  behavior because the lane asked for a shrink or throttle, and current source
  made that tuning opt-in rather than changing live AI commander behavior.
- The scan still runs after the one-hour gate while threat is not yet confirmed.
  This pass does not change cadence because the active target only needs the
  stale prompt row closed, not a new AI commander behavior decision.
- There is no LoadoutManager work for this PR. The source roots already match
  for the audited files, and this PR changes documentation only.

## Recommendation

Treat lane 114 as implemented on `claude/build84-cmdcon36`. Future runtime or
soak work can opt into a smaller scan radius by setting
`WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS_ENABLE = 1` and choosing a mission-specific
`WFBE_C_AICOM_ARTY_THREAT_SCAN_RADIUS` value, then watching for
`ARTY_THREAT_ARMED|cond-c` telemetry.

Do not shrink the default in a stale-lane cleanup PR. That would alter late-game
AI commander counter-battery behavior without fresh runtime evidence.

## Verification

- `rg` confirmed the scan-radius constants and `nearestObjects` call in both
  maintained mission roots.
- `git diff --no-index` confirmed the relevant maintained Chernarus and Takistan
  `AI_Commander_Base.sqf` copies are content-equal.
- `git diff --no-index` confirmed the relevant maintained Chernarus and Takistan
  `Init_CommonConstants.sqf` copies are content-equal.
- This PR is docs-only; no SQF, SQM, HPP, EXT, generated package, or live server
  artifact changed.
- LoadoutManager was not run because no mission source changed.
