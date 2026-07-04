# HQ Killed-EH Casing Audit (Lane 33)

Date: 2026-07-03
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Verdict

Lane 33 is already fixed on the current target. No mission source change is needed.

The original AUDIT-60 row was real: the repaired-HQ and mobilized-HQ paths needed to relay the uppercase local `_MHQ` to `HandleSpecial ["set-hq-killed-eh", ...]`. On the current target, both paths already do that, and the generated Takistan/Zargabad copies match the Chernarus source.

## Evidence

`docs/design/MISSION-AUDIT-60.md` already marks the row live-done:

- Line 9 says AUDIT-60 items 1 and 2 now send `_MHQ` in both maintained roots.
- Lines 28-31 mark the repaired-HQ and mobilized-HQ killed-EH casing rows as `CONFIRMED, LIVE DONE`.
- Line 52 summarizes both `_mhq` to `_MHQ` fixes.

Current source anchors:

| Path | Anchor | Current state |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_MHQRepair.sqf` | line 43 | Sends `["set-hq-killed-eh", _MHQ]` after creating `_MHQ` on line 26 and adding the server-local killed EH on line 37. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Construction/Construction_HQSite.sqf` | line 104 | Sends `["set-hq-killed-eh", _MHQ]` after creating `_MHQ` on line 78 and adding the server-local killed EH on line 102. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/...` | same server files | Same `_MHQ` relay anchors are present. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/...` | same server files | Same `_MHQ` relay anchors are present. |

The live source comments also identify the original WAVE-3 AUDIT-60 fix at both relay sites:

```sqf
//--- WAVE-3 (60-audit): _mhq -> _MHQ (case-sensitive local was nil -> repaired HQ's killed round-ender wired to nothing).
```

and

```sqf
//--- WAVE-3 (60-audit): _mhq -> _MHQ (case-sensitive local was nil -> mobilized HQ's killed round-ender wired to nothing).
```

## Scope Boundary

This audit does not touch mission source, client enrollment/JIP flow, HC architecture, live deployment, package generation, or LoadoutManager output. It only closes the stale lane-33 prompt row with current-target evidence.

## Verification Commands

```powershell
rg -n "set-hq-killed-eh|WAVE-3 \(60-audit\)|_mhq -> _MHQ|WFBE_SE_FNC_OnHQKilled|_MHQ" `
  "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_MHQRepair.sqf" `
  "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Construction/Construction_HQSite.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_MHQRepair.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Construction/Construction_HQSite.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_MHQRepair.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Construction/Construction_HQSite.sqf"

rg -n "_mhq" `
  "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_MHQRepair.sqf" `
  "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Construction/Construction_HQSite.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_MHQRepair.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Construction/Construction_HQSite.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_MHQRepair.sqf" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Construction/Construction_HQSite.sqf"
```

The second scan returns only the explanatory `_mhq -> _MHQ` comments, not a live lowercase `_mhq` relay.
