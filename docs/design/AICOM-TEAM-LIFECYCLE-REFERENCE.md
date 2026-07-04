# AICOM Team Lifecycle Reference

Target ref: `claude/build84-cmdcon36` at `57302322` when this page was written.

Scope: this is a read-only source reference for the current AICOM team path from founding to journey, arrival, capture, hold and base assault. It documents the existing Chernarus source root and the source-side design docs. It does not change mission runtime code, AICOM behavior, generated map mirrors, packages or live server state.

Prior art:

- `docs/design/AICOM-UNIT-BEHAVIOR-FABLE.md` explains why Build 86 moved teams away from all-RED marching and added recovery/stickiness work.
- `docs/design/REAL-BASE-ASSAULT.md` explains the real-destruction base assault goal.
- `docs/design/SPREAD-AND-HOLD.md` explains allocator spread and first-captor hold.
- PR #267 / lane 165 is adjacent prior art for stuck recovery v2; this page is the broader lifecycle route map.

## Lifecycle Map

| Phase | Primary owner | Current source anchors | What to check |
| --- | --- | --- | --- |
| Team budget and founding gate | `Server/AI/Commander/AI_Commander_Teams.sqf` | `:33`, `:44-65`, `:69-128`, `:229` | Reads `wfbe_teams`, counts founded/editor/pending groups, applies dynamic target and exits when founded plus pending reaches target. |
| HC dispatch or server fallback | `AI_Commander_Teams.sqf`, `Client/PVFunctions/HandleSpecial.sqf`, `Common_RunCommanderTeam.sqf` | `Teams.sqf:1119-1215`, `Teams.sqf:1217-1244`, `HandleSpecial.sqf:51`, `RunCommanderTeam.sqf:3-11` | Preferred path dispatches `delegate-aicom-team` to a live HC. No-HC path founds a server-local empty group and lets AssignTypes/Produce fill it. |
| Initial driver posture | `Common/Functions/Common_RunCommanderTeam.sqf` | `:94-97` | Fresh driver groups begin `RED` / `AWARE` / `FULL`; objective waypoints still take over later. |
| Strategic target selection | `AI_Commander_Strategy.sqf`, `AI_Commander_Allocate.sqf` | `Strategy.sqf:120-155`, `:365-393`, `Allocate.sqf:4-15`, `:130`, `:296-388`, `:513` | Strategy picks front posture; Allocate writes per-team `wfbe_aicom_alloc_target` for fist, expansion, harass, feint and reinforce work. |
| Town assignment and journey commit | `AI_Commander_AssignTowns.sqf` | `:48-64`, `:522-546`, `:693-761` | Assignment writes standard team move variables, publishes HC `wfbe_aicom_order`, latches `wfbe_aicom_townorder` and emits `ASSAULT_DISPATCH`. |
| Road-march route | `Common_RunCommanderTeam.sqf`, `Common_BuildRoadRoute.sqf` | `RunCommanderTeam.sqf:1176-1238`, `:1247-1280`; `BuildRoadRoute.sqf:32-61` | Vehicle teams and long foot legs get road-node chains, lane offsets and a final tight destination node. |
| Recovery during journey | `Common_RunCommanderTeam.sqf` | `:954-1091` | Recovery v2 handles unstuck pulses, driver swap, slope-aware foot snap, water guard and road-node teleport only on the stuck path. |
| Careful-gear governor | `Common_RunCommanderTeam.sqf` | `:1301-1358`; `Init_CommonConstants.sqf:369` | Convoys downshift to `LIMITED` only after steep grade dwell and return to `FULL` once the condition clears. |
| Arrival latch | `Common_RunCommanderTeam.sqf` | `:1363-1471` | When the leader reaches the arrival gate the driver reasserts `RED`, releases road bias, sets `COMBAT` / `RED`, then lays the assault SAD. |
| Capture and hold | `Common_RunCommanderTeam.sqf`, `AI_Commander_AssignTowns.sqf` | `RunCommanderTeam.sqf:1658-2049`, `AssignTowns.sqf:254-272` | Town capture dismounts, attacks camp/depot defenders, then first captor can claim a timed hold with `HOLD-CLAIM`. |
| Base assault and victory pressure | `AI_Commander_Strategy.sqf`, `Common_RunCommanderTeam.sqf` | `Strategy.sqf:684-883`, `:925-958`; `RunCommanderTeam.sqf:1532-1646` | HQ strike publishes `goto`; the driver uses real target/fire orders against enemy HQ/factory structures and strategy records base-overrun pressure. |

## Founding And Ownership

