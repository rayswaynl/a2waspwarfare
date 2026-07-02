# Lane 116 Dead Patrol Loop Audit - 2026-07-02

## Verdict

Lane 116 is already fixed in the current Build 88 base. No source change is needed.

The prompt item described the old `server_town_patrol.sqf` loop using `||`, which would keep a town-patrol monitor alive after the team died. Current Chernarus and Takistan source both use an `_aliveTeam` gate and a `while {!WFBE_GameOver && _aliveTeam}` loop, so the monitor exits as soon as the group has no live units or the group is null.

## Current evidence

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_patrol.sqf:9` exits immediately for a null group.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_patrol.sqf:18-25` computes `_aliveTeam` from live units and null-group state.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_patrol.sqf:21` uses `while {!WFBE_GameOver && _aliveTeam} do`.
- The Takistan mirror has the same guard and loop at the same line numbers.
- `Common/Functions/Common_CreateTownUnits.sqf:115-120` still launches `server_town_patrol.sqf` for valid town-AI groups, so this is not dead code. The live path is protected by the current loop guard.

## Adjacent prompt item

Lane 123's `Server_GetTownPatrol.sqf` SV boundary is also already patched in both roots:

- `Server/Functions/Server_GetTownPatrol.sqf:17-19` maps `<=30` to LIGHT, `>30 && <60` to MEDIUM, and `>=60` to HEAVY.
- Repo-wide caller search only finds the compile registration in `Init_Server.sqf`, not an active call site. The current side-patrol system is driven by `Server/FSM/server_side_patrols.sqf`.

## Scope decision

This PR does not edit mission source. Changing the patrol scripts again would risk touching the maintained town-AI patrol path without a live defect to fix. The correct action is to mark lane 116 stale against current base and keep the evidence close to the prompt queue.

## Verification

- Checked active brain claims and open PR/branch searches for lane 116 and lane 123; no live owner was found.
- Grepped both mission roots for `server_town_patrol.sqf`, `Server_GetTownPatrol`, and `WFBE_SE_FNC_GetTownPatrol`.
- Compared Chernarus and Takistan line-level evidence for the loop and SV boundary guards.
- No LoadoutManager mirror was run because the diff is docs-only.
