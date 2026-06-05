# Source Fix Propagation Queue

This page tracks mission-code fixes that have reached the Chernarus source mission and the maintained generated Vanilla Takistan target, but still need Arma 2 OA smoke before they can be called release-complete. Agents can load the compact mirror in [`agent-release-readiness.json`](agent-release-readiness.json).

All source paths are relative to the repo root.

## Rule

`Missions/[55-2hc]warfarev2_073v48co.chernarus` is the source mission. `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` is the maintained generated/copy target. A fix is not release-complete until:

1. The Chernarus source patch is present.
2. LoadoutManager propagation has run.
3. Generated diffs are inspected.
4. Every claimed mission root has its generated `version.sqf` present and terrain-correct.
5. Relevant Arma 2 OA smoke is recorded.

LoadoutManager root discovery now supports both the old ancestor-folder rule and normal repo checkouts: `Tools/LoadoutManager/FileManagement/FileManager.cs` accepts either an ancestor folder named `a2waspwarfare` or a root containing `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. Packaging can be skipped for propagation-only runs with `A2WASP_SKIP_ZIP=1`; see [Tools/build workflow](Tools-And-Build-Workflow).

Generated input gate: `version.sqf` is required boot input, not tracked source. It is ignored by `.gitignore`, included by `description.ext:39` and `initJIPCompatible.sqf:4`, and consumed by `Rsc/Header.hpp:5,9,21`. Before calling any propagated fix release-ready, verify source Chernarus and maintained Vanilla Takistan both have generated `version.sqf` files with the expected `WF_MAXPLAYERS`, `WF_MISSIONNAME`, `WF_RESPAWNDELAY`, map flags and release/debug defines. The compact agent-readable rule lives in [`agent-release-readiness.json`](agent-release-readiness.json) under `versionSqfGeneratedInput`.

## Latest Propagation Run

Checked on 2026-06-02 after the LoadoutManager root-discovery and skip-zip patch. Codex ran:

```powershell
$env:A2WASP_SKIP_ZIP = "1"
dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj
```

Result: generation/copy completed for Chernarus and Takistan, `_MISSIONS.7z` packaging was intentionally skipped, and the maintained Vanilla Takistan diffs now contain all five source fixes. The run printed `The specified content was not found in the file.` once per terrain from `BaseTerrain.ReplaceGUIMenuHelp`; this is a non-fatal help-menu text replacement warning because `Client/GUI/GUI_Menu_Help.sqf` is skip-listed and terrain-specific.

| Fix | Rechecked evidence | Result |
| --- | --- | --- |
| Paratrooper marker revival | Source and Vanilla `Common/Init/Init_PublicVariables.sqf:39` include `HandleParatrooperMarkerCreation`. | Chernarus carries it, Vanilla carries it, smoke pending. |
| Client skill init idempotency | Source and Vanilla `Client/Init/Init_Client.sqf` now run one `Skill_Init.sqf` compile and then `WFBE_SK_FNC_Apply`; the duplicate post-apply compile is removed. | Chernarus carries it, Vanilla carries it, smoke pending. |
| Hosted server FPS loop sleep | Source and Vanilla `serverFpsGUI.sqf:1` and `monitorServerFPS.sqf:1` exit on `!isDedicated`. | Chernarus carries it, Vanilla carries it, smoke pending. |
| Supply mission scan narrowing | Source and Vanilla `supplyMissionStarted.sqf:28` scan only `["Base_WarfareBUAVterminal"]` for the 80m command-center check. | Chernarus carries it, Vanilla carries it, smoke pending. |
| Supply player-object list indexing | Source and Vanilla `playerObjectsList.sqf:17` initialize `_i = 0` before the `WFBE_SE_PLAYERLIST` loop. | Chernarus carries it, Vanilla carries it, smoke pending. |

Follow-up source check on 2026-06-05 added one later source-only fix to the queue: commander-built artillery ownership. It was not part of the 2026-06-02 LoadoutManager run above, but current docs/source Chernarus and maintained Vanilla both carry the same `Construction_StationaryDefense.sqf:91-93` commander-team handoff. Stable `origin/master` and release head `3282ff3f` still lack that handoff.

## Release Branch Caveat (2026-06-05 Refresh)

The propagation table above describes the docs/source branch state, not a stable-master or release-branch guarantee. The original source-status recheck used docs/source `HEAD` `4163faba`, `origin/master` `2cdf5fb8`, and `origin/release/2026-06-feature-bundle` `a9219d88`. A 2026-06-05 spot-check against current release head `3282ff3f` found the same lane outcomes for the rows below.

| Lane | Stable `origin/master` | Release `3282ff3f` | Practical rule |
| --- | --- | --- | --- |
| Paratrooper marker revival | Handler registration absent in Chernarus/Vanilla `Common/Init/Init_PublicVariables.sqf`. | Handler registration absent in release Chernarus (`NukeIncoming` at `:41`) and release Vanilla (`NukeIncoming` at `:39`). | Do not assume this lane is in release builds until the release branch carries it in both maintained missions. |
| Client skill init idempotency | Duplicate `Skill_Init.sqf` remains in Chernarus/Vanilla at `Client/Init/Init_Client.sqf:561` and `:585`. | Duplicate `Skill_Init.sqf` remains in release Chernarus at `:565`/`:589` and release Vanilla at `:561`/`:585`. | Treat release/master as still needing the single-init change. |
| Hosted server FPS loop sleep | Chernarus/Vanilla still use branch-only sleeps inside the loop. | Release Chernarus has the guarded publisher and removed/commented monitor path; release Vanilla still has the old loop shape. | Release branch is Chernarus-only for this lane. |
| Supply mission scan narrowing | Chernarus/Vanilla still use the broad 80m command-center scan. | Release Chernarus has the heli-aware narrowed command-center scan; release Vanilla still uses the broad 80m scan. | Release branch is Chernarus-only for this lane. |
| Commander-built artillery ownership | Chernarus/Vanilla keep manned base-area artillery gunners on the base-area `DefenseTeam`; no commander-team handoff is present. | Release Chernarus/Vanilla also keep manned base-area artillery gunners on `DefenseTeam`; no commander-team handoff is present. | Treat release/master as still needing the commander-built ARTY ownership patch. |

## Current Propagated Fix Queue

| Lane | Source status | Vanilla status | Smoke status | Evidence | Next action |
| --- | --- | --- | --- | --- | --- |
| [Paratrooper marker revival](Paratrooper-Marker-Revival) | Chernarus registers `HandleParatrooperMarkerCreation` in the client PV list. | Vanilla `Init_PublicVariables.sqf` now registers the handler too. | Pending Arma smoke. | Source/Vanilla `Common/Init/Init_PublicVariables.sqf:39`; sender `Server/Support/Support_Paratroopers.sqf:117`. | Smoke a paratrooper support drop and confirm the client marker appears. |
| [Client skill init idempotency](Client-Skill-Init-Idempotency) | Chernarus runs `Skill_Init.sqf` once, then calls `WFBE_SK_FNC_Apply`. | Vanilla duplicate compile removed. | Pending Arma smoke. | Source/Vanilla `Client/Init/Init_Client.sqf:547,571`; skill cap mutation `Client/Module/Skill/Skill_Init.sqf:49`. | Smoke Soldier/non-Soldier AI cap and respawn skill reapply. |
| [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) | Chernarus FPS publishers exit immediately on `!isDedicated`. | Vanilla FPS publishers have the same early exit. | Pending dedicated/hosted smoke. | Source/Vanilla `Server/GUI/serverFpsGUI.sqf:1`; source/Vanilla `Server/Module/serverFPS/monitorServerFPS.sqf:1`. | Smoke dedicated FPS publish and hosted/listen no-spin behavior. |
| [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) | Chernarus 80m command-center scan uses `nearestObjects [..., ["Base_WarfareBUAVterminal"], 80]`. | Vanilla uses the same narrowed 80m scan. | Pending truck/heli smoke. | Source/Vanilla `Server/Module/supplyMission/supplyMissionStarted.sqf:25-28`; broad nearby-player 8m scan remains intentional. | Smoke delivery near command centers and no completion near unrelated objects. |
| [Supply player-object list indexing](Player-Join-Disconnect-And-AntiStack-Lifecycle) | Chernarus initializes `_i = 0` before the `WFBE_SE_PLAYERLIST` loop so reconnecting UIDs replace their real row. | Vanilla has the same counter placement. | Pending reconnect/supply smoke. | Source/Vanilla `Server/Module/supplyMission/playerObjectsList.sqf:17-29`; consumers `supplyMissionStarted.sqf:57+` and `supplyMissionActive.sqf:51+`. | Smoke reconnect/JIP player-object replacement and supply mission completion lookup. |
| [Commander-built artillery ownership](Construction-And-CoIn-Systems-Atlas) | Chernarus routes manned artillery-class base-area defense gunners to the current commander team when one exists. | Vanilla has the same commander-team handoff. | Pending commander ARTY smoke. | Source/Vanilla `Server/Construction/Construction_StationaryDefense.sqf:91-93`; tactical discovery `Common/Functions/Common_GetTeamArtillery.sqf:10-30`; tactical UI `Client/GUI/GUI_Menu_Tactical.sqf:544,565,594`. | Smoke commander-built manned ARTY inside the HQ/base circle, Tactical fire-mission listing, ammo loading, direct fire, non-artillery `DefenseTeam` behavior and HC static-defense fallback. |

## Patch-Ready But Not In Current Code

These have source-backed playbooks but are not current code fixes yet. Do not mix them into a propagation run unless the code owner explicitly claims the patch.

| Lane | Status | Canonical page | Why separate |
| --- | --- | --- | --- |
| Factory queue counter/token cleanup | Patch-ready, current code still carries both the queue-counter leak and low-entropy token; branch matrix refreshed 2026-06-05. | [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup) | `perf/quick-wins` and release Chernarus patch only the crewless queue-counter leak; the FIFO token and maintained Vanilla propagation remain open. |
| Side-supply clamp and temp-channel validation | Patch-ready, current source/Vanilla, stable, Miksuu upstream and release all still carry the overspend-as-credit floor plus payload-side trust; `perf/quick-wins` fixes only the Chernarus arithmetic floor. | [Economy authority first cut](Economy-Authority-First-Cut#side-supply-branch-matrix) | Port or recreate the arithmetic floor-to-zero fix in current source, add west/east side/channel/amount validation, propagate maintained Vanilla, and keep broader DR-44 spend authority/server-ledger work separate. |
| Commander reassignment call shape | Patch-ready, current docs/source still carries the helper defect; branch matrix refreshed 2026-06-05. | [Commander reassignment call shape](Commander-Reassignment-Call-Shape) | Stable/upstream/release already fix helper unpacking, but current source/Vanilla need the patch or port; duplicate notification owner and UI row-identity cleanup remain open everywhere checked. |
| Construction small-site logic cleanup | Patch-ready; current source/Vanilla, stable/upstream and release all still carry SmallSite add/add while MediumSite removes. | [Construction logic list cleanup](Construction-Logic-List-Cleanup) | Needs the one-line SmallSite add-to-remove edit, then Vanilla propagation and construction smoke. |
| Auto-wall toggle scope cleanup | Docs-ready workflow/authority cleanup; current source/Vanilla, stable, Miksuu upstream, perf/quick-wins and release all keep `User14` toggling one global `isAutoWallConstructingEnabled` value that later SmallSite/MediumSite workers consume. | [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) | Decide global-vs-side/requester policy, then either label the match-wide behavior or key/validate the state and smoke two players/sides toggling before small and medium construction. |
| Salvage payout/cleanup cleanup | Patch-ready first cut plus authority follow-up; current source/Vanilla, stable, Miksuu upstream, perf/quick-wins, release and the Miksuu salvage branches all keep lowercase salvage payout calls, local wreck deletion and the `updatesalvage.sqf` `||` loop. | [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) | Fix `ChangePlayerFunds` casing in both salvage paths across source Chernarus and maintained Vanilla first, smoke manual engineer and salvage-truck payouts, then separately review loop exit and server-owned delete/reward authority. |
| Resistance patrol active latch | Patch-ready; current source/Vanilla, stable `origin/master` and Miksuu upstream still carry the `server_patrols.sqf` `||` loop that blocks active-latch cleanup. `perf/quick-wins` and release Chernarus use `&&`, but maintained Vanilla still carries the old loop. | [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#resistance-patrol-branch-matrix), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) | Port or recreate the Chernarus loop-exit fix in current source, propagate maintained Vanilla, and smoke patrol launch/death/relaunch plus game-over cleanup. |
| RHUD/endgame title display handle split | Patch-ready; current source/Vanilla, stable/upstream and release all still share `currentCutDisplay` between `OptionsAvailable`/RHUD/action icons and `EndOfGameStats`. | [UI IDD collision repair](UI-IDD-Collision-Repair) | Needs a title display-variable split or RHUD/action-icon endgame gate before propagation; keep separate from broader UI IDD cleanup and smoke RHUD/action icons/endgame stat bars together. |
| Clickable text soundPush config | Patch-ready; current source/Vanilla, stable/upstream, `perf/quick-wins`, release and UI theme branches all still carry malformed `RscClickableText.soundPush[] = {, 0.2, 1};` in the base resource class. | [Client UI systems atlas](Client-UI-Systems-Atlas#clickable-text-soundpush-branch-matrix) | Needs one base-class config edit in source Chernarus, maintained Vanilla propagation, then Arma 2 OA dialog smoke across representative `RscClickableText` inheritors before release wording. |
| Empty supply-truck cleanup timeout | Docs-ready logistics/cleanup owner decision; current source/Vanilla, stable/upstream, `perf/quick-wins` and release all hard-code `_delay = 86400` for supply-truck classes in `Server_HandleEmptyVehicle.sqf` while the collector only hands empty vehicles to the handler. | [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas#empty-supply-truck-branch-matrix) | Decide keep-and-label versus shorter/parameterized timeout, then patch source Chernarus plus maintained Vanilla if changing behavior. Smoke ordinary empty vehicles, ambulance/repair double-timeout vehicles, supply trucks used for supply/logistics and long-match object counts. |
| Gear template profile filter | Patch-ready; current source/Vanilla, stable/upstream and release all still carry undefined `_u_upgrade` save filtering plus the six-field profile import guard. | [Gear template profile filter](Gear-Template-Profile-Filter) | Needs save-filter replacement in `Client_UI_Gear_SaveTemplateProfile.sqf` plus an `Init_ProfileGear.sqf` import guard/default before propagation. |
| Vehicle cargo equip loop bounds | Patch-ready; current source/Vanilla, stable/upstream and release all still carry the same five inclusive cargo loops. | [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) | Needs five loop-bound edits in `Common_EquipVehicle.sqf` and `Common_EquipBackpack.sqf`, then Vanilla propagation and cargo smoke. |
| Buy-menu price/key alignment | Patch-ready; current source/Vanilla, stable and upstream still carry selected-detail price drift, stale `UNIT_COST_MODIFIER` reset behavior and the driver-default profile key split. Release/QoL branch fix only Chernarus selected-detail display. | [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas#buy-menu-price-and-driver-key-branch-matrix) | Needs one shared price/reset path plus one normalized driver-default key, then Vanilla propagation and Buy Units UI/economy smoke. |
| Visible parameter runtime-consumer cleanup | Docs-ready parameter cleanup; current source/Vanilla, stable, Miksuu upstream and release all keep `WFBE_C_AI_MAX` visible/defaulted without an active maintained-root runtime reader, and keep `WFBE_C_UNITS_CLEAN_TIMEOUT` visible/defaulted while live cleanup uses bodies/empty timeout variables. | [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs) | Decide whether to wire, hide, rename or label each parameter historical; apply consistently to source Chernarus plus maintained Vanilla, then smoke host parameter display, player AI cap UI/RHUD, corpse cleanup and empty-vehicle cleanup. |
| Salvage payout casing and loop/authority cleanup | Patch-ready; current source/Vanilla, stable `origin/master`, Miksuu upstream, `origin/perf/quick-wins`, release and historical Miksuu salvage branches all still carry lowercase `ChangePlayerfunds`, the salvage-truck `||` loop and client-local deletion/reward shape. | [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix) | Fix the casing in source Chernarus first, propagate maintained Vanilla, smoke manual engineer salvage and salvage-truck payout, then review loop exit and server-owned deletion/reward as a separate authority lane. |
| Service menu affordability guards | Patch-ready, current code still carries the defect; branch matrix refreshed 2026-06-05. | [Service menu affordability guards](Service-Menu-Affordability-Guards) | Current docs/source and maintained Vanilla need action-time price/funds/context guards; stable/upstream improve button-enable order but still debit client-side; release Chernarus is only a partial rearm/refuel QoL guard and release Vanilla/EASA exact-funds remain open. |
| Vote/help/main-menu UI cleanup | Patch-ready; current source/Vanilla, stable, Miksuu upstream, `perf/quick-wins` and release all keep inclusive vote refresh loops, vote row-color offset, mismatched help load/unload namespace state and GPS zoom router cases without audited button emitters. | [Client UI systems atlas](Client-UI-Systems-Atlas#vote-help-and-main-menu-branch-matrix) | Fix vote loops and row coloring, clean the help `onLoad`/`onUnload` namespace contract, decide remove-vs-revive for GPS `17/18`, propagate maintained Vanilla and smoke vote refresh, help open/close and main-menu HUD/GPS behavior. |
| Camp flag texture drift | Patch-ready in current source; release Chernarus has a partial one-line capture fix, but current source/Vanilla, stable/upstream, release Vanilla and repair-side flag refresh remain open. | [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) | Current source/Vanilla `server_town_camp.sqf:135` still uses the old side for independent capture flags; release Chernarus commit `0a1e6165` uses the new side, but release Vanilla does not. `Server_HandleSpecial.sqf:243,246` changes repaired camp side and broadcasts `CampCaptured` without refreshing the world flag in all checked roots. |
| Camp count helper fallback semantics | Patch-ready caller-semantics cleanup; current source/Vanilla, stable, Miksuu upstream, perf/quick-wins and release all keep zero-camp helpers returning `1` and feeding capture mode 2, threeway respawn and depot-buy gates. | [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) | Decide real-count versus safe-denominator semantics, then split helpers or add caller-specific zero-camp guards. Smoke capture mode 2, threeway defender respawn and depot infantry buys on zero, partial and all-camp towns. |
| WASP marker wait cleanup | Opportunity/source implementation still needed; current source/Vanilla, stable, Miksuu upstream, perf/quick-wins and release all keep the display-54 input-lock busy wait while the display-12 sibling is already throttled. | [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) | Replace the display-54 wait with a throttled `waitUntil`/sleep shape, preserve key handler wiring and final input unlock, propagate maintained Vanilla, then smoke map-marker double-click naming, Enter prefixing, Escape cleanup and timeout/no-dialog input re-enable. |

## Propagation Procedure

1. Start from a clean or intentionally understood worktree.
2. For propagation-only runs, set `A2WASP_SKIP_ZIP=1`.
3. Run `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj` from the repo root, or `dotnet run` from `Tools/LoadoutManager`.
4. Inspect `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` diffs for the intended source fixes.
5. Treat `The specified content was not found in the file.` from `ReplaceGUIMenuHelp` as a non-fatal warning unless a future diff shows help-menu title replacement was expected for that terrain.
6. Verify generated `version.sqf` exists and matches the intended target root before pack/test/release claims; use `agent-release-readiness.json` `versionSqfGeneratedInput` as the machine checklist.
7. Do not claim `Modded_Missions/*` propagation; current tooling does not actively maintain those folders. A 2026-06-03 scout confirmed all tracked modded folders lack generated `version.sqf`, several lack core bootstrap files, and 18 Napf/Eden/Lingor files contain unresolved conflict markers.
8. Run or record the relevant smoke from [Testing workflow](Testing-Debugging-And-Release-Workflow), especially the [propagated fix smoke pack](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack).
9. Update this page, [Progress dashboard](Progress-Dashboard), [`agent-release-readiness.json`](agent-release-readiness.json), [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and [`agent-knowledge.jsonl`](agent-knowledge.jsonl).

## Validation Matrix

| Fix | Minimum smoke |
| --- | --- |
| Paratrooper marker revival | Trigger paratrooper support; marker is created on the requesting client and no unregistered-client-PVF error appears. See the dedicated smoke row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Client skill init idempotency | Soldier class receives one AI-cap boost, non-Soldier keeps configured cap, and respawn still reapplies skill effects. See the hosted/respawn row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Hosted server FPS loop sleep | Dedicated server still publishes `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS`; hosted/listen run does not spin the FPS publisher loops. See the dedicated/hosted row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Supply mission scan narrowing | Supply truck/heli completes at a real command center; unrelated nearby objects do not complete the mission; JIP cooldown behavior remains unchanged. See the supply scan row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Supply player-object list indexing | A reconnecting/JIP player with an existing UID updates the matching `WFBE_SE_PLAYERLIST` row, not row 0, and supply completion still finds the correct nearby player object. See the reconnect row in [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Commander-built artillery ownership | Commander-built manned artillery inside the HQ/base circle appears in the commander's Tactical fire-mission path, ammo loading still targets the gun, direct fire still works, non-artillery statics remain on the base-area `DefenseTeam`, and HC static-defense delegation does not break commander-team discoverability. See the commander artillery row in [Testing workflow](Testing-Debugging-And-Release-Workflow#source-propagated-fix-smoke-pack). |

## Agent Index Facts

```json
[
  {"fact":"loadoutmanager_root_discovery","source":"Tools/LoadoutManager/FileManagement/FileManager.cs","summary":"LoadoutManager now accepts either an ancestor named a2waspwarfare or a normal repo root containing Missions, Missions_Vanilla and Tools/LoadoutManager/LoadoutManager.csproj."},
  {"fact":"loadoutmanager_skip_zip","source":"Tools/LoadoutManager/ZipManager.cs","summary":"Set A2WASP_SKIP_ZIP to 1, true or yes to run generation/copy without packaging _MISSIONS.7z."},
  {"fact":"version_sqf_generated_input_gate","source":"agent-release-readiness.json#versionSqfGeneratedInput","summary":"version.sqf is ignored/generated but required by description.ext, initJIPCompatible.sqf and Rsc/Header.hpp; verify per-target generated files before pack, smoke or release claims."},
  {"fact":"current_propagated_fixes","source":"Init_PublicVariables.sqf:39; Init_Client.sqf:547,571; serverFpsGUI.sqf:1; monitorServerFPS.sqf:1; supplyMissionStarted.sqf:25-28; playerObjectsList.sqf:17-29; Construction_StationaryDefense.sqf:91-93","summary":"Paratrooper marker registration, duplicate Skill_Init removal, hosted FPS loop exits, supply command-center scan narrowing, supply player-object list indexing and commander-built artillery ownership are present in Chernarus source and maintained Vanilla Takistan; Arma smoke remains pending."},
  {"fact":"latest_propagation_run","source":"Source-Fix-Propagation-Queue.md#latest-propagation-run","summary":"2026-06-02 LoadoutManager run completed generation/copy for Chernarus and Takistan with A2WASP_SKIP_ZIP=1; all five tracked fixes propagated, Arma smoke remains pending."}
]
```

## Continue Reading

Previous: [Testing workflow](Testing-Debugging-And-Release-Workflow) | Next: [Tools/build workflow](Tools-And-Build-Workflow)

Main map: [Home](Home) | Progress: [Progress dashboard](Progress-Dashboard) | Machine release ledger: [`agent-release-readiness.json`](agent-release-readiness.json) | Machine backlog: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)
