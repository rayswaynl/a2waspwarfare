# Group-Cap Hygiene Status

Date: 2026-07-02
Lane: fleet lane 48, status-only
Base checked: `origin/claude/build84-cmdcon36` at `b2dbab5f3`

## Scope

Lane 48 asked for group-count telemetry plus a conservative empty-group reaper
for the Arma 2 OA per-side group cap. This pass checks the current target before
touching source.

No SQF, SQM, HPP, EXT, generated Takistan files, HC architecture, live server
settings, or package artifacts are changed here.

## Verdict

The lane is already implemented on the current target. Do not reclaim lane 48 as
"add group-cap telemetry" or "add empty-group GC" unless a later branch removes
these systems or runtime RPT evidence shows a new gap.

The current target already has:

- a central `createGroup` wrapper with emergency GC, source attribution and
  debounced failure warnings;
- a server-only 60-second group GC loop with group-count cache, cap warnings and
  telemetry wire lines;
- a client/headless-client local empty-group reaper for groups the server cannot
  delete because locality is wrong;
- Chernarus/Takistan parity for the checked group-GC files.

## Evidence Table

| Surface | Current target evidence | Lane 48 status |
| --- | --- | --- |
| Central group creation wrapper | `Common/Init/Init_Common.sqf:117` compiles `WFBE_CO_FNC_CreateGroup`; `Common/Functions/Common_CreateGroup.sqf:35-54` runs an emergency collect-then-delete GC at 140 groups, `:69-79` creates the group, warns on `grpNull`, and tags successes with `wfbe_group_src`. | Implemented |
| Server empty-group GC | `Server/Init/Init_Server.sqf:1047` starts `Server/FSM/server_groupsGC.sqf`; the loop is server-only at `server_groupsGC.sqf:9`, runs every 60 seconds at `:16-17`, collects candidates before deletion at `:28-45`, and skips persistent groups before `deleteGroup`. | Implemented |
| Server group-count cache | `server_groupsGC.sqf:338-341` publishes `wfbe_grpcnt_west`, `wfbe_grpcnt_east`, `wfbe_grpcnt_guer`, and `wfbe_grpcnt_t` for other loops to read instead of rescanning `allGroups`. | Implemented |
| Server telemetry | `server_groupsGC.sqf:349` emits `GCSTAT\|v1`, `:376` emits `GUERCAP\|v1`, `:552` emits `EMPTYGRP\|v1`, `:556` emits `DELEGSTAT\|v1`, `:572` emits `TOWNSTAT\|v1`, and `:594-595` emit `ORBATSTAT\|v1`. | Implemented |
| Cap warnings | `server_groupsGC.sqf:387,395,404,412,421,429` warn when WEST/EAST/GUER approach 130 groups or reach 144 groups. | Implemented |
| Player-client local GC | `Client/Init/Init_Client.sqf:583` starts `Client/Functions/Client_GroupsGC.sqf`; the worker runs on clients and HCs but skips the dedicated server at `Client_GroupsGC.sqf:24-25`. | Implemented |
| Headless-client local GC | `Headless/Init/Init_HC.sqf:224-234` documents the HC-local group leak and starts the same `Client_GroupsGC` worker for headless clients. | Implemented |
| Client/HC telemetry | `Client_GroupsGC.sqf:37-38` runs every 60 seconds, `:42` protects delegated-town tracked groups, `:82` deletes confirmed local empty candidates, and `:90-99` emits `CLIENT_EMPTY_GROUP_CLEANUP\|v1` plus a human-readable companion line. | Implemented |

## Parity Check

The checked files are byte-equivalent between source Chernarus and maintained
Takistan on this branch:

| File | Chernarus / Takistan SHA-256 prefix |
| --- | --- |
| `Common/Functions/Common_CreateGroup.sqf` | `C10A6D21264A` |
| `Server/FSM/server_groupsGC.sqf` | `E4ACED9F526D` |
| `Client/Functions/Client_GroupsGC.sqf` | `4057C794EF35` |
| `Client/Init/Init_Client.sqf` | `28EFC31FED3E` |
| `Headless/Init/Init_HC.sqf` | `2B046B9013B4` |

## Non-Goals

- Do not add another empty editor-slot reaper. The current source documents that
  the boot-time editor-slot sweep must stay audit-only because empty JIP-selectable
  slot groups are not safe deletion candidates.
- Do not change HC locality or delegation architecture under this lane.
- Do not distance/simulation-gate combat AI.
- Do not tune `WFBE_C_GROUPAUDIT_EVERY`, group caps, GC intervals or warning
  thresholds without runtime evidence from a soak/RPT pass.

## Verification

- Reviewed the current target source under `origin/claude/build84-cmdcon36`.
- Confirmed group-GC and launch-path anchors in source Chernarus.
- Confirmed the checked Chernarus and maintained Takistan files have matching
  SHA-256 hashes.
- Confirmed this PR is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