The server brain owns the team budget. `AI_Commander_Teams.sqf` reads the side logic `wfbe_teams`, separates founded teams from editor-slot teams, adds `wfbe_aicom_pending`, and compares that total to the dynamic target. The dynamic target path is visible around `AI_Commander_Teams.sqf:69-128`; it can emit `AICOMSTAT|v2|EVENT|...|TEAMS_TARGET|...` when player-count scaling changes the effective target.

The normal founding route is HC-local:

1. `AI_Commander_Teams.sqf:1119-1120` increments pending before dispatch.
2. `AI_Commander_Teams.sqf:1201` sends `delegate-aicom-team` to the selected HC.
3. `Client/PVFunctions/HandleSpecial.sqf:51` spawns `WFBE_CO_FNC_RunCommanderTeam`.
4. `Common_RunCommanderTeam.sqf:3-11` describes the HC driver and the public order variable.

If no live HC is available, `AI_Commander_Teams.sqf:1217-1244` creates a server-local group, stamps `wfbe_aicom_founded`, appends it to `wfbe_teams`, and logs `TEAM_FOUNDED` on the same v2 event schema as the HC path. That fallback is not the modern happy path, but it matters when reading RPTs from no-HC tests.

Telemetry to recognize:

- `AICOMSTAT|v2|EVENT|<side>|<min>|TEAM_FOUNDED|via=HC|...`
- `AICOMSTAT|v2|EVENT|<side>|<min>|TEAM_FOUNDED|via=server-local|...`
- `AICOMSTAT|v2|EVENT|<side>|<min>|HCDISPATCH|pending=...`
- `AICOMSTAT|v2|EVENT|<side>|<min>|TEAM_RETIRED|reason=pc-scale|...`

## Orders And Target Selection

The HC driver reads only `wfbe_aicom_order`, not `wfbe_teammode` / `wfbe_teamgoto`. That is why the commander files publish both the standard movement variables and a public order array for HC-resident teams.

Key order writers:

- `AI_Commander_AssignTowns.sqf:693-761` publishes town work as `[seq, "towns-target", pos, strikeTier]` and records `wfbe_aicom_townorder`.
- `AI_Commander_Strategy.sqf:532` publishes defense relief orders for HC teams.
- `AI_Commander_Strategy.sqf:667` publishes rally orders.
- `AI_Commander_Strategy.sqf:791` and `:883` publish enemy-HQ `goto` orders for strike/base-assault pressure.
- `AI_Commander_Execute.sqf:71-100` publishes human command orders to HC teams.

The assignment layer is sticky on purpose. `AI_Commander_AssignTowns.sqf:48-64` treats already en-route teams as assigned, and `:522-546` keeps a progressing journey from being retargeted every strategy tick. The important breadcrumb is `wfbe_aicom_townorder`, written on dispatch at `:749-753` and read during stuck/arrival accounting.

Allocator telemetry is the compact "what did the brain intend this tick?" line:

```text
AICOM2|v1|ALLOC|<side>|<min>|fist=N|primary=...|src=...|harassTo=...|assigned=N|harass=N|expand=N|teams=N|myTowns=N|expandFirst=...|concentrate=...
```

The current source emits it at `AI_Commander_Allocate.sqf:513`.

## Journey Driver

The driver loop reads `wfbe_aicom_order` around `Common_RunCommanderTeam.sqf:918`. On a new sequence, it wipes and re-lays waypoints for the order instead of allowing stale waypoints to accumulate.

For mounted teams, `Common_RunCommanderTeam.sqf:1176-1238` converts a long bare move into a road march:

- `WFBE_C_AICOM_MARCH_YELLOW` controls whether transit combat mode is `YELLOW` or legacy `RED`.
- `Common_BuildRoadRoute.sqf:32-61` first snaps to a base-egress road node, then builds tapered lateral road nodes so concentrated teams do not stack on the same line.
- Intermediate nodes use `AWARE` / march combat mode / `COLUMN` / `FULL`.
- The final node on the destination stays `AWARE` / `RED` / `COLUMN` / `FULL` so the arrival latch can take over.

For pure infantry or long foot legs, `Common_RunCommanderTeam.sqf:1247-1280` keeps the same principle: march in column, keep a live MOVE chain, and let the arrival branch re-task the team into combat. This is the practical answer to the old "teams fight the whole road" failure mode documented in `AICOM-UNIT-BEHAVIOR-FABLE.md`.

Recovery v2 is part of the journey, not the planner. The block at `Common_RunCommanderTeam.sqf:954-1091` fires only when the driver detects a stuck path and the `WFBE_C_AICOM_RECOVERY_V2` gate is on. It is layered:

- unflip / unstuck event bookkeeping;
- dead-driver crew swap;
- reverse pulse and lane flip;
- road-node teleport only for the severe tier;
- player-visible guard, water guard and slope-aware foot snap.

