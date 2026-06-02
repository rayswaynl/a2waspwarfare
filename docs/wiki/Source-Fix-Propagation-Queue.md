# Source Fix Propagation Queue

This page tracks mission-code fixes that have reached the Chernarus source mission and the maintained generated Vanilla Takistan target, but still need Arma 2 OA smoke before they can be called release-complete. Agents can load the compact mirror in [`agent-release-readiness.json`](agent-release-readiness.json).

All source paths are relative to the repo root.

## Rule

`Missions/[55-2hc]warfarev2_073v48co.chernarus` is the source mission. `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` is the maintained generated/copy target. A fix is not release-complete until:

1. The Chernarus source patch is present.
2. LoadoutManager propagation has run.
3. Generated diffs are inspected.
4. Relevant Arma 2 OA smoke is recorded.

LoadoutManager root discovery now supports both the old ancestor-folder rule and normal repo checkouts: `Tools/LoadoutManager/FileManagement/FileManager.cs` accepts either an ancestor folder named `a2waspwarfare` or a root containing `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. Packaging can be skipped for propagation-only runs with `A2WASP_SKIP_ZIP=1`; see [Tools/build workflow](Tools-And-Build-Workflow).

## Latest Propagation Run

Checked on 2026-06-02 after the LoadoutManager root-discovery and skip-zip patch. Codex ran:

```powershell
$env:A2WASP_SKIP_ZIP = "1"
dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj
```

Result: generation/copy completed for Chernarus and Takistan, `_MISSIONS.7z` packaging was intentionally skipped, and the maintained Vanilla Takistan diffs now contain all five source fixes. The run printed `The specified content was not found in the file.` once per terrain from `BaseTerrain.ReplaceGUIMenuHelp`; this is a non-fatal help-menu text replacement warning because `Client/GUI/GUI_Menu_Help.sqf` is skip-listed and terrain-specific.

| Fix | Rechecked evidence | Result |
| --- | --- | --- |
| Paratrooper marker revival | Source and Vanilla `Common/Init/Init_PublicVariables.sqf:39` include `HandleParatrooperMarkerCreation`. | Source patched, Vanilla propagated, smoke pending. |
| Client skill init idempotency | Source and Vanilla `Client/Init/Init_Client.sqf` now run one `Skill_Init.sqf` compile and then `WFBE_SK_FNC_Apply`; the duplicate post-apply compile is removed. | Source patched, Vanilla propagated, smoke pending. |
| Hosted server FPS loop sleep | Source and Vanilla `serverFpsGUI.sqf:1` and `monitorServerFPS.sqf:1` exit on `!isDedicated`. | Source patched, Vanilla propagated, smoke pending. |
| Supply mission scan narrowing | Source and Vanilla `supplyMissionStarted.sqf:28` scan only `["Base_WarfareBUAVterminal"]` for the 80m command-center check. | Source patched, Vanilla propagated, smoke pending. |
| Supply player-object list indexing | Source and Vanilla `playerObjectsList.sqf:17` initialize `_i = 0` before the `WFBE_SE_PLAYERLIST` loop. | Source patched, Vanilla propagated, smoke pending. |

## Current Propagated Fix Queue

| Lane | Source status | Vanilla status | Smoke status | Evidence | Next action |
| --- | --- | --- | --- | --- | --- |
| [Paratrooper marker revival](Paratrooper-Marker-Revival) | Patched: Chernarus registers `HandleParatrooperMarkerCreation` in the client PV list. | Propagated: Vanilla `Init_PublicVariables.sqf` now registers the handler too. | Pending Arma smoke. | Source/Vanilla `Common/Init/Init_PublicVariables.sqf:39`; sender `Server/Support/Support_Paratroopers.sqf:117`. | Smoke a paratrooper support drop and confirm the client marker appears. |
| [Client skill init idempotency](Client-Skill-Init-Idempotency) | Patched: Chernarus runs `Skill_Init.sqf` once, then calls `WFBE_SK_FNC_Apply`. | Propagated: Vanilla duplicate compile removed. | Pending Arma smoke. | Source/Vanilla `Client/Init/Init_Client.sqf:547,571`; skill cap mutation `Client/Module/Skill/Skill_Init.sqf:49`. | Smoke Soldier/non-Soldier AI cap and respawn skill reapply. |
| [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) | Patched: Chernarus FPS publishers exit immediately on `!isDedicated`. | Propagated: Vanilla FPS publishers have the same early exit. | Pending dedicated/hosted smoke. | Source/Vanilla `Server/GUI/serverFpsGUI.sqf:1`; source/Vanilla `Server/Module/serverFPS/monitorServerFPS.sqf:1`. | Smoke dedicated FPS publish and hosted/listen no-spin behavior. |
| [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) | Patched: Chernarus 80m command-center scan uses `nearestObjects [..., ["Base_WarfareBUAVterminal"], 80]`. | Propagated: Vanilla uses the same narrowed 80m scan. | Pending truck/heli smoke. | Source/Vanilla `Server/Module/supplyMission/supplyMissionStarted.sqf:25-28`; broad nearby-player 8m scan remains intentional. | Smoke delivery near command centers and no completion near unrelated objects. |
| [Supply player-object list indexing](Player-Join-Disconnect-And-AntiStack-Lifecycle) | Patched: Chernarus initializes `_i = 0` before the `WFBE_SE_PLAYERLIST` loop so reconnecting UIDs replace their real row. | Propagated: Vanilla has the same counter placement. | Pending reconnect/supply smoke. | Source/Vanilla `Server/Module/supplyMission/playerObjectsList.sqf:17-29`; consumers `supplyMissionStarted.sqf:57+` and `supplyMissionActive.sqf:51+`. | Smoke reconnect/JIP player-object replacement and supply mission completion lookup. |

## Patch-Ready But Not Source-Patched

These have source-backed playbooks but are not current code fixes yet. Do not mix them into a propagation run unless the code owner explicitly claims the patch.

| Lane | Status | Canonical page | Why separate |
| --- | --- | --- | --- |
| Factory queue counter/token cleanup | Patch-ready, current source still unpatched. | [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup) | A code patch is still needed in `Client_BuildUnit.sqf` before propagation. |
| Commander reassignment call shape | Patch-ready, current source still unpatched. | [Commander reassignment call shape](Commander-Reassignment-Call-Shape) | Needs a source patch plus one notification-owner decision. |
| Gear template profile filter | Patch-ready, current source still unpatched. | [Gear template profile filter](Gear-Template-Profile-Filter) | Needs `_u_upgrade` replacement in `Client_UI_Gear_SaveTemplateProfile.sqf`. |
| Vehicle cargo equip loop bounds | Patch-ready, current source still unpatched. | [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) | Needs five loop-bound edits before propagation. |
| Service menu affordability guards | Patch-ready, current source still unpatched. | [Service menu affordability guards](Service-Menu-Affordability-Guards) | Needs action-time price/funds/context guards before propagation. |
| WASP marker wait cleanup | Opportunity, source implementation still needed. | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) | Small performance cleanup, but still requires map-marker smoke. |

## Propagation Procedure

1. Start from a clean or intentionally understood worktree.
2. For propagation-only runs, set `A2WASP_SKIP_ZIP=1`.
3. Run `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj` from the repo root, or `dotnet run` from `Tools/LoadoutManager`.
4. Inspect `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` diffs for the intended source fixes.
5. Treat `The specified content was not found in the file.` from `ReplaceGUIMenuHelp` as a non-fatal warning unless a future diff shows help-menu title replacement was expected for that terrain.
6. Do not claim `Modded_Missions/*` propagation; current tooling does not actively maintain those folders.
7. Run or record the relevant smoke from [Testing workflow](Testing-Debugging-And-Release-Workflow), especially the [propagated fix smoke pack](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack).
8. Update this page, [Progress dashboard](Progress-Dashboard), [`agent-release-readiness.json`](agent-release-readiness.json), [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and [`agent-knowledge.jsonl`](agent-knowledge.jsonl).

## Validation Matrix

| Fix | Minimum smoke |
| --- | --- |
| Paratrooper marker revival | Trigger paratrooper support; marker is created on the requesting client and no unregistered-client-PVF error appears. See the dedicated smoke row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Client skill init idempotency | Soldier class receives one AI-cap boost, non-Soldier keeps configured cap, and respawn still reapplies skill effects. See the hosted/respawn row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Hosted server FPS loop sleep | Dedicated server still publishes `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS`; hosted/listen run does not spin the FPS publisher loops. See the dedicated/hosted row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Supply mission scan narrowing | Supply truck/heli completes at a real command center; unrelated nearby objects do not complete the mission; JIP cooldown behavior remains unchanged. See the supply scan row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Supply player-object list indexing | A reconnecting/JIP player with an existing UID updates the matching `WFBE_SE_PLAYERLIST` row, not row 0, and supply completion still finds the correct nearby player object. See the reconnect row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |

## Agent Index Facts

```json
[
  {"fact":"loadoutmanager_root_discovery","source":"Tools/LoadoutManager/FileManagement/FileManager.cs","summary":"LoadoutManager now accepts either an ancestor named a2waspwarfare or a normal repo root containing Missions, Missions_Vanilla and Tools/LoadoutManager/LoadoutManager.csproj."},
  {"fact":"loadoutmanager_skip_zip","source":"Tools/LoadoutManager/ZipManager.cs","summary":"Set A2WASP_SKIP_ZIP to 1, true or yes to run generation/copy without packaging _MISSIONS.7z."},
  {"fact":"current_propagated_fixes","source":"Init_PublicVariables.sqf:39; Init_Client.sqf:547,571; serverFpsGUI.sqf:1; monitorServerFPS.sqf:1; supplyMissionStarted.sqf:25-28; playerObjectsList.sqf:17-29","summary":"Paratrooper marker registration, duplicate Skill_Init removal, hosted FPS loop exits, supply command-center scan narrowing and supply player-object list indexing are present in Chernarus source and maintained Vanilla Takistan after the 2026-06-02 LoadoutManager run."},
  {"fact":"latest_propagation_run","source":"Source-Fix-Propagation-Queue.md#latest-propagation-run","summary":"2026-06-02 LoadoutManager run completed generation/copy for Chernarus and Takistan with A2WASP_SKIP_ZIP=1; all five tracked fixes propagated, Arma smoke remains pending."}
]
```

## Continue Reading

Previous: [Testing workflow](Testing-Debugging-And-Release-Workflow) | Next: [Tools/build workflow](Tools-And-Build-Workflow)

Main map: [Home](Home) | Progress: [Progress dashboard](Progress-Dashboard) | Machine release ledger: [`agent-release-readiness.json`](agent-release-readiness.json) | Machine backlog: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)
