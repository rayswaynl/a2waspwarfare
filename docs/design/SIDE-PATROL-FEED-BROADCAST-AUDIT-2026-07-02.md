# Side Patrol Feed Broadcast Audit - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@b2dbab5f3070c2bc8cacc79c06b9ca5ac20a2493`.

Scope: fleet lane 111, which flagged `server_side_patrols.sqf` for broadcasting
both `WFBE_ACTIVE_PATROLS` and `WFBE_ACTIVE_AICOM_TEAMS` every patrol cycle. This
pass is docs-only because the current build84 target already carries a
default-preserving change-aware broadcast option in both maintained mission
roots.

No mission source, generated Takistan files, marker-feed behavior, JIP catch-up
behavior, live deploy, or package artifacts are changed here.

## Verdict

Lane 111 is already implemented on the checked target as an opt-in feed tuning
hook.

The current default remains the legacy every-cycle rebroadcast for JIP safety:
`WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY = 0`. When operators set that flag above 0,
`server_side_patrols.sqf` publishes the patrol and AICOM marker feeds only when
the combined feed signature changes or when the keepalive interval expires.

The keepalive fallback is important. The comments at `server_side_patrols.sqf:82-95`
explain that Arma 2 OA `publicVariable` broadcasts are not replayed to later JIP
clients. A pure "only on change" path could strand late joiners with empty marker
feeds, so the current implementation keeps a bounded heartbeat in the opt-in
mode.

## Evidence

| Surface | Chernarus evidence | Takistan evidence | Status |
| --- | --- | --- | --- |
| Change-aware flag | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:900` sets `WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY = 0` if nil. | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:900` matches. | Legacy every-cycle rebroadcast is preserved by default. |
| Keepalive interval | `Init_CommonConstants.sqf:901` sets `WFBE_C_SIDE_PATROL_FEED_KEEPALIVE = 60` if nil. | `Init_CommonConstants.sqf:901` matches. | Opt-in mode keeps a bounded heartbeat. |
| JIP-safety rationale | `server_side_patrols.sqf:82-95` documents why both marker feeds must still reach JIP clients after connect-time catch-up. | `server_side_patrols.sqf:82-95` matches. | The lane is not reduced to a brittle change-only publish path. |
| Opt-in branch | `server_side_patrols.sqf:99-112` reads the flag, floors keepalive to at least 20 seconds, compares `str [WFBE_ACTIVE_PATROLS, WFBE_ACTIVE_AICOM_TEAMS]`, and publishes both feeds on change or keepalive due. | `server_side_patrols.sqf:99-112` matches. | Change-aware mode exists and is bounded. |
| Default branch | `server_side_patrols.sqf:113-118` still broadcasts both feeds every scrub cycle when the flag is 0. | `server_side_patrols.sqf:113-118` matches. | Existing live behavior remains unchanged. |

`git diff --no-index` reports no content diff between the maintained Chernarus
and Takistan copies of the checked `server_side_patrols.sqf` and
`Init_CommonConstants.sqf` files.

## Non-Findings

- The default still broadcasts both feeds every cycle. That is intentional
  compatibility behavior and protects JIP marker recovery.
- The opt-in path still publishes both `WFBE_ACTIVE_PATROLS` and
  `WFBE_ACTIVE_AICOM_TEAMS` together. That is deliberate because the client
  marker consumers need both current lists to recover cleanly.
- This pass does not add consumer-targeted `publicVariableClient` routing. The
  current source already provides the low-risk operator tuning hook; changing
  recipient routing would be a separate network-behavior decision that needs
  runtime proof.
- There is no LoadoutManager work for this PR. The source roots already match
  for the audited files, and this PR changes documentation only.

## Recommendation

Treat lane 111 as implemented on `claude/build84-cmdcon36`. Future runtime or
soak work can opt into change-aware mode with
`WFBE_C_SIDE_PATROL_FEED_CHANGE_ONLY = 1`, then tune
`WFBE_C_SIDE_PATROL_FEED_KEEPALIVE` while watching player join marker recovery
and RPT/network behavior.

Do not flip the default in a stale-lane cleanup PR. The unconditional rebroadcast
is explicitly preserving Arma 2 OA JIP durability.

## Verification

- `rg -F` confirmed the lane-111 constants and readers in both maintained roots.
- `git diff --no-index` confirmed the relevant maintained Chernarus and Takistan
  `server_side_patrols.sqf` copies are content-equal.
- `git diff --no-index` confirmed the relevant maintained Chernarus and Takistan
  `Init_CommonConstants.sqf` copies are content-equal.
- This PR is docs-only; no SQF, SQM, HPP, EXT, generated package, or live server
  artifact changed.
- LoadoutManager was not run because no mission source changed.
