# Respawn Camp and HandleDamage Audit (Lane 38)

Date: 2026-07-03
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Verdict

Lane 38 is a stale/false-positive prompt row on the current target. No mission source change is needed.

The row bundled two AUDIT-60 follow-ups:

- `Common_GetRespawnCamps.sqf` was suspected of using invalid `isNil {code}` syntax and a bad `Private [...],;` declaration.
- `Init_Town.sqf` was suspected of returning the wrong value from a camp `handleDamage` event handler.

The current target already rejects both findings. `docs/design/MISSION-AUDIT-60.md` marks items 8 and 9 as rejected false positives, and the live source matches that verdict across Chernarus, Takistan, and Zargabad.

## Official References

Checked against Bohemia Interactive Community pages for the Arma 2 OA command family:

- `https://community.bistudio.com/wiki/isNil`
- `https://community.bistudio.com/wiki/addEventHandler`
- `https://community.bistudio.com/wiki/Arma_2:_Event_Handlers#HandleDamage`
- `https://community.bistudio.com/wiki/getDammage`

## Evidence

`docs/design/MISSION-AUDIT-60.md` already carries the closing verdict:

- Line 11 says the follow-up verification closed items 7, 8, and 9 as not-real, including valid `isNil { ... }` syntax and absolute damage math from the `handleDamage` EH.
- Line 22 says the `isNil {code}` respawn-camp syntax claim is a false positive and the separate trailing `Private [...],;` parse issue is already fixed.
- Line 43 repeats that the code-block form is valid in A2 OA and used broadly in the live codebase.
- Line 45 rejects the `handleDamage` return-contract claim because `Init_Town.sqf:109` returns an absolute damage value after mitigation math.

Current source anchors:

| Path | Anchor | Current state |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GetRespawnCamps.sqf` | line 1 | The `Private [...]` declaration ends cleanly with `];` and carries the cmdcon41-w3 comment that the old trailing comma was removed. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GetRespawnCamps.sqf` | lines 40 and 67 | The camp side checks use `isNil {_x getVariable 'sideID'}`, matching the rejected AUDIT-60 verdict. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf` | line 109 | The camp model `handleDamage` EH returns `getDammage (_this select 0)+((_this select 2)/(missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF"))`, i.e. the new absolute damage value. |
| Takistan and Zargabad generated roots | same files | The same `Private`, `isNil`, and `handleDamage` anchors are present. |

## Scope Boundary

This audit does not touch mission source, respawn/JIP flow, damage-handler code, HC architecture, live deployment, package generation, or LoadoutManager output. It only closes the stale lane-38 prompt row with current-target evidence.

## Verification Commands

```powershell
rg -n "Fresh false-positive|isNil \{code\}|handleDamage return|REJECTED|Common_GetRespawnCamps|Init_Town" docs/design/MISSION-AUDIT-60.md

rg -n "Private \['_availableSpawn'|isNil \{_x getVariable 'sideID'\}" `
  "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GetRespawnCamps.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_GetRespawnCamps.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_GetRespawnCamps.sqf"

rg -n "handleDamage|WFBE_C_CAMP_HEALTH_COEF|getDammage" `
  "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Town.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_Town.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_Town.sqf"
```
