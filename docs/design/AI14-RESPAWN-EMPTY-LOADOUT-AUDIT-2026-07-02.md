# AI14 Respawn Empty-Loadout Audit - 2026-07-02

## Verdict

Lane 119 is already fixed on the live target branch. The prompt still lists
`AI_SquadRespawn.sqf` and `AI_AdvancedRespawn.sqf` as vulnerable to an empty
AI loadout array, but `origin/claude/build84-cmdcon36` at
`b1608b096eb4a02d7c213d794e22b8bc59df8df0` already guards both the upgrade
index and the loadout-array count before the random `select`.

No mission source change is needed for this lane.

## Current Target Evidence

Maintained Chernarus root:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_SquadRespawn.sqf:56-61`
  documents the `_upgrades` guard, checks `count _upgrades > 13`, then checks
  `count _loadout > 0` before `_loadout select floor (random count _loadout)`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_AdvancedRespawn.sqf:68-73`
  has the same guard sequence before the respawned unit is equipped.

Maintained Takistan mirror:

- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/AI_SquadRespawn.sqf:56-61`
  matches the Chernarus squad respawn guard.
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/AI_AdvancedRespawn.sqf:68-73`
  matches the Chernarus advanced respawn guard.

The risky expression still exists, but it is now nested inside the
`count _loadout > 0` branch, so an empty loadout array skips equipment selection
instead of evaluating `random 0` / `select 0`.

## Prior PR Trail

- PR #204, `[fable] Lane 119: guard AI respawn loadout pick against empty
  upgrades array`, was merged into `claude/build84-cmdcon36` on 2026-07-02.
- PR #206, `Lane 119: guard AI respawn loadout selection`, was closed as the
  duplicate lane-119 implementation.
- `git branch -r --contains c49d87ae6` includes
  `origin/claude/build84-cmdcon36`, confirming the merged lane-119 fix is in
  the current target lineage.

## Scope Notes

This audit only covers the AI14 empty-loadout crash described in lane 119.
It does not change AI respawn behavior, mobile respawn selection, player
respawn, GUER gear defaults, or any mission mirror output. Because this is a
docs-only stale-lane audit, `Tools/LoadoutManager` was not run.