The careful-gear governor at `Common_RunCommanderTeam.sqf:1301-1358` is separate from recovery. It reads `WFBE_C_AICOM_GRADE_DWELL` and only downshifts a convoy to `LIMITED` after the grade condition persists; it restores `FULL` once clear.

## Arrival, Capture And Hold

Arrival begins when the leader is inside the calculated arrival gate at `Common_RunCommanderTeam.sqf:1365-1369`. The branch is important because it changes the meaning of the order from travel to fight:

- `Common_RunCommanderTeam.sqf:1372-1384` reasserts `RED`, releases road bias and prepares overland combat.
- `Common_RunCommanderTeam.sqf:1394` sets default arrival posture to `COMBAT` / `RED`.
- `Common_RunCommanderTeam.sqf:1469-1471` lays ground SAD waypoints with `WEDGE` / `NORMAL`.
- Fixed-wing teams split out at `:1453-1469` so planes orbit attack instead of receiving a ground WEDGE SAD.

Town capture starts at `Common_RunCommanderTeam.sqf:1658`. The key shape is:

- mounted teams have already delivered infantry; capture works from the live infantry state instead of assuming cargo is still seated;
- camp phase can lay MOVE/SAD waypoints and direct live units with `doTarget` / `doFire` (`:1828`, `:1848`, `:1858`);
- depot-center phase uses `COMBAT` / `RED` / `LINE` at `:1926` to avoid a bunched WEDGE at the center;
- secondary center pressure can still use `WEDGE` at `:2123`.

The hold handoff is a first-captor latch, not a planner assignment. At `Common_RunCommanderTeam.sqf:2033-2049`, the driver reads `WFBE_C_AICOM_HOLD_MODE`, stamps `wfbe_aicom_hold_until`, broadcasts `defense` via `SetTeamMoveMode`, broadcasts town center via `SetTeamMovePos`, sets `wfbe_aicom_holding_town`, and logs `HOLD-CLAIM`. `AI_Commander_AssignTowns.sqf:254-272` later treats that held town as occupied so the team is not immediately pulled away.

Telemetry to recognize:

- `AICOMSTAT|v2|EVENT|<side>|<min>|ASSAULT_DISPATCH|...`
- `AICOMSTAT|v2|EVENT|<side>|<min>|ASSAULT_ARRIVED|...`
- `AICOMSTAT|v2|EVENT|<side>|<min>|ASSAULT_STRANDED|...`
- `AICOMSTAT|v2|EVENT|<side>|<min>|RECYCLE_FLAG|reason=stranded|...`
- `AICOMSTAT|v2|EVENT|<side>|<min>|CAPTURE_TRACE|ARRIVAL_GATE|...`
- `Common_RunCommanderTeam.sqf: [...] HOLD-CLAIM [...]`

## Base Assault Branch

Base assault is routed through `goto`, not `towns-target`. That distinction matters:

- `AI_Commander_Strategy.sqf:684-883` decides whether an HQ strike is active and publishes `goto` to HC teams.
- `Common_RunCommanderTeam.sqf:1532-1646` detects the arrived `goto` team, finds enemy HQ/factory structures, lays an assault SAD near the selected structure and orders live units through `reveal`, `doTarget` and `doFire`.
- `AI_Commander_Strategy.sqf:925-958` records base overrun/siege pressure and avoids claiming a scripted victory unless the real destruction path permits it.

Base assault log lines to correlate:

- `Common_RunCommanderTeam.sqf: [...] BASE-ASSAULT fire phase begin ...`
- `Common_RunCommanderTeam.sqf: [...] BASE-ASSAULT fire phase end ...`
- `AICOMSTAT|v1|EVENT|<side>|<min>|BASE_OVERRUN|...`
- `AICOMSTAT|v1|POSTURE|...`
- `AICOMSTAT|v1|FRONT|...`

## Read This Before Editing AICOM

Use this page as a route map, not as a replacement for source reads. The practical collision rules are:

- `Common_RunCommanderTeam.sqf` is the lifecycle executor. Any change to transit, recovery, arrival, capture, hold or base-assault behavior collides here.
- `AI_Commander_Teams.sqf` owns founding and team population. Do not fix driver behavior there.
- `AI_Commander_Allocate.sqf` owns per-team target intent. Do not add movement side effects there.
- `AI_Commander_AssignTowns.sqf` owns dispatch, journey accounting and assignment stickiness.
- `AI_Commander_Strategy.sqf` owns high-level posture, relief, rally and HQ-strike commits.

Docs-only lanes can usually cite this page without running `Tools/LoadoutManager`. Runtime SQF lanes still need the normal Chernarus-first edit, generated mirror pass, SQF trap scan, bracket balance verification and no-package guard from the fleet directive.
