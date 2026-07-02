# GUER FOB RHUD Audit - 2026-07-02

Lane: 155, GUER FOB-token RHUD row
Base checked: `origin/claude/build84-cmdcon36@ca278c4bc7`
Scope: docs/source audit only. No mission source, RHUD layout, generated Takistan files, live deploy, or package artifacts are changed here.

## Summary

The prompt row is stale on the current live target. GUER FOB availability is already visible on the RHUD for resistance players in both maintained roots.

The current implementation:

- reserves GUER-only RHUD rows 15/16 for Tech Kills and 17/18 for FOB availability;
- labels row 17 as `FOB:`;
- reads `WFBE_GUER_FOB_AVAIL` with `[0,0,0]` fallback;
- rejects malformed/non-array values before display;
- renders row 18 as `B n | LF n | HF n`.

No source patch is recommended in this lane. The current target already exposes the FOB token counts without requiring players to open the buy menu.

## Evidence Table

| Path | Evidence | Result |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:243` | Comment reserves GUER-only rows 15/16 and 17/18, with FOB on 17/18. | RHUD space is already allocated. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:369-373` | Resistance-side branch sets row 17 to `FOB:`. | GUER players get a visible label. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Client_UpdateRHUD.sqf:536-542` | Reads `_gFob = missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]]`, validates shape, and renders `B %1 | LF %2 | HF %3` to row 18. | FOB counts are shown directly on the RHUD. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Client_UpdateRHUD.sqf:243,369-373,536-542` | Same label/read/shape-guard/render path. | Takistan mirror is already covered. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_BuildingKilled.sqf:27-31` | Enemy factory kills increment `WFBE_GUER_FOB_AVAIL` and `publicVariable` it. | Normal FOB-token grants feed the RHUD variable. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_HandleSpecial.sqf:1279-1283` | VBIED factory kills increment and broadcast the same variable. | VBIED grants use the same RHUD feed. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestFOBStructure.sqf:27,46-47,65-66` | FOB building spends/refunds `WFBE_GUER_FOB_AVAIL` and broadcasts after mutation. | Counts update after player FOB construction. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_GuerStipend.sqf:73-75` | Periodic GUER stipend loop rebroadcasts the FOB availability counter when present. | Clients get periodic refreshes. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_OnPlayerConnected.sqf:158` | JIP catch-up sends `WFBE_GUER_FOB_AVAIL` with `publicVariableClient`. | Joiners receive the current RHUD value. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/...` | The same grant/spend/rebroadcast/JIP anchors exist in the maintained Takistan root. | Mirror present. |

## Non-Findings

- This audit does not change RHUD control placement, label copy, update cadence, or GUER FOB economy.
- This audit does not add a new parameter or flag; no new behavior is needed because the prompt-named feature already exists.
- This audit does not evaluate broader GUER onboarding or buy-menu discoverability beyond the RHUD FOB-token row.

## Suggested Smoke

Optional in-game smoke for a later owner run:

1. Join as a GUER player.
2. Destroy or VBIED an enemy Barracks, Light Factory, or Heavy Factory.
3. Confirm the RHUD `FOB:` row updates from `B 0 | LF 0 | HF 0` to the matching count.
4. Build a FOB from the corresponding delivery truck and confirm the count decrements.
5. Rejoin and confirm the same count is visible after JIP catch-up.

## Verification

- `rg` confirmed the RHUD label, `WFBE_GUER_FOB_AVAIL` read, shape guard, and `B/LF/HF` render line in both maintained roots.
- `rg` confirmed normal factory kill, VBIED kill, FOB build/refund, periodic rebroadcast, and JIP catch-up paths publish `WFBE_GUER_FOB_AVAIL`.
- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only audit.
