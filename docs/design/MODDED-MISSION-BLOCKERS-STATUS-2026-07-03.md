# Modded Mission Blockers Status - 2026-07-03

## Scope

This is a docs-only status note for the in-tree `Modded_Missions` folders on
`origin/claude/build84-cmdcon36`. It does not repair or regenerate any modded
mission fork.

## Current Finding

`Modded_Missions` is still not a runnable release surface. Current generation
and packaging flows do not maintain these folders, and the checked modded forks
still have syntax and bootstrap blockers that should prevent any release note
from claiming supported modded missions.

The current line-start conflict-marker scan finds 18 files:

| Mission folder | Files with marker blocks |
| --- | ---: |
| `Modded_Missions/[55-2hc]warfarev2_073v48co.Napf` | 5 |
| `Modded_Missions/[55-2hc]warfarev2_073v48co.eden` | 4 |
| `Modded_Missions/[55-2hc]warfarev2_073v48co.lingor` | 9 |

The affected files are:

| Mission | File |
| --- | --- |
| Napf | `description.ext` |
| Napf | `Client/Module/Skill/Skill_Init.sqf` |
| Napf | `Common/Config/Core_Structures/Structures_CO_US.sqf` |
| Napf | `Common/Config/Core_Units/Units_RU.sqf` |
| Napf | `Common/Module/IRS/IRS_OnIncomingMissile.sqf` |
| eden | `Client/Action/Action_RepairMHQ.sqf` |
| eden | `Client/Module/Skill/Skill_Apply.sqf` |
| eden | `Client/Module/Skill/Skill_Init.sqf` |
| eden | `Common/Config/Core_Structures/Structures_CO_RU.sqf` |
| lingor | `Client/Client_UpdateRHUD.sqf` |
| lingor | `Client/Module/Nuke/nukeincoming.sqf` |
| lingor | `Common/Config/Core_Artillery/Artillery_CO_US.sqf` |
| lingor | `Common/Config/Core_Root/Root_RU.sqf` |
| lingor | `Common/Config/Core_Root/Root_TKA.sqf` |
| lingor | `Common/Config/Core_Root/Root_US.sqf` |
| lingor | `Common/Config/Core_Root/Root_US_Camo.sqf` |
| lingor | `Common/Config/Core_Root/Root_USMC.sqf` |
| lingor | `Common/Init/Init_Unit.sqf` |

Napf, eden, and lingor also still compile `Common/Functions/Common_GetTotalCamps.sqf`
from `Common/Init/Init_Common.sqf`, but that helper is not tracked inside those
modded mission folders.

## Release Gate

Do not describe `Modded_Missions` as supported, packaged, runnable, generated, or
validated until an owner chooses one of these routes:

- Regenerate supported modded missions from the maintained source model.
- Maintain them as explicit terrain forks with separate repair, parity, and boot
  smoke evidence.
- Retire or exclude them from release claims and packaging documentation.

Any supported route needs all marker blocks removed, missing helper references
resolved, generated/runtime bootstrap files restored, and Arma boot smoke for
each supported terrain.

## Validation

- Current line-start conflict-marker scan over `Modded_Missions` found 18 files.
- Current `Common_GetTotalCamps.sqf` reference scan found Napf, eden, and lingor
  compile the helper from `Common/Init/Init_Common.sqf`.
- No mission source, generated mission source, tool code, packaging, deploy, or
  live-server action was changed.
