# Agent Worklog

> Append-only, agent-visible worklog. **Recent entries only (2026-06-06 onward).** Older entries (2026-06-01 → 06-06) are preserved verbatim in [Agent worklog archive](Agent-Worklog-Archive). Append new entries at the bottom; do not reorder or edit other agents' entries. Machine feeds: [`agent-events.jsonl`](agent-events.jsonl), [`agent-collaboration.json`](agent-collaboration.json).

---

## 2026-06-06T22:05:00+02:00 - Codex - Legacy compiled aliases with no static callers

- Claimed `legacy-compiled-aliases-no-static-callers` from Aquinas' returned read-only compiled-helper scout.
- Source-checked current Chernarus and maintained Vanilla compile/caller scope for `AITownResitance`, `EquipLoadout`, `GetGroupFromConfig`, `GetSafePlace`, `GetUnitsBelowHeight`, `UseStationaryDefense`, `ReplaceArray`, `FireArtillery`, `GetSideUpgrades` and client `HandlePVF`; after excluding compile lines, comment-only hits and the helper file itself, the old alias symbols had zero active static callers in both maintained roots.
- Result: [Function and module index](Function-And-Module-Index#legacy-compiled-aliases-with-no-static-callers) now owns the alias table and [Dead/stale code register](Dead-Code-And-Stale-Code-Register) routes a single stale-alias row there. The docs explicitly do not mark shared helper files dead where newer `WFBE_*` function names still call them. No gameplay source changed.

## 2026-06-06T21:42:00+02:00 - Codex - Client modal loop cadence index

- Claimed `client-modal-loop-cadence-index` from Huygens' returned read-only client loop cadence scout.
- Source-checked current Chernarus and maintained Vanilla for the highest-cadence modal controllers: `GUI_BuyGearMenu.sqf:503`, `GUI_TransferMenu.sqf:94`, `GUI_RespawnMenu.sqf:113` and `GUI_UpgradeMenu.sqf:282` all use `sleep .01`, and no local `PerformanceAudit_Record` writer was found in those four controllers.
- Result: [Client UI systems](Client-UI-Systems-Atlas#client-modal-loop-cadence) now separates `.01` modal loops, `.05` vote/team loops, `.1` standard menu loops, `.03` visual helper loops and already-instrumented HUD/marker loops. [Performance opportunity sweep](Performance-Opportunity-Sweep) routes the `.01` row as measurement-first P3 work, not a blind cadence patch. No gameplay source changed.

## 2026-06-06T21:24:00+02:00 - Codex - UI resource missing `wf_*.paa` block

- Claimed `ui-resource-wf-icon-missing-block` after the resource-parity scout reported missing stale `RscMenu_Upgrade` icon assets.
- Source-checked current Chernarus and maintained Vanilla `Rsc/Dialogs.hpp:2644,2655,2666,2677,2688,2699,2710,2721,2732,2743,2754,2765,2776,2787,2798,2809,2820,2831`; both roots reference the same missing `Client\Images\wf_*.paa` files, and `rg --files` found none of those filenames anywhere in the repo. `Rsc/Ressources.hpp:300,302,304` button skins resolve and are not part of this finding.
- Result: `UI-Resource-Parity-Cleanup` now owns the exact missing upgrade icon block, and `Client-UI-Systems-Atlas` routes image/resource indicator cleanup there. Updated docs routing only. No gameplay source changed.

## 2026-06-06T21:12:00+02:00 - Codex - Indicator surface matrix index

- Claimed `indicator-surface-matrix-index` to turn the existing "all indicators" backlog inventory into the requested runtime ownership matrix.
- Source-checked representative current Chernarus anchors for title/HUD ownership (`Rsc/Titles.hpp:164-171,532-540,723`; `Client_UpdateRHUD.sqf:89-92,199-201,367-369`), map marker cadence and writes (`updatetownmarkers.sqf:20-21,129-134`; `Common_MarkerUpdate.sqf:49-50,67-88,218-241`), support marker creation (`Support_Paratroopers.sqf:117`; `HandleParatrooperMarkerCreation.sqf:30-45`), menu/resource icons (`Dialogs.hpp:1171,1566,1586,2123,2644,3469`) and FPS status publication (`monitorServerFPS.sqf:1-5`).
- Result: `Client-UI-Systems-Atlas` now has a compact `surface`, `owner script`, `state source`, `audience`, `update cadence`, `cleanup path`, `known risk`, `branch scope` and `smoke target` matrix for RHUD/action titles, capture/endgame/CoIn titles, map/tactical markers, support/special markers, menu/list resources and status/debug counters. Updated docs routing only. No gameplay source changed.

## 2026-06-06T21:00:00+02:00 - Codex - Commander task / Objective Ping branch split

- Claimed `commander-task-objective-ping-branch-split` after current-source docs still treated commander task assignment and the old town `TaskSystem` as one dormant UI bucket.
- Source-checked current source/Vanilla, stable `origin/master` / local `master` `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `TaskSystem`, `SetTask`, command-menu task controls and public-variable registration.
- Result: owner pages now separate the old disabled town `TaskSystem` (`Init_Client.sqf:75,759`; `TownCaptured.sqf:35,87` on master/perf and `:36,88` on release) from release `7ff18c49` re-enabling targeted commander `SetTask` sends as Objective Ping in both maintained roots (`GUI_Menu_Command.sqf:19,336,344`). Updated docs routing only. No gameplay source changed.

## 2026-06-06T20:55:00+02:00 - Codex - PerformanceAudit writer index

- Claimed `performance-audit-writer-index` after finding `PerformanceAudit_*` was only a one-line family in the function index while the analyzer page documented the offline parser.
- Source-checked current source Chernarus and maintained Vanilla for `Common_PerformanceAudit.sqf`, client/server run startup and representative client/server `PerformanceAudit_Record` writers.
- Result: `Function-And-Module-Index` now separates the mission-side local RPT writer family from the offline `Tools/PerformanceAuditAnalyzer` parser, with line refs for enablement, buffering, flush/run behavior and representative client/server instrumentation surfaces. Updated docs routing only. No gameplay source changed.

## 2026-06-06T20:45:00+02:00 - Codex - AI commander upgrade debit current-head refresh

- Claimed `ai-commander-upgrade-debit-current-head-refresh` after finding the AI commander upgrade debit machine rows still cited `origin/master@2cdf5fb8` while the current stable head is `89ae9dad`.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8`, `origin/perf/quick-wins` `0076040f`, release `7ff18c49` and `origin/feat/ai-commander` `c20ce153` for `Server_AI_Com_Upgrade.sqf` and `GUI_UpgradeMenu.sqf`.
- Result: current stable and perf keep the same maintained-root raw AI_ORDER cost lookup plus swapped funds/supply debit; `2cdf5fb8..89ae9dad` does not touch the checked worker/menu files. Release fixes debit order in both maintained roots, while `feat/ai-commander` fixes debit plus cost-level lookup only in Chernarus. Updated docs/status routing only. No gameplay source changed.

## 2026-06-07T00:30:00+02:00 - Codex - Service/EASA affordability current-head refresh

- Claimed `service-easa-affordability-current-head-refresh` after finding the service affordability page and Feature Status still described release Chernarus as the only partial release rearm/refuel guard and kept older stable/upstream wording.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8` and release `7ff18c49` for maintained-root `GUI_Menu_Service.sqf` and `GUI_Menu_EASA.sqf`.
- Result: current stable still enables service buttons from current funds/prices at `GUI_Menu_Service.sqf:311-317`, but rearm/refuel debit directly and repair/heal only check positive price at `:326,337,347,358`; EASA still rejects exact-funds purchases at `GUI_Menu_EASA.sqf:47-49`. Release `7ff18c49` guards rearm/refuel in both maintained roots at `GUI_Menu_Service.sqf:466,489`, but repair/heal and EASA exact-funds/client-debit behavior remain open. Updated docs/status routing only. No gameplay source changed.

## 2026-06-07T00:12:00+02:00 - Codex - Reaktiv current-head refresh

- Claimed `reaktiv-current-head-refresh` after finding the Reaktiv dead-code/module rows still described stable `2cdf5fb8` as current-facing branch evidence.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8`, `origin/perf/quick-wins` `0076040f`, release `7ff18c49` and current modded Napf/Eden/Lingor copies for `Common/Module/Reaktiv` and `Common/Init/Init_Common.sqf`.
- Result: current stable and perf still carry the unreachable Reaktiv module in both maintained roots; current stable initializes ICBM, IRS and CIPHER at `Init_Common.sqf:321-325` with no Reaktiv init call. Release `7ff18c49` removes Reaktiv from maintained roots, while current modded Napf/Eden/Lingor copies still carry stale module files. Updated docs/status routing only. No gameplay source changed.

## 2026-06-06T23:59:55+02:00 - Codex - LoadoutManager root current-head refresh

- Claimed `loadoutmanager-root-current-head-refresh` after finding the hardening backlog row still described current source/stable as `origin/master` `2cdf5fb8`.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Tools/LoadoutManager/FileManagement/FileManager.cs` and `ZipManager.cs`.
- Result: current stable and perf still climb until an ancestor folder is literally named `a2waspwarfare` at `FileManager.cs:145-152`; `2cdf5fb8..89ae9dad` does not touch the checked root/zip files. Release `7ff18c49` uses `IsA2WaspWarfareRoot` and accepts either the ancestor name or repo markers at `FileManager.cs:158-176`. Updated docs/status routing only. No gameplay source changed.

## 2026-06-06T23:59:45+02:00 - Codex - Camp-count current-head machine refresh

- Claimed `camp-count-current-head-machine-refresh` after finding the hardening backlog row still described stable `origin/master` `2cdf5fb8` as current-facing camp-count evidence.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Common_GetTotalCamps.sqf`, `Common_GetTotalCampsOnSide.sqf`, capture-mode, threeway-respawn and depot-buy consumers.
- Result: current stable and release both keep `Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16` returning `1` for zero-camp towns in Chernarus and maintained Vanilla; release only shifts Buy Units callers to `GUI_Menu_BuyUnits.sqf:117-118`. Updated machine/status routing only. No gameplay source changed.

## 2026-06-06T23:59:30+02:00 - Codex - AI supply-truck current-head refresh

- Claimed `ai-supply-truck-current-head-refresh` after finding AI supply-truck safe-disable rows that mixed current-stable wording with historical `2cdf5fb8` raw-spawn line refs.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8`, `origin/perf/quick-wins` `0076040f`, release `7ff18c49` and `origin/feat/ai-commander` `c20ce153` for `Init_Server.sqf`, `AI_UpdateSupplyTruck.sqf` and missing `Server/FSM/supplytruck.fsm`.
- Result: current stable `89ae9dad` still comments out `UpdateSupplyTruck` at `Init_Server.sqf:36`, initializes `wfbe_ai_supplytrucks` at `:386`, raw-spawns `UpdateSupplyTruck` at `:387`, and leaves `AI_UpdateSupplyTruck.sqf:17` pointing at the missing FSM. Release `7ff18c49` warning/disables both maintained roots at `:385-386`; `feat/ai-commander` guards only Chernarus. Updated docs/status routing only. No gameplay source changed.

## 2026-06-06T23:59:00+02:00 - Codex - Resistance patrol current-head refresh

- Claimed `resistance-patrol-current-head-refresh` after finding patrol active-latch rows with older `HEAD@2cdf5fb8` / launch-line refs while current Feature Status had already moved to stable `89ae9dad`.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `server_town_ai.sqf` and `server_patrols.sqf`.
- Result: current stable `89ae9dad` starts patrols from `server_town_ai.sqf:295-298` and still keeps `server_patrols.sqf:26` as `while {!WFBE_GameOver || _team_alive}` with the reset at `:71-72`; perf fixes Chernarus only, while release `7ff18c49` uses `&&` in both maintained roots. Updated docs/status routing only. No gameplay source changed.

## 2026-06-06T23:58:00+02:00 - Codex - Town AI despawn current-head refresh

- Claimed `town-ai-despawn-current-head-refresh` after finding the human Feature Status row still described historical stable `2cdf5fb8` as current-facing town-AI despawn evidence.
- Source-checked current `origin/master` / local `master` / Miksuu `89ae9dad`, historical stable `2cdf5fb8`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for the tracked town-AI vehicle cleanup guard.
- Result: current stable `89ae9dad` moves the inactive vehicle cleanup to `server_town_ai.sqf:265-285`, still deletes at `:278` with only `!(isPlayer leader group _x)`, and adds `Server_CleanupExpiredTownDefenseAssets.sqf:61-64` with the same player-leader-style deletion risk. Historical stable, perf and release keep the older `server_town_ai.sqf:216-221` shape. Updated docs/status routing only. No gameplay source changed.

## 2026-06-06T20:10:00+02:00 - Codex - Release ARTY marker ownership route

- Claimed `release-arty-marker-ownership-route` after the commander/construction scout exposed a source conflict: existing current-facing docs said release `7ff18c49` lacked commander-built ARTY ownership, but release has a different marker-based discovery path.
- Source-checked release `7ff18c49` Chernarus and maintained Vanilla: `Construction_StationaryDefense.sqf:133-135` sets `WFBE_CommanderArtillery`, `WFBE_CommanderArtillerySide` and `WFBE_CommanderArtilleryIndex` on non-repair-truck artillery defenses, while `Common_GetTeamArtillery.sqf:46-78` lets the commander team discover same-side marked artillery inside HQ/base-area radius.
- Rechecked current `origin/master` / local `master` `89ae9dad`: it still has neither the docs/source `Construction_StationaryDefense.sqf:91-93` commander-team gunner handoff nor the release marker scan. Updated branch-status docs only. No gameplay source changed.

## 2026-06-06T19:35:00+02:00 - Codex - Origin master town-defense merge correction

- Claimed `origin-master-town-defense-merge-correction` after fresh `git fetch --all --prune` advanced `origin/master` from `2cdf5fb8` to `89ae9dad`, matching `miksuu/master`.
- Source-checked the new master for the town-defense persistence/diagnostics files in source Chernarus and maintained Vanilla; recheck showed both local source `HEAD` and `origin/master` at `89ae9dad`.
- Result: the town-defense persistence/diagnostics overhaul is now current remote-stable source evidence, not upstream-only evidence. DR-45 remains open because `server_town_ai.sqf` and `Server_CleanupExpiredTownDefenseAssets.sqf` still use player-leader-style deletion guards without full crew/cargo/turret player-occupancy checks. Updated wiki/status routing only. No gameplay source changed.

## 2026-06-06T19:05:00+02:00 - Codex - Miksuu town-defense overhaul refresh

- Claimed `miksuu-town-defense-overhaul-refresh` after refetch showed current `miksuu/master` is `89ae9dad` while the current snapshot/upstream intel still described `69e1958a` as the upstream head.
- Source-checked `69e1958a..89ae9dad` for town-defense persistence/diagnostics helpers in source Chernarus and maintained Vanilla; this row was later superseded when `origin/master` and local `master` also advanced to `89ae9dad`.
- Result: Miksuu `89ae9dad` adds `Common_MarkTownDefenseAsset`, `Server_CleanupExpiredTownDefenseAssets`, `Server_SendTownDebugChat`, `TownDefenseDiagnosticsEnabled` and capture-persistence handling in both maintained roots. The later origin-master correction makes that current stable source evidence, and the same cleanup still lacks a full crew/cargo/turret player-occupancy guard, so DR-45 remains a required companion before release-ready wording. Updated upstream/town docs and machine rows only. No gameplay source changed.

## 2026-06-06T18:50:00+02:00 - Codex - Docs/source supply scan branch-scope correction

- Claimed `docs-source-supply-scan-branch-scope` after post-push local wiki edits showed a narrower distinction between docs/source branch evidence and local `HEAD` / stable source evidence for the supply command-center scan.
- Source-checked `origin/docs/developer-wiki-index` `f3e157f2`, local `HEAD` / stable `origin/master` `2cdf5fb8`, Miksuu `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `supplyMissionStarted.sqf`.
- Result: docs/source branch `f3e157f2` carries typed `["Base_WarfareBUAVterminal"]` scans at `supplyMissionStarted.sqf:28` in Chernarus and maintained Vanilla; local `HEAD` / stable, Miksuu and perf still broad-enumerate and post-filter; release carries heli-aware typed scan at `:52,58` in both maintained release roots. Updated supply owner/status pages and coordination rows only. No gameplay source changed.

## 2026-06-06T18:35:00+02:00 - Codex - Release context current-head correction

- Claimed `release-context-current-head-correction` after compact machine context still repeated release `3282ff3f` / Chernarus-only wording for lanes that current release `7ff18c49` later propagated into both maintained release roots.
- Source-checked release `7ff18c49` Chernarus and maintained Vanilla for paratrooper marker registration, hosted FPS guard, single `Skill_Init`, and commander-built ARTY ownership.
- Result: current release `7ff18c49` carries `HandleParatrooperMarkerCreation` at `Common/Init/Init_PublicVariables.sqf:34`, a single `Client\Module\Skill\Skill_Init.sqf` call at `Client/Init/Init_Client.sqf:564` with `WFBE_SK_FNC_Apply` at `:587`, and `if (!isDedicated) exitWith {};` at `Server/GUI/serverFpsGUI.sqf:4` in both maintained release roots. Current release and stable `origin/master` still lack the commander-built ARTY `GetCommanderTeam` handoff. Updated current snapshot/context and coordination rows only. No gameplay source changed.

## 2026-06-06T18:20:00+02:00 - Codex - Supply scan current-source scope correction

- Claimed `supply-scan-current-source-scope-correction` after current status pages and machine rows still treated the typed command-center scan as current-source propagated.
- Source-checked current source Chernarus and maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `supplyMissionStarted.sqf`, `Init_Town.sqf`, `Init_Server.sqf` and the dead-twin files.
- Result: current source/Vanilla, stable, Miksuu and perf still enumerate `nearestObjects [..., [], 80]` at `supplyMissionStarted.sqf:28` and post-filter `Base_WarfareBUAVterminal` at `:25`; release `7ff18c49` carries the typed heli-aware scan and dead-twin cleanup in both maintained release roots. Updated supply owner/status pages and machine rows only. No gameplay source changed.

## 2026-06-06T18:05:00+02:00 - Codex - Reaktiv branch status refresh

- Claimed `reaktiv-branch-status-refresh` after the dead-code row already marked Reaktiv unreachable but did not preserve current release-branch scope.
- Source-checked `Common/Module/Reaktiv` and `Reaktiv_Init.sqf` across current source/Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49`.
- Result: current source/Vanilla, stable, Miksuu and perf still carry the unreachable Reaktiv module in both maintained roots; release `7ff18c49` removes Reaktiv from maintained roots while stale modded Napf/Eden/Lingor copies remain. Updated Modules Atlas, Dead/stale code register and machine rows only. No gameplay source changed.

## 2026-06-06T17:55:00+02:00 - Codex - LoadoutManager root discovery branch-scope correction

- Claimed `loadoutmanager-root-discovery-branch-scope` after Tools/build, Source Fix queue and machine context still treated repo-marker root discovery as current-source behavior.
- Source-checked `Tools/LoadoutManager/FileManagement/FileManager.cs`: current source/stable `origin/master` `2cdf5fb8`, Miksuu `89ae9dad` and `origin/perf/quick-wins` `0076040f` still require an ancestor named `a2waspwarfare` at `:145,150-152`; release `7ff18c49` adds `IsA2WaspWarfareRoot` and accepts either the ancestor name or root markers `Missions/[55-2hc]warfarev2_073v48co.chernarus`, `Tools/LoadoutManager` and `AGENTS.md` at `:165-176`.
- Result: corrected Tools/build, Source Fix propagation context, Supply Mission Scan Narrowing and machine context/backlog records so current-source runs from generated Codex worktrees require a named ancestor unless the release-branch marker-root patch is ported. No gameplay source changed.

## 2026-06-06T17:48:00+02:00 - Codex - Gear profile filter current-head refresh

- Claimed `gear-profile-filter-current-head-refresh` after Feature Status, Source Fix queue and the paired hardening backlog rows still used older broad branch wording for the `_u_upgrade` save-filter bug and six-field profile import guard. Scope: docs/machine current-head refresh only; no gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Client_UI_Gear_SaveTemplateProfile.sqf` and `Init_ProfileGear.sqf`.
- Result: every checked maintained root/branch still keeps `_template_upgrade` assigned but `_u_upgrade` referenced at `SaveTemplateProfile.sqf:33,52,75`, and still accepts `count _x >= 6` before reading `_x select 6` in `Init_ProfileGear.sqf:17,25`. Updated Gear template profile filter, Feature Status, Source Fix queue and machine rows only. No gameplay source changed.

## 2026-06-06T17:35:00+02:00 - Codex - Vehicle cargo loop current-head refresh

- Claimed `vehicle-cargo-loop-current-head-refresh` after [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), Feature Status and Source Fix queue still had broad branch wording without current head hashes or `perf/quick-wins` parity detail. Scope: source-check branch heads and refresh docs/machine evidence only; no gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Common_EquipVehicle.sqf` and `Common_EquipBackpack.sqf`.
- Result: current source/Vanilla, stable, Miksuu and release still keep all five inclusive `for '_i' from 0 to count(_items)` loops. `perf/quick-wins` fixes the five bounds in Chernarus with `count(_items)-1`, but maintained Vanilla on perf still carries the inclusive loops, so this is a partial branch rescue rather than complete propagation. Updated the owner page, Feature Status, Source Fix queue and machine rows only. No gameplay source changed.

## 2026-06-06T17:22:00+02:00 - Codex - Auto-wall toggle current-head refresh

- Claimed `auto-wall-toggle-current-head-refresh` after the live auto-wall machine row still cited older Miksuu/release heads for a current-looking branch matrix. Scope: docs/machine current-head refresh only; no gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Init_Common.sqf`, CoIn `User14`, `RequestAutoWallConstructinChange.sqf`, `Construction_SmallSite.sqf` and `Construction_MediumSite.sqf`.
- Result: every checked maintained root still routes one global `isAutoWallConstructingEnabled` value through the same thin request handler. Release `7ff18c49` shifts `Init_Common.sqf` to `:200` and adds an `AARadar` exclusion to SmallSite/MediumSite wall creation, but it does not add side/requester scoping. Updated Construction/CoIn, Feature Status, Source Fix queue and machine rows only. No gameplay source changed.

## 2026-06-06T17:14:00+02:00 - Codex - Marker creation direct-channel index sharpening

- Claimed `marker-creation-channel-index-sharpening` from the returned public-variable scout after [Public variable channel index](Public-Variable-Channel-Index) still described `MARKER_CREATION` only as generic WASP/marker code.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49`: all checked roots keep the same `Common_CreateMarker.sqf:82-83` broadcast and `Client/FSM/updateclient.sqf:14-16` receiver registration.
- Result: `MARKER_CREATION` is now documented as a mixed caller-to-clients side-scoped marker relay with exact sender, receiver and caller anchors; future work should define sender/side/schema validation and delete/JIP/replay smoke before treating the relay as only cosmetic. No gameplay source changed.

## 2026-06-06T17:05:00+02:00 - Codex - Network hardening current-head refresh

- Claimed `network-hardening-current-head-refresh` after the hardening roadmap and networking overview still named older Miksuu/release refs for the PVF dispatcher and `SEND_MESSAGE` compile surfaces. Scope: source-check current branch heads and refresh docs/machine evidence only. No gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Server_HandlePVF.sqf`, `Client_HandlePVF.sqf`, `updateclient.sqf`, `Client_onEventHandler_SEND_MESSAGE.sqf` and `Common_SendMessage.sqf`.
- Result: every checked maintained root still keeps generic PVF dispatcher `Spawn (Call Compile _script)`; release only adds adjacent HC client filtering and shifts the client compile to `Client_HandlePVF.sqf:32`. Every checked maintained root also keeps `SEND_MESSAGE` receiver/helper `call compile` of message text. Refreshed roadmap/networking overview and matching machine rows only. No gameplay source changed.

## 2026-06-06T16:59:00+02:00 - Codex - Camp-count current-head refresh

- Claimed `camp-count-current-head-refresh` after the camp helper owner/status/machine rows still named older Miksuu/release refs for a current-looking branch matrix. Scope: source-check current branch heads and refresh docs/machine evidence only. No gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Common_GetTotalCamps.sqf`, `Common_GetTotalCampsOnSide.sqf`, `server_town.sqf`, `Common_GetRespawnThreeway.sqf` and `GUI_Menu_BuyUnits.sqf`.
- Result: every checked maintained root still returns `1` for zero-camp towns in both helpers and feeds the same capture mode 2, threeway respawn and depot-buy gates. Release `7ff18c49` only shifts the Buy Units caller lines to `GUI_Menu_BuyUnits.sqf:117-118`; it does not split real-count versus safe-denominator semantics. Updated Towns/Camps, Feature Status, Source Fix queue and machine rows only. No gameplay source changed.

## 2026-06-06T16:58:00+02:00 - Codex - Indicator exploration backlog sharpening

- Claimed `indicator-exploration-backlog-sharpening` after the returned UI indicator scout supplied exact current-source anchors for HUD/title surfaces, map/tactical markers, support markers, menu/list icons, status/debug channels and image/resource references. Scope: docs-only owner/backlog sharpening; no gameplay source edits planned.
- Source-checked representative anchors in current Chernarus for `Rsc/Titles.hpp`, `Client_UpdateRHUD.sqf`, `updateavailableactions.fsm`, marker update loops, paratrooper/MASH/UAV/artillery/ICBM marker scripts, `RscClickableText`/image references and performance/status channels.
- Result: [Client UI systems](Client-UI-Systems-Atlas#indicator-exploration-backlog) now carries an exact-anchor matrix with index state and canonical owner route for each indicator family; [Client UI, HUD and menus](Client-UI-HUD-And-Menus#known-ui-findings) links directly to the indicator inventory route. No gameplay source changed.

## 2026-06-06T16:50:00+02:00 - Codex - Factory purchase current-head refresh

- Claimed `factory-purchase-current-head-refresh` after factory buy-menu price/key and destroyed-factory refund owner/status/machine rows still named older Miksuu/release refs. Scope: source-check current branch heads and refresh docs/machine evidence only. No gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `GUI_Menu_BuyUnits.sqf`, `Client_UIFillListBuyUnits.sqf` and `Client_BuildUnit.sqf`.
- Result: current source/Vanilla, stable, Miksuu and perf still keep selected-detail price drift, no level-0 `UNIT_COST_MODIFIER` reset, mixed driver-default profile keys and no dead/null factory refund. Release `7ff18c49` fixes selected-detail parity in both maintained roots and mirrors both driver keys in several write paths, but modifier reset, one-key normalization and dead/null factory refund remain open. Updated Factory and purchase systems, Feature Status, Source Fix queue and machine rows only. No gameplay source changed.

## 2026-06-06T16:49:00+02:00 - Codex - Status provenance current-head refresh

- Claimed `status-provenance-current-head-refresh` after scout returns and local stale-ref scans found current-looking documentation still naming older Miksuu/source labels in Feature Status and the salvage branch matrix. Scope: docs/machine provenance cleanup only; no gameplay source edits planned.
- Source-checked current branch heads for camp flag texture and salvage payout/loop evidence: current source/Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` still keep the documented current-source camp flag drift / repair-side refresh gap and salvage lowercase `ChangePlayerfunds` / `updatesalvage.sqf` `||` loop shape.
- Result: refreshed the broad upstream note, the camp flag row and the salvage branch matrix/machine rows to current-head provenance while preserving patch-ready conclusions. No gameplay source changed.

## 2026-06-06T16:17:00+02:00 - Codex - Empty supply-truck current-head refresh

- Claimed `empty-supply-truck-current-head-refresh` after the empty supply-truck cleanup owner/status/machine rows still named older Miksuu/release refs. Scope: source-check current branch heads and refresh docs/machine evidence only. No gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for `Server/FSM/emptyvehiclescollector.sqf` and `Server/Functions/Server_HandleEmptyVehicle.sqf`.
- Result: every checked maintained root still drains `WF_Logic emptyVehicles` into `WFBE_SE_FNC_HandleEmptyVehicle` and sets supply-truck `_delay = 86400` in `Server_HandleEmptyVehicle.sqf:23`. The `f532f706..89ae9dad` Miksuu delta and `3282ff3f..7ff18c49` release delta do not touch the checked empty-vehicle cleanup files. Updated marker cleanup/restoration, Feature Status, Source Fix queue and machine rows only. No gameplay source changed.

## 2026-06-06T16:08:00+02:00 - Codex - Client UI branch-evidence refresh

- Claimed `client-ui-branch-evidence-refresh` after stale-ref scanning found the Client UI vote/help/main-menu, tactical fast-travel fee and clickable-text branch matrices still naming older Miksuu/release heads. Scope: source-check current branch heads and refresh docs/machine evidence only. No gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49` for vote loops/coloring, help dialog load/unload keys, main-menu GPS actions, tactical fast-travel fee handling and `RscClickableText.soundPush[]`.
- Result: all checked maintained roots still keep the inclusive vote refresh loops, vote row-color offset, help namespace mismatch, fast-travel fee TODO/hidden-destination/local-debit shape and malformed clickable-text base sound array. Release `7ff18c49` now exposes `MenuAction = 19` GPS show/hide at `Dialogs.hpp:1237`, but still keeps old `17/18` zoom handlers at `GUI_Menu.sqf:221,225` without matching emitters. Updated Client UI systems and matching machine rows only. No gameplay source changed.

## 2026-06-06T16:02:00+02:00 - Codex - Gear template current-head refresh

- Claimed `gear-template-current-head-refresh` after the gear-template owner/status/machine rows still named older Miksuu evidence for creation/display/save gate scope. Scope: source-check current branch heads, refresh docs/machine evidence only, and leave gameplay source untouched.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49`: all checked maintained roots still keep `Client_UI_Gear_AddTemplate.sqf:136` accepting templates by either `WFBE_UP_BARRACKS` or `WFBE_UP_GEAR`, `Client_UI_Gear_FillTemplates.sqf:17` displaying only against `WFBE_UP_GEAR`, and `Client_UI_Gear_SaveTemplateProfile.sqf:33,52,75` referencing undefined `_u_upgrade`.
- Confirmed the `f532f706..89ae9dad` Miksuu delta and `7195b331..7ff18c49` release delta do not touch the checked gear-template files. Updated owner/status/queue pages and machine rows only. No gameplay source changed.

## 2026-06-06T15:56:22+02:00 - Codex - RequestSpecial upgrade-sync current-head refresh

- Claimed `requestspecial-upgrade-sync-current-head-refresh` after the upgrade-sync owner/status/machine rows still cited older Miksuu/release refs and one stale client timer line. Scope: refresh docs and machine evidence only; no gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49`: all checked maintained roots still assign `_args = _this` at `Server_HandleSpecial.sqf:3` and keep the `upgrade-sync` case at `:67-73` reading side from `_args` but id/level from `_this`.
- Release `7ff18c49` shifts both maintained-root client callers to `Client/GUI/GUI_UpgradeMenu.sqf:254`; current/stable/Miksuu/perf callers remain at `:241`. The `fb3084c2..7ff18c49` release delta does not touch the checked upgrade-sync files. Refreshed Support specials, Upgrades, Feature status, Source fix queue, dashboard and machine rows only. No gameplay source changed.

## 2026-06-06T15:50:11+02:00 - Codex - AI supply-truck current-head refresh

- Claimed `ai-supply-truck-current-head-refresh` after stale-ref scanning found the AI supply-truck owner/revival pages and machine rows still citing older Miksuu/release evidence. Scope: source-check current branch heads, refresh docs/machine evidence only, and leave gameplay source untouched.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f`, release `7ff18c49` and `origin/feat/ai-commander` `c20ce153` for `UpdateSupplyTruck`, `AI_UpdateSupplyTruck.sqf` and the missing `Server/FSM/supplytruck.fsm`.
- Result: current/stable/upstream/perf still keep the commented compile plus raw gated spawn and missing FSM; release `7ff18c49` logs/disables the branch at `Init_Server.sqf:386` in both maintained roots; `feat/ai-commander` guards only Chernarus at `:389` while Vanilla remains raw. Updated owner/status/queue pages and machine rows only. No gameplay source changed.

## 2026-06-06T15:41:16+02:00 - Codex - WASP marker wait current-head refresh

- Claimed `wasp-marker-wait-current-head-refresh` after stale-ref scanning found the WASP marker wait owner/machine rows still citing older Miksuu/release heads. Scope: source-check current branch heads, refresh docs/machine evidence only, and leave gameplay source untouched.
- Source-checked current source Chernarus plus maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f` and release `7ff18c49`: all checked maintained roots still load `WASP\global_marking_monitor.sqf` from client init and keep `disableUserInput true`, `findDisplay 54` polling and `disableUserInput false` at `global_marking_monitor.sqf:57,64,73`.
- Current/stable/Miksuu/perf load the monitor at `Client/Init/Init_Client.sqf:279`; release `7ff18c49` shifts the launch to `:283` in both maintained release roots. The sibling display-12 wait remains the local throttled pattern at `global_marking_monitor.sqf:80`. Updated owner/status/machine rows only. No gameplay source changed.

## 2026-06-06T15:22:10+02:00 - Codex - Release leaf current-head refresh

- Claimed `release-leaf-current-head-refresh` after a stale-ref scan found owner/leaf pages still calling `7195b331` the current release head for supply scan, hosted FPS and paratrooper marker static evidence even though `origin/release/2026-06-feature-bundle` is now `7ff18c49`. Scope: verify the relevant release files did not change in `7195b331..7ff18c49`, then refresh wording only where it describes current release head evidence. No gameplay source edits planned.
- Source-checked the `7195b331..7ff18c49` release delta: it touches delegated-AI fallback/locality and cleaner/restorer startup files only, not `supplyMissionStarted.sqf`, `Init_PublicVariables.sqf`, `serverFpsGUI.sqf`, `monitorServerFPS.sqf` or the relevant `Init_Server.sqf` compile/comment lines.
- Verified current release `7ff18c49` still carries the heli-aware supply command-center scan at `supplyMissionStarted.sqf:52,58`, paratrooper marker registration at `Common/Init/Init_PublicVariables.sqf:34`, and guarded single FPS publisher with absent `monitorServerFPS.sqf` in both maintained roots. Refreshed the stale leaf/decision pages and coordination records. No gameplay source changed.

## 2026-06-06T15:02:41+02:00 - Codex - Resource income branch-evidence refresh

- Claimed `resource-income-branch-evidence-refresh` for the resource income payout/display drift row. Scope: source-check current Miksuu upstream and release refs, then refresh stale branch evidence in the economy owner/status/queue and machine rows. No gameplay source edits planned.
- Source-checked current source Chernarus plus maintained Vanilla, Miksuu upstream `89ae9dad`, release `7ff18c49` and `origin/perf/quick-wins` `0076040f`. All checked refs keep `updateresources.sqf:31` gating side-supply growth, player paychecks and AI commander funds, with income system `4` server multiplier at `updateresources.sqf:42-43`.
- Source-checked `Client_GetIncome.sqf:20-30` on the same branch heads: income system `4` still displays the commander/player split without the server-side `1.5` multiplier. Updated economy/status/source-fix and machine rows to current Miksuu/release refs. No gameplay source changed.

## 2026-06-06T14:50:18+02:00 - Codex - Side supply branch-evidence refresh

- Claimed `side-supply-branch-evidence-refresh` for the side-supply clamp/temp-channel validation row. Scope: source-check current Miksuu upstream and current release refs, then refresh stale branch evidence in the economy owner page and machine/status rows. No gameplay source edits planned.
- Source-checked current Miksuu upstream `89ae9dad` and release `7ff18c49` in Chernarus plus maintained Vanilla: both still use `_currentSupply - _amount` for negative side-supply results in `Common_ChangeSideSupply.sqf:25` and `Server_ChangeSideSupply.sqf:12,36`, and both still trust `_side` from the `wfbe_supply_temp_west/east` payloads.
- Rechecked `origin/perf/quick-wins` `0076040f`: it still fixes the arithmetic floor only in source Chernarus; maintained Vanilla remains old and the direct temp-channel authority check is still absent.
- Rechecked the adjacent reason-string path in the same helper: current source/Vanilla, Miksuu `89ae9dad`, `perf/quick-wins` and release `7ff18c49` still read `_reason` only when `count _this > 3`, so three-argument `AttackWave.sqf:40` drops its reason while four-argument supply completion keeps its reason.
- Refreshed [Economy authority first cut](Economy-Authority-First-Cut#side-supply-branch-matrix), [Feature status](Feature-Status-Register), [Source fix queue](Source-Fix-Propagation-Queue) and matching feature/hardening machine rows to current Miksuu/release refs. No gameplay source changed.

## 2026-06-06T14:37:44+02:00 - Codex - P0 network branch-evidence refresh

- Claimed `p0-network-branch-evidence-refresh` for the direct `SEND_MESSAGE` compile surface and generic PVF dispatcher compile surface. Scope: source-check current release and current Miksuu upstream refs, then refresh docs/machine rows only where stale branch evidence remains. No gameplay source edits planned.
- Source-checked Miksuu upstream `89ae9dad` and release `7ff18c49` in Chernarus plus maintained Vanilla: PVF still dispatches `_parameters Spawn (Call Compile _script)` at `Server_HandlePVF.sqf:14`; Miksuu clients keep it at `Client_HandlePVF.sqf:22`, while release clients keep it at `:32` after the adjacent HC filter.
- Source-checked direct `SEND_MESSAGE`: both refs/roots still register the direct PVEH at `Client/FSM/updateclient.sqf:10-12`, compile multi-language payload text at `Client_onEventHandler_SEND_MESSAGE.sqf:27`, and repeat helper-side `call compile _messageText` plus broadcast at `Common_SendMessage.sqf:26,37-38`.
- Updated the PVF and `SEND_MESSAGE` owner/status/queue pages plus matching feature/hardening machine rows from stale upstream/release refs to current Miksuu `89ae9dad` and release `7ff18c49`. No gameplay source changed.

## 2026-06-06T14:31:50+02:00 - Codex - Release head machine-row refresh

- Claimed `release-head-machine-row-refresh` after human-facing Feature Status rows were already moved to current release head `7ff18c49` while several machine-readable feature/hardening rows still named older `7195b331` release evidence. Scope: source-check only the stale propagated/static lanes and refresh machine/status routing. No gameplay source edits planned.
- Source-checked release `7ff18c49` Chernarus and maintained Vanilla for paratrooper marker registration, single `Skill_Init`/`WFBE_SK_FNC_Apply`, hosted `serverFpsGUI` guard plus absent redundant monitor, and supply command-center scan narrowing.
- Updated `agent-feature-status.jsonl`, `agent-hardening-backlog.jsonl` and `agent-release-readiness.json` to use `7ff18c49` for checked release-head rows whose relevant files did not change in the `7195b331..7ff18c49` delta. Historical `7195b331` lane/provenance notes remain separate. No gameplay source changed.

## 2026-06-06T14:20:35+02:00 - Codex - AI commander upgrade debit branch route

- Claimed `ai-commander-upgrade-debit-branch-route` from the Feature Status AI commander upgrade debit row. Scope: source-check current Chernarus/Vanilla and key branches for the AI upgrade worker's cost lookup and funds/supply debit order, then route the evidence through existing AI/economy/upgrade owner pages. No gameplay source edits planned.
- Source-checked current source/Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `89ae9dad`, `origin/perf/quick-wins` `0076040f`, release `7ff18c49` and `origin/feat/ai-commander` `c20ce153` for `Server_AI_Com_Upgrade.sqf`.
- Result: current source/Vanilla, stable, upstream and perf keep raw AI_ORDER cost lookup plus swapped AI funds/side-supply debit. Release fixes debit order in both maintained roots; `feat/ai-commander` fixes debit plus cost-level lookup only in Chernarus while maintained Vanilla remains old.
- Updated [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix), [Upgrades and research](Upgrades-And-Research-Atlas), [Economy, towns and supply](Economy-Towns-And-Supply), [Feature status](Feature-Status-Register), [Source fix queue](Source-Fix-Propagation-Queue), dashboard and machine rows. No gameplay source changed.

## 2026-06-06T14:11:02+02:00 - Codex - Server AI order helper index

- Claimed `server-ai-order-helper-index` from the codebase coverage gap list. Scope: source-check the compiled `Server/AI/Orders/*` helper family, document static callers and execution boundaries, and route runtime readers to the existing cleanup/restoration atlas instead of duplicating that page. No gameplay source edits planned.
- Source-checked current Chernarus `Server/Init/Init_Server.sqf:13-18`, `Server/AI/Orders/AI_MoveTo.sqf`, `AI_Patrol.sqf`, `AI_TownPatrol.sqf`, `AI_WPAdd.sqf`, `AI_WPRemove.sqf`, support drop callers and resistance callers.
- Result: `AIMoveTo`, `AIPatrol`, `AIWPAdd` and `AIWPRemove` have proven support/resistance callers; `AITownPatrol` is compiled but no static Chernarus caller was found outside the compile line and helper file. Commander map-order execution remains unproven.
- Updated [Function and module index](Function-And-Module-Index#server-ai-order-helpers), [AI, headless and performance](AI-Headless-And-Performance#commander-team-order-variables), [Server gameplay runtime](Server-Gameplay-Runtime-Atlas#runtime-loops), [SQF code atlas](SQF-Code-Atlas), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T13:58:33+02:00 - Codex - Release 7ff18c49 PR8 delta route

- Claimed `release-7ff18c49-pr8-delta-route` after the release branch moved from the previously documented `7195b331` intermediate to current `origin/release/2026-06-feature-bundle` head `7ff18c49`. No gameplay source edits planned.
- Source-checked the `7195b331..7ff18c49` diff: it touches 16 files, with matching Chernarus and maintained Vanilla changes for delegated AI fallback/locality guards (`Client_DelegateAIStaticDefence.sqf:27`, `Client_DelegateTownAI.sqf:27`, `Common_CreateUnit.sqf:34-36`, `Common_CreateUnitForStaticDefence.sqf:68-69`) and cleaner/restorer startup hardening (`crater_cleaner.sqf:5,7,50`, `droppeditems_cleaner.sqf:5,7,46`, `ruins_cleaner.sqf:5,7,30`, `buildings_restorer.sqf:4,6,18,31`).
- Result: prior propagated-fix conclusions from `7195b331` carry forward at `7ff18c49`; the new delta is release-branch evidence only. It does not close DR-42 static-defense update-back/failover because update-back/failover work remains absent and still needs explicit design plus smoke.
- Updated [PR cleanup lab](PR-Cleanup-And-Integration-Lab#pr-8-head-refresh-7ff18c49), [Current source snapshot](Current-Source-Status-Snapshot), [Feature status](Feature-Status-Register), [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook), [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard, pruning ledger and machine records. No gameplay source changed.

## 2026-06-06T13:34:23+02:00 - Codex - Town AI vehicle despawn branch route

- Claimed `town-ai-vehicle-despawn-branch-route` from the DR-45 town-AI passenger/crew safety backlog. No gameplay source edits planned.
- Source-checked current source Chernarus and maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `master` `89ae9dad` from `https://github.com/miksuu/a2waspwarfare.git`, `origin/perf/quick-wins` `0076040f` and `origin/release/2026-06-feature-bundle` `7ff18c49` for `Server/FSM/server_town_ai.sqf`.
- Result: every checked maintained root/branch still deletes tracked inactive town-AI vehicles using `alive _x` plus `!(isPlayer leader group _x)` without a player `crew` check. Current source/stable/perf/release use `server_town_ai.sqf:216-221`; Miksuu upstream diagnostics move the block to `:265-285` but keep the same guard at `:278`.
- Updated [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#current-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard, pruning ledger and machine records. No gameplay source changed.

## 2026-06-06T13:15:54+02:00 - Codex - Mission start parameter index

- Claimed `mission-start-parameter-index` after Steff asked to add all start parameters to the wiki.
- Source-checked maintained Chernarus and Vanilla Takistan `Rsc/Parameters.hpp`; they are identical in current source and expose 89 active lobby-visible classes under `class Params`.
- Added [Mission start parameters index](Mission-Start-Parameters-Index) with source-order, source lines, class names, lobby titles, defaults, choices, category ranges and caveats for hidden/commented, forced, visible-no-op and mislabeled parameters. No gameplay source changed.

## 2026-06-06T10:45:23+02:00 - Codex - Indicator exploration backlog

- Claimed `indicator-exploration-backlog` after Steff asked to check all indicators and add exploring them to the wiki to-do list.
- Source-scanned indicator families across `Rsc/Titles.hpp`, `Client/Client_UpdateRHUD.sqf`, `Client/FSM/updateavailableactions.fsm`, `Client/FSM/client_title_capture.sqf`, marker update loops, Tactical/Respawn markers, support marker PVFs, Buy Units/EASA/Gear/Upgrade icons, server-FPS/status publishers and `Client/Images`.
- Added a canonical exploration checklist to [Client UI systems](Client-UI-Systems-Atlas#indicator-exploration-backlog), then routed it from [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions) and [Progress dashboard](Progress-Dashboard). No gameplay source changed.

## 2026-06-06T10:34:00+02:00 - Codex - Air Event parameter documentation

- Claimed `air-event-parameter-doc-gap` after Steff asked whether the old Air Event setting still exists.
- Source-checked current Chernarus and maintained Vanilla: `WFBE_AIR_EVENT_ENABLED` is exposed in `Rsc/Parameters.hpp`, converted into `IS_air_war_event` during `initJIPCompatible.sqf`, and still gates event economy/upgrade clearance, ICBM availability and Avenger/Tunguska-style heavy-AA entries.
- Added a compact canonical caveat to [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#air-event-override-caveat) and a short route from [Feature status](Feature-Status-Register). No gameplay source changed.

## 2026-06-06T03:35:00+02:00 - Codex - Hosted FPS release status refresh

- Claimed `hosted-fps-release-status-refresh` after [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) and [Pending owner decisions](Pending-Owner-Decisions) still described release `3282ff3f` as Chernarus-only.
- Rechecked current release head `7195b331`: both maintained release roots guard `Server/GUI/serverFpsGUI.sqf` with `if (!isDedicated) exitWith {};`, the redundant `Server/Module/serverFPS/monitorServerFPS.sqf` file is absent, and both release `Init_Server.sqf` files keep the monitor compile commented.
- Updated owner/decision pages, release-readiness and feature/hardening machine rows plus the dashboard. No gameplay source changed.

## 2026-06-06T03:10:00+02:00 - Codex - Paratrooper release status refresh

- Claimed `paratrooper-release-status-refresh` after [Current source snapshot](Current-Source-Status-Snapshot) and one Feature Status row still said the current release branch lacked `HandleParatrooperMarkerCreation`, despite the newer `7195b331` spot-check and source evidence.
- Rechecked docs/source, stable `origin/master` and release `7195b331`: docs/source Chernarus and maintained Vanilla register `HandleParatrooperMarkerCreation` at `Common/Init/Init_PublicVariables.sqf:39`; stable still omits it; release `7195b331` registers it at `:34` in both maintained release roots.
- Updated [Paratrooper marker revival](Paratrooper-Marker-Revival), [Current source snapshot](Current-Source-Status-Snapshot), [Feature status](Feature-Status-Register), release/feature machine rows and the dashboard. No gameplay source changed.

## 2026-06-06T02:55:00+02:00 - Codex helper - SEND_MESSAGE direct compile branch route

- Claimed `send-message-direct-compile-branch-route` from the direct-PV/P0 hardening backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f` and release `origin/release/2026-06-feature-bundle` `7195b331` for `Client/FSM/updateclient.sqf`, `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf` and `Common/Functions/Common_SendMessage.sqf`.
- Result: every checked maintained root/branch keeps direct `SEND_MESSAGE` PVEH registration, receiver-side payload-text `call compile` when the multi-language flag is true, and the same helper compile before `missionNamespace setVariable` / `publicVariable`.
- Updated [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix), [Networking](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T02:45:00+02:00 - Codex - Client skill release status refresh

- Claimed `client-skill-release-status-refresh` after [Client skill init idempotency](Client-Skill-Init-Idempotency) and machine rows still described `origin/release/2026-06-feature-bundle` as duplicate-init despite the newer `7195b331` release head.
- Rechecked current source, stable `origin/master` and release `7195b331`: docs/source Chernarus and maintained Vanilla still have one `Skill_Init.sqf` call at `Client/Init/Init_Client.sqf:547` plus `WFBE_SK_FNC_Apply` at `:571`; stable still duplicates at `:561` and `:585`; release `7195b331` has one `Skill_Init.sqf` call at `:564` and apply at `:587` in both maintained roots.
- Updated [Client skill init idempotency](Client-Skill-Init-Idempotency), [Current source snapshot](Current-Source-Status-Snapshot), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), release/feature machine rows and the dashboard. No gameplay source changed.

## 2026-06-06T02:25:00+02:00 - Codex helper - Gear template creation gate branch route

- Claimed `gear-template-creation-gate-branch-route` from the gear-template owner-decision backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f` and release `origin/release/2026-06-feature-bundle` `7195b331` for `Client_UI_Gear_AddTemplate.sqf`, `Client_UI_Gear_FillTemplates.sqf` and `Client_UI_Gear_SaveTemplateProfile.sqf`.
- Result: every checked maintained root/branch keeps AddTemplate accepting a template when the max item upgrade is within either `WFBE_UP_BARRACKS` or `WFBE_UP_GEAR`, FillTemplates displaying stored templates only against `WFBE_UP_GEAR`, and SaveTemplateProfile still filtering with undefined `_u_upgrade`.
- Updated [Gear template profile filter](Gear-Template-Profile-Filter#creation-gate-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T02:20:00+02:00 - Codex helper - AI supply-truck branch route

- Claimed `ai-supply-truck-branch-route` from the abandoned AI logistics backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f`, release `origin/release/2026-06-feature-bundle` `7195b331` and `origin/feat/ai-commander` `c20ce153` for `Server/Init/Init_Server.sqf`, `Server/AI/AI_UpdateSupplyTruck.sqf`, config defaults and mission params.
- Result: current source/Vanilla, stable, upstream and perf still comment out the `UpdateSupplyTruck` compile while the AI-commander/supply-system branch raw-spawns it and the helper still points at missing `Server\FSM\supplytruck.fsm`; release logs/disables the branch in both maintained roots; `feat/ai-commander` guards only Chernarus, leaving Vanilla raw and not reviving logistics.
- Updated [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix), [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T02:05:00+02:00 - Codex helper - Factory destroyed-purchase refund branch route

- Claimed `factory-destroyed-purchase-refund-branch-route` from the factory/purchase authority and refund backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f` and release `origin/release/2026-06-feature-bundle` `7195b331` for `GUI_Menu_BuyUnits.sqf` debit timing and `Client_BuildUnit.sqf` abort cleanup.
- Result: current source/Vanilla, stable, upstream and perf all debit after `BuildUnit` spawn and leave the dead/null factory exit as queue cleanup with no refund. Release carries `_currentCost` into `BuildUnit` and refunds in the empty/crewless branch, but its dead/null factory exit still does not refund.
- Updated [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas#destroyed-factory-refund-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T01:35:00+02:00 - Codex helper - Side-supply reason-string branch route

- Claimed `side-supply-reason-string-branch-route` from the side-supply diagnostics backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706` (local ref after a fetch reset), `origin/perf/quick-wins` `0076040f` and current release `fb3084c2`.
- Result: every checked maintained root/branch keeps `Common_ChangeSideSupply.sqf:8-14` reading `_reason` only when `count _this > 3`, so three-argument `Server/PVFunctions/AttackWave.sqf:40` drops its audit reason while four-argument `supplyMissionCompleted.sqf` preserves the formatted reason.
- Updated [Economy authority first cut](Economy-Authority-First-Cut#side-supply-reason-string-branch-matrix), [Economy, towns and supply](Economy-Towns-And-Supply), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T01:15:00+02:00 - Codex helper - Resource income payout/display branch route

- Claimed `resource-income-payout-branch-route` from the economy correctness backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f` and current release `7195b331`.
- Result: every checked maintained root/branch keeps `Server/FSM/updateresources.sqf:29-70` wrapping side-supply growth, player paychecks and AI-commander funds in the same town-supply cap guard, and keeps income system `4` applying a server-side `1.5` multiplier that `Client/Functions/Client_GetIncome.sqf:20-29` does not mirror for display math.
- Updated [Economy, towns and supply](Economy-Towns-And-Supply#resource-income-branch-matrix), [Economy authority first cut](Economy-Authority-First-Cut), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T01:32:00+02:00 - Codex - Stable low-priority TODO cluster prune

- Claimed `stable-low-priority-todo-cluster-prune` after [Feature status](Feature-Status-Register) still carried three vague TODO-only rows: base/town dynamic logic, CoIn border relocation and AI attack radio/combat tuning.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master`, Miksuu upstream, `origin/perf/quick-wins` and `origin/release/2026-06-feature-bundle`. All checked roots keep the same TODO shapes at `Init_Common.sqf:273-285`, `coin_interface.sqf:114,419-425` and `Server_AI_SetTownAttackPath.sqf:74-78`.
- Collapsed the three Feature Status rows into one low-priority TODO cluster, then moved useful detail to [Architecture overview](Architecture-Overview#representative-source-anchors), [Construction and CoIn](Construction-And-CoIn-Systems-Atlas#coin-runtime-behavior) and [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map#findings). No gameplay source changed.

## 2026-06-06T01:20:00+02:00 - Codex - Dashboard Latest Batch trim after resource income

- Claimed `dashboard-latest-batch-retrim-after-resource-income` during rebase after the resource-income payout branch route made [Progress dashboard](Progress-Dashboard) grow past five current rows.
- Kept the newest five live dashboard rows and aged `fast-travel-fee-branch-route` out of Latest Batch. The fast-travel finding remains preserved in this worklog, [`agent-events.jsonl`](agent-events.jsonl), [Client UI systems](Client-UI-Systems-Atlas#tactical-fast-travel-fee-branch-matrix), [Support specials](Support-Specials-And-Tactical-Modules-Atlas), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and git history.
- No gameplay source changed.

## 2026-06-06T00:50:00+02:00 - Codex helper - RequestSpecial upgrade-sync branch route

- Claimed `requestspecial-upgrade-sync-branch-route` from the RequestSpecial/upgrades cleanup backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f` and current release `d482c742`.
- Result: every checked maintained root/branch keeps the same `Server_HandleSpecial.sqf` mixed `_args` / `_this` parser for `upgrade-sync`, while `Server_HandleSpecial.sqf:3` assigns `_args = _this`; this is cleanup/fragility debt, not a confirmed current runtime break. Release only shifts the Chernarus upgrade-menu caller to `GUI_UpgradeMenu.sqf:254`.
- Updated [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix), [Upgrades and research](Upgrades-And-Research-Atlas), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T00:30:00+02:00 - Codex helper - vote/help UI edge branch route

- Claimed `vote-help-ui-edge-branch-route` from the UI correctness backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master` `2cdf5fb8`, Miksuu upstream `f532f706`, `origin/perf/quick-wins` `0076040f` and release `3282ff3f`.
- Result: every checked maintained root/branch keeps the same vote inclusive-loop and row-color shape, help-panel load/unload namespace mismatch and main-menu GPS `17/18` router-only shape. Release only moves line numbers for Help and the main menu.
- Updated [Client UI systems](Client-UI-Systems-Atlas#vote-help-and-main-menu-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T00:55:00+02:00 - Codex - Dashboard Latest Batch trim after fast-travel

- Claimed `dashboard-latest-batch-retrim-after-fast-travel` during rebase after the fast-travel fee branch route made [Progress dashboard](Progress-Dashboard) grow to six published rows.
- Kept the newest five live dashboard rows and aged `empty-supply-truck-cleanup-branch-route` out of Latest Batch. The empty supply-truck finding remains preserved in this worklog, [`agent-events.jsonl`](agent-events.jsonl), [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas#empty-supply-truck-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and git history.
- No gameplay source changed.

## 2026-06-06T00:35:00+02:00 - Codex - Dashboard Latest Batch trim after vote/help

- Claimed `dashboard-latest-batch-retrim-after-vote-help` after [Progress dashboard](Progress-Dashboard) Latest Batch grew to six rows when the vote/help UI edge batch landed.
- Trimmed the table back to the newest five published rows by aging `clickabletext-soundpush-branch-route` out of Latest Batch. The clickable-text finding remains preserved in this worklog, [`agent-events.jsonl`](agent-events.jsonl), [Client UI systems](Client-UI-Systems-Atlas#clickable-text-soundpush-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and git history.
- No gameplay source changed.

## 2026-06-06T00:20:00+02:00 - Codex - Salvage pruning ledger duplicate trim

- Claimed `pruning-ledger-salvage-duplicate-row-trim` after [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger) carried both the newer `salvage-payout-cleanup-branch-route` row and the older mini-scout `salvage-payout-loop-branch-route` row in Recent Pruning Decisions.
- Removed the older duplicate row from the active ledger only. The broader branch-checked salvage cleanup row remains live, and provenance stays in this worklog, [`agent-events.jsonl`](agent-events.jsonl), git history and [Construction and CoIn](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix).
- No gameplay source changed.

## 2026-06-06T00:15:00+02:00 - Codex-helper - Side-supply clamp branch route

- Claimed `side-supply-clamp-branch-route` from the economy authority backlog.
- Source-checked current source Chernarus, maintained Vanilla, stable `origin/master`, `miksuu/master`, `origin/perf/quick-wins` and `origin/release/2026-06-feature-bundle` for `Common_ChangeSideSupply.sqf` and `Server_ChangeSideSupply.sqf`.
- Result: current source/Vanilla, stable, upstream and release all still floor negative results with `_currentSupply - _amount` and trust payload `_side` in direct `wfbe_supply_temp_west/east` handlers. `perf/quick-wins` fixes only Chernarus arithmetic to `0`; Vanilla and DR-44 side/channel/requester validation remain open.
- Refreshed [Economy authority first cut](Economy-Authority-First-Cut) as the canonical branch route and condensed [Economy/towns/supply](Economy-Towns-And-Supply), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger) and machine records. No gameplay source changed.

## 2026-06-06T00:00:00+02:00 - Codex-helper - WASP marker wait branch route

- Claimed `wasp-marker-wait-branch-route` from the UI/performance backlog.
- Source-checked current docs/source Chernarus, maintained Vanilla, `origin/master`, `miksuu/master`, `origin/perf/quick-wins` and `origin/release/2026-06-feature-bundle` for `WASP/global_marking_monitor.sqf` and the `Client/Init/Init_Client.sqf` launch line.
- Result: every checked maintained root/branch still loads the client-local WASP marker monitor and keeps `disableUserInput true`, the unslept display-54 polling window and final `disableUserInput false` in `global_marking_monitor.sqf:57-73`; the display-12 wait at `:80` remains the throttled idiom to copy. Release Chernarus only shifts the launch line to `Init_Client.sqf:282`.
- Refreshed [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) as the canonical branch route and condensed [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger) and machine records. No gameplay source changed.

## 2026-06-06T20:35:00+02:00 - Codex - supply scan matrix dedupe/current-head refresh
- Claimed `supply-scan-matrix-dedupe-current-head` after stale current-facing `2cdf5fb8` supply-scan wording remained even though current `origin/master` / local `master` now point at `89ae9dad`.
- Refreshed [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [Feature status](Feature-Status-Register) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f`, docs/source `f3e157f2` and release `7ff18c49` stay separated.
- Kept the canonical branch/root matrix on [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) and reduced duplicate short-status routing on the leaf/playbook/status surfaces. No gameplay source changed.

## 2026-06-06T21:00:00+02:00 - Codex - economy current-head branch refresh
- Claimed `economy-current-head-branch-refresh` after source-checking that the side-supply clamp/reason and resource-income files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Economy authority first cut](Economy-Authority-First-Cut#side-supply-branch-matrix), [Economy, towns and supply](Economy-Towns-And-Supply#resource-income-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for side-supply clamp/reason and resource-income debt.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for those economy lanes. Side-supply arithmetic, reason parsing and resource-income behavior remain future code-owner work; no gameplay source changed.

## 2026-06-06T21:20:00+02:00 - Codex - network P0 current-head refresh
- Claimed `network-p0-current-head-refresh` after source-checking that the PVF dispatcher and `SEND_MESSAGE` files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook#current-branch-matrix), [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix), [Networking and public variables](Networking-And-Public-Variables), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for PVF dispatcher lookup and direct `SEND_MESSAGE` compile.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for those P0 network lanes. PVF dispatcher lookup hardening and structured/localized `SEND_MESSAGE` payload work remain future code-owner work; no gameplay source changed.

## 2026-06-06T21:40:00+02:00 - Codex - factory purchase stable-head refresh
- Claimed `factory-purchase-stable-head-refresh` after source-checking that the buy-menu/list/build-unit files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas#buy-menu-price-and-driver-key-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for buy-menu price/key cleanup and destroyed-factory refund policy.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for those factory lanes. Price/key alignment and purchase acceptance/debit/refund policy remain future code-owner work; no gameplay source changed.

## 2026-06-06T21:55:00+02:00 - Codex - WASP marker wait stable-head refresh
- Claimed `wasp-marker-wait-stable-head-refresh` after source-checking that the WASP marker helper/client-init files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for the display-54 input-lock busy wait.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this WASP lane. The tiny throttled-wait patch and marker-dialog smoke remain future code-owner work; no gameplay source changed.

## 2026-06-06T22:10:00+02:00 - Codex - empty supply-truck stable-head refresh
- Claimed `empty-supply-truck-stable-head-refresh` after source-checking that the empty-vehicle collector/handler files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas#empty-supply-truck-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for the 24-hour supply-truck empty timeout.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this cleanup lane. The keep-and-label versus shorter/parameterized timeout decision remains future runtime/logistics owner work; no gameplay source changed.

## 2026-06-06T22:25:00+02:00 - Codex - auto-wall toggle stable-head refresh
- Claimed `auto-wall-toggle-stable-head-refresh` after source-checking that current `origin/master` / local `master` `89ae9dad` still keeps the global auto-wall toggle shape; the `2cdf5fb8..89ae9dad` diff only touches checked `Init_Common.sqf` roots for unrelated town-defense helper compile wiring.
- Refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for the global `isAutoWallConstructingEnabled` scope decision.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this auto-wall lane. The global-versus-side/requester policy decision remains future construction owner work; no gameplay source changed.

## 2026-06-06T22:40:00+02:00 - Codex - salvage payout stable-head refresh
- Claimed `salvage-payout-stable-head-refresh` after source-checking that the checked salvage skill/FSM/client-init/build-unit files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f`, release `7ff18c49` and historical salvage branches stay separated for the lowercase payout call, salvage-truck loop and client-local deletion/reward lane.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this salvage lane. The small casing fix and larger server-owned salvage authority review remain future salvage owner work; no gameplay source changed.

## 2026-06-06T22:55:00+02:00 - Codex - RequestSpecial upgrade-sync stable-head refresh
- Claimed `requestspecial-upgrade-sync-stable-head-refresh` after source-checking that the checked `Server_HandleSpecial.sqf`, `GUI_UpgradeMenu.sqf` and `Server_ProcessUpgrade.sqf` files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix), [Upgrades and research](Upgrades-And-Research-Atlas), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for the mixed `_args` / `_this` parser cleanup lane.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this upgrade-sync lane. Tuple normalization and malformed-payload smoke remain future upgrade/network owner work; no gameplay source changed.

## 2026-06-06T23:10:00+02:00 - Codex - gear template/profile stable-head refresh
- Claimed `gear-template-stable-head-refresh` after source-checking that the checked `Client_UI_Gear_AddTemplate.sqf`, `Client_UI_Gear_FillTemplates.sqf`, `Client_UI_Gear_SaveTemplateProfile.sqf` and `Init_ProfileGear.sqf` files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Gear template profile filter](Gear-Template-Profile-Filter), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for the undefined `_u_upgrade` save filter, six-field import guard and Barracks-or-Gear creation versus Gear-only display mismatch.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for these gear lanes. Save/import repair and the Barracks/Gear semantics decision remain future gear owner work; no gameplay source changed.

## 2026-06-06T23:25:00+02:00 - Codex - vehicle cargo loop stable-head refresh
- Claimed `vehicle-cargo-loop-stable-head-refresh` after source-checking that the checked `Common_EquipVehicle.sqf`, `Common_EquipBackpack.sqf` and `Client_GetVehicleContent.sqf` files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for the five inclusive cargo-application loops and perf's Chernarus-only partial rescue.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this cargo lane. Source Chernarus patch plus maintained Vanilla propagation and cargo smoke remain future gear owner work; no gameplay source changed.

## 2026-06-06T23:40:00+02:00 - Codex - ClickableText soundPush stable-head refresh
- Claimed `clickabletext-soundpush-stable-head-refresh` after source-checking that the checked `Rsc/Ressources.hpp` and `Rsc/Dialogs.hpp` files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Client UI systems](Client-UI-Systems-Atlas#clickable-text-soundpush-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [Dead/stale code](Dead-Code-And-Stale-Code-Register) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f`, release `7ff18c49` and UI theme branches stay separated for the malformed base `RscClickableText.soundPush[]` value.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this UI config lane. Base-class config repair plus representative clickable-control smoke remain future UI owner work; no gameplay source changed.

## 2026-06-06T23:55:00+02:00 - Codex - fast travel fee stable-head refresh
- Claimed `fast-travel-fee-stable-head-refresh` after source-checking that the checked `GUI_Menu_Tactical.sqf` and `Init_CommonConstants.sqf` files did not change from historical stable `2cdf5fb8` to current `origin/master` / local `master` `89ae9dad`.
- Refreshed [Client UI systems](Client-UI-Systems-Atlas#tactical-fast-travel-fee-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable `89ae9dad`, Miksuu `89ae9dad`, perf `0076040f` and release `7ff18c49` stay separated for fee-mode TODOs, hidden unaffordable destinations, marker-only fee text and local travel debit.
- Updated machine status/backlog rows to stop presenting `2cdf5fb8` as current stable evidence for this Tactical UX lane. Hide-vs-disabled/prompt policy and action-time recheck remain future UI owner work; no gameplay source changed.

## 2026-06-07T13:10:00+02:00 - Claude - DR-48 town-defense overhaul capture-persistence occupancy review
- Claimed `town-defense-overhaul-capture-persistence-occupancy-review` (autonomous archaeology lane). The `Marty_town_defense_overhaul` merge landed on stable/local `master` `89ae9dad` **after** the 2026-06-02 coverage-ledger all-green milestone (3 new files + 17 modified in Chernarus), so it was previously unreviewed source.
- Filed [Deep-review findings](Deep-Review-Findings) **DR-48** (Round 39): the new `Server/Functions/Server_CleanupExpiredTownDefenseAssets.sqf` re-introduces the DR-45 occupancy-deletion class for captured-town persistence. The OBJECT branch `:61-64` deletes `captured_mobile_vehicle`/`static_weapon` with only `isPlayer _asset`/`isPlayer leader group _asset` — occupancy-blind, and for a vehicle `group _asset` is `grpNull` so the leader guard is likely a no-op deleting even a player driver. The GROUP branch `:57-60` deletes every member with no player guard. Captured vehicles persist 600s (`server_town.sqf:240`, 60s under `WF_Debug`) and are reaped per town every town-AI loop tick (`server_town_ai.sqf:61`).
- Corroborated the occupancy primitive at source: the repo's own `Server_HandleEmptyVehicle.sqf:26-30` uses `crew`, not `group`. The recommended `crew`-based fix is correct whether or not `group <vehicle>` returns `grpNull`, so it does not depend on the open BIKI question (the `group` command BIKI page returned HTTP 403 on live fetch this pass; in-engine confirmation is a future smoke gate).
- Updated [Town-AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#dr-48--capture-persistence-cleanup-new-town-defense-overhaul), the [Codebase coverage ledger](Codebase-Coverage-Ledger) AI/headless row, [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) (`town-defense-overhaul-capture-persistence-occupancy`) and `agent-collaboration.json`. No gameplay source changed.
- Next action — Codex: confirm overhaul branch presence on `perf/quick-wins` / release in the next current-head refresh and route DR-48 from the AI/headless atlas + Feature Status as desired. Steff/code owner: apply the crew/cargo guard to both branches and smoke a player riding a captured town vehicle across persistence expiry; confirm `group <vehicle>` semantics in-engine.

## 2026-06-07T15:10:00+02:00 - Claude - Audit Findings Queue verification sweep (backlog cleared)
- Lane `audit-findings-queue-verification-sweep`. Source-checked every previously-UNVERIFIED (`⬜`) row in the [Audit Findings Queue](Audit-Findings-Queue-2026-06-03) (AI/V/SG/NJ/UX, ~48 rows) against current `master` via read-only scouts, then adversarially re-verified the high-severity promotions at source.
- **Result: the queue has no `⬜` rows left.** Verdicts recorded per-row on the queue page: ~29 REAL, 4 FALSE (V8, V9, V12, NJ6), 1 GONE/already-fixed (AI13), 8 NUANCED/design/perf, 2 split (AI14, SG9 each have a real part + a false sub-claim), and all spot-checked UX typo/hardcoded-English claims REAL.
- Filed [Deep-review findings](Deep-Review-Findings) **Round 40**: **DR-49** (side-supply underflow guard `if (_change<0) then {_change=_currentSupply-_amount}` *adds* `abs(amount)` on a deduction — economy exploit; Common + both `Server_ChangeSideSupply` handlers) and **DR-50** (`Server_OnHQKilled.sqf` double-awards HQ-kill score: unconditional `:47` + non-teamkill-guarded `:81` = 1800 on a clean kill, and 900 on a teamkill). Both added to [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).
- **Adversarial correction:** audit NJ10 ("JIP HQ killed-EH → victory may not fire", flagged high) is **not** a victory-blocker — the authoritative HQ-killed EH is server-local (`Init_Server.sqf:323`, `Construction_HQSite.sqf:89` "Killed EH fires localy, this is the server", `Server_MHQRepair.sqf:37`); the client EH at `Init_Client.sqf:515` is a redundant relay. Recorded so it is not re-opened as critical. SG1 re-confirms DR-11/DR-13; SG14 maps to DR-30.
- Cited DR-49 in the economy ledger row and DR-50 in the victory ledger row. No gameplay source changed.
- Next action — Codex: optionally promote DR-49/DR-50 into Feature Status / Source-Fix-Propagation-Queue and route the localization-cleanup lane (UX). Steff/code owner: DR-49 and DR-50 are clean, low-LOC server-side fixes with smoke steps in the hardening backlog.

## 2026-06-07T16:00:00+02:00 - Claude - Debloat: archive worklog history

- Goal `get rid of all bloat`. The live worklog had grown to 3642 lines / 539 entries (~15% of the wiki by line count) — the single largest bloat surface — with mixed newest-first/appended ordering.
- Split it: this live page now keeps only recent entries (2026-06-06 onward, 82 entries) plus a Future-Agents/Continue-Reading frame; the full 2026-06-01→06-06 history (448 dated entries + old VERIFICATION/ROUND audit entries) is preserved **verbatim** in [Agent worklog archive](Agent-Worklog-Archive). No evidence deleted; entry order unchanged in both pages.
- Logged in [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger). **Sync note for Codex:** new page `Agent-Worklog-Archive.md` is linked from this page's intro/footer; add it to `_Sidebar.md` / [Navigation inventory](Navigation-Inventory-And-Page-Status) archive routing at your discretion (Codex nav lane). No gameplay source changed.

## 2026-06-07T16:30:00+02:00 - Claude - Debloat: condense three stale planning/audit pages

- Goal `get rid of all bloat`. Condensed [Documentation implementation plan](Documentation-Implementation-Plan) (135→34, workstreams done → status table routing to owners), [Wiki quality audit](Wiki-Quality-Audit) (89→21, all items Codex-resolved → archival gateway; kept both false-positive corrections, also in [Instructions for Codex](Instructions-For-Codex#false-positives-to-preserve)) and [Knowledge platform roadmap](Knowledge-Platform-Roadmap) (80→55, trimmed opinion prose; kept recommendation/target-shape/debt-table/migration/authoring rules). ~190 lines removed; all internal links re-checked.
- Logged in [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) with a Codex handoff for remaining lower-priority bloat (mirror-reconciliation historical inventory, supply-scan-narrowing matrix restatement, HC delegation-table duplication across 4 pages). No gameplay source changed.

## 2026-06-07T17:15:00+02:00 - Claude - Debloat: remaining Codex-handoff items

- Goal `get rid of all bloat`, second pass closing the items previously handed to Codex. Condensed [Wiki mirror reconciliation plan](Wiki-Mirror-Reconciliation-Plan) (115→57, removed the dead `_wasp_wiki_claude` inventory; parity is `full-diffCount=0`), [AI assistant guide](AI-Assistant-Guide) (56→26, boot-order routing → entry-pack pointer, kept guardrails) and [AI assistant developer guide](AI-Assistant-Developer-Guide) (66→61, boot list → pointer; kept all unique edit rules/pitfalls/checklists/search patterns); lightly trimmed [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) (101→99, restated matrix only). ~95 lines removed; links re-checked.
- **Source-grounded non-action:** the HC delegation-mode `0/1/2` reference across the four AI/HC pages was checked at source and **kept** — each copy is small and wrapped in unique evidence, the pages already cross-link, and removing it would force click-throughs for ~10 lines while damaging four atlas pages (intentional orientation, not bloat). Recorded in the [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger).
- Net debloat this session: live worklog 3642→515 + archive; ~290 lines from seven planning/audit/onboarding/mirror pages. No gameplay source changed.

## Future Agents

- Add dated entries at the bottom before and after substantial documentation or code changes.
- Older history (2026-06-01 → 06-06) lives in [Agent worklog archive](Agent-Worklog-Archive). Do not assume visible order is strictly timestamp-sorted; trust explicit timestamps plus current-state pages ([Progress dashboard](Progress-Dashboard), [Current source status snapshot](Current-Source-Status-Snapshot), [`agent-status.json`](agent-status.json)).

## Continue Reading

Previous: [Agent collaboration protocol](Agent-Collaboration-Protocol) | Next: [Deep-review findings](Deep-Review-Findings)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

## 2026-06-07T18:30:00+02:00 - Claude - Agent team clears coverage-gap backlog (DR-51..DR-54)

- Goal `use an agent team to clear all backlog`. Ran a 5-subsystem Workflow (35 agents incl. adversarial verifiers, ~1.4M tokens) over the Round-36 coverage-gap weakly-understood systems — the last open documentation backlog.
- Filed [Deep-review findings](Deep-Review-Findings#round-41--agent-team-clearance-of-the-coverage-gap-backlog--dr-51dr-54) **Round 41**: **DR-51** (both server AI-respawn paths orphaned/uncalled → AI leaders never respawn), **DR-52** (support specials Paratroops/ParaVehi/ParaAmmo/UAV have no server authority + accept a client-supplied group handle — extends the client-authoritative class), **DR-53** (PR#1 supply-heli economy: client-forgeable SupplyAmount + non-cash double-reward, branch `feat/supply-helicopter`), **DR-54** (Core_US/USMC dedup guard broken + AH64D_EP1 faction mislabel).
- Routed dead code (AI_TLWPHandler.sqs, groupsMonitor.sqf, nil `Spawn UpdateSupplyTruck`) to [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and **corrected a stale false-positive note** there that claimed the non-vanilla AI respawn path was live. Folded the full config data-model map into [Assets/config atlas](Assets-Config-Localization-And-Parameters-Atlas). Updated the [coverage ledger](Codebase-Coverage-Ledger) AI/headless + Modules rows and added DR-51..DR-54 to [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).
- **Corrections preserved:** the long-suspected PR#1 stacked `Killed` EH is **refuted** (the `isNil` guard works; real residual is a double cooldown timer); the interdiction `Killed` EH is server-routed via `publicVariableServer` (not a client-authority hole). Marked the Round-36 coverage-gap list **cleared**. No gameplay source changed.
- Next action — Steff/code owner: DR-52 and DR-53 are P1 authority/economy fixes; DR-51/DR-54 are P2/P3. Codex: optionally promote DR-51..54 into Feature Status / Source-Fix-Propagation-Queue.

## 2026-06-07T20:30:00+02:00 - Claude - Deeper hazard-class sweep (68-agent team) -> DR-55..DR-57

- Goal: even-deeper agent-team pass. 7 whole-tree hazard-class sweepers + adversarial verifiers (68 agents, ~2.9M tokens), deduped vs DR-1..54.
- **DR-55 (CRITICAL, systemic):** the PVF/PVEH/direct-publicVariable handler surface lacks server-side sender authentication — `Server_HandlePVF.sqf:14` and `Init_PublicVariables.sqf:50` never forward the sender, so ~18 newly-enumerated handlers are client-forgeable (RequestVehicleLock, RequestChangeScore, RequestMHQRepair, RequestNewCommander direct-assign, RequestTeamUpdate, ATTACK_WAVE_DETAILS, WFBE_Server_PV_SupplyMissionCompleted, and RequestSpecial RespawnST/repair-camp/upgrade-sync/connected-hc/update-clientfps/update-town-delegation/update-teamleader, plus the Action_RepairMHQDepot client town-SV drain). Generalizes DR-1/27/41/44/52/53 to the whole surface; full table in [Deep-review findings](Deep-Review-Findings#round-42--deeper-hazard-class-sweep-68-agent-team--dr-55dr-57).
- **DR-56 (HIGH):** `ARTY_HandleSADARM.sqf` infinite `while{true}` thread leak per air-kill + per-frame `setVelocity` busy-wait. **DR-57 (HIGH):** town patrols never spawn (`server_town_ai.sqf:67-68` resets the patrol timer every cycle).
- Routed minor (PLAYER_RADIATED perf, playerObjectsList double-PVEH, skillDiffCompensation no-gameover guard, monitorServerFPS dead orphan, Action_RepairMHQDepot `supplyvalue` casing, Client_BuildUnit dup HandleReload). Confirmed **still-unpatched on master**: SG4, SG5, SG9, AI1, AI2, V2 (PR#8/release-only fixes). Sharpened DR-7..10 (AntiStack `call compile` on `callExtension` output) and DR-46 (SEND_MESSAGE receiver `call compile`).
- Added DR-55/56/57 to [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and the coverage ledger. No gameplay source changed.
- Next action — Steff/code owner: DR-55 is the P0 — a single authentication change at the dispatcher plus per-handler side/role/funds re-derivation closes the whole forgery surface. Codex: cross-link DR-55 from Public-Variable-Channel-Index / Server-Authority-Migration-Map / Networking (atlas lane).

## 2026-06-07T22:30:00+02:00 - Claude - Wiki-maintenance megapass (71-agent team)

- Goal: large multi-agent wiki pass (dead code, doc improvement, LLM/token optimisation, resolved issues, low-relevancy condensation, unnecessary-document hunt). 9 read-only analysis lanes + adversarial verifiers (71 agents, ~3.5M tokens).
- **Dead code (headline):** added a 2026-06-07 deep dead-code-sweep section to [Dead/stale code register](Dead-Code-And-Stale-Code-Register) — ~18 newly-confirmed unreachable files (never-compiled helpers, compiled-but-never-called globals, commented-compile-intact), plus two ⚠️ flagged AI-commander functions (`Server_AI_Com_Upgrade`, `Server_AI_SetTownAttackPath`) that are uncalled — consistent with the dormant AI-commander FSM (DR-14/DR-15 note), so the AI-commander upgrade/attack-path audit analysis describes dormant code (owner verification flagged).
- **Resolved issue (the one genuine fix found):** **DR-15 is fixed on master** — `Server_AssignNewCommander.sqf:4` now reads `_side = _this select 0;`. Marked resolved in [Deep-review findings](Deep-Review-Findings), [Instructions for Codex](Instructions-For-Codex#false-positives-to-preserve) and [Feature status](Feature-Status-Register); only the redundant `new-commander-assigned` broadcast remains. The resolved-issue sweep otherwise confirmed DR-1..14, DR-16..57 all remain open on master (no false "resolved" claims).
- **Doc improvement:** added Feature-Status rows for DR-55 (systemic, P0), DR-49/50/52/53/56/57, and the DR-15 resolution. Fixed a broken `[Home](Home.md)` link.
- **Deliberately NOT done (handed to Codex / flagged):** the link-lane `--`→`-` anchor reformats target the **MkDocs** slugger — on the live GitHub wiki em-dash headings legitimately produce `--`, so "fixing" them would break working links (mirror/nav lane). The MASH-undeploy path "fix" was a false positive (pages already cite the correct path). Two empty Miksuu archive stubs (`Miksuu-Wiki-Archive-Home`, `Miksuu-Wiki-Archive-Discord-Bot`) are removable but are MkDocs-nav pages (Codex nav lane). Per-page token condensations of standalone pages remain a bounded follow-up.
- No gameplay source changed.

## 2026-06-08T00:15:00+02:00 - Claude - Wiki-maintenance pass 2 (additive; partial — high verifier-failure rate)

- Second multi-agent maintenance pass (5 lanes / 38 agents). Many verifiers failed to emit structured output this run, so I applied only solidly-verified-safe results and authored the high-value doc item myself.
- **Applied:** (1) [Dead/stale code register](Dead-Code-And-Stale-Code-Register) — added `Client/Module/MASH/receiverMASHmarker.sqf` (dead client MASH receiver, compile commented at `Init_Client.sqf:132`; the client end of DR-34's broken chain) and formalized `Server/Module/serverFPS/monitorServerFPS.sqf` (no-op duplicate; `WFBE_VAR_SERVER_FPS` has no reader, RHUD uses `SERVER_FPS_GUI`). (2) Authored a **Town Patrol Mechanic** section on [Towns/camps/capture](Towns-Camps-And-Capture-Atlas) — the feature had no mechanic write-up; it now explains the roaming-capture flow and corrects the page with **DR-57** (never spawns) + **AI6** (SV==60) alongside the pre-existing AI1 lifecycle note.
- **Rejected (prior verified decision):** the `UI-HUD-And-Dialogs` and `Agent-Development-Pack` "merge" recommendations — both are **intentional compatibility aliases** kept on purpose; not merging.
- **Handed to Codex / unverified:** `Miksuu-Wiki-Archive-Discord-Bot` empty-stub delete (MkDocs-nav lane); ~25 candidate dead `STR_*` keys + a dup-IDD (verifiers failed → owner confirm before acting); the apply-ready condense lane and most doc-gap proposals did not pass verification this run.
- No gameplay source changed.

## 2026-06-13T16:46:44+02:00 - Codex - Attack wave authority branch route

- Claimed `attack-wave-authority-branch-route` from the DR-41 hardening backlog as a docs-only lane.
- Source-checked current docs/source `HEAD` `f3e157f2`, stable `origin/master` `cf2a6d6a`, Miksuu upstream `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2`, `origin/feat/ai-commander` `c20ce153` and historical `upstream/AttackWave` `994150da`.
- Result: every checked Chernarus and maintained Vanilla root keeps the direct `ATTACK_WAVE_INIT` `_supply` / `_side` trust in `Server_AttackWave.sqf` plus trusted `ATTACK_WAVE_DETAILS` handling/debit in `AttackWave.sqf`; no branch rescue was found.
- Added the canonical branch/root matrix to [Attack-wave authority playbook](Attack-Wave-Authority-Playbook#branch--root-matrix) and condensed [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), dashboard and machine records. No gameplay source changed.

## 2026-06-13T18:20:00+02:00 - Codex - PVF sender authentication route

- Claimed `pvf-sender-authentication-route` from Claude's DR-55 handoff as a docs-only cross-link lane.
- Source-checked current `origin/master` `cf2a6d6a`: `Common/Init/Init_PublicVariables.sqf:51-53` registers server PVF handlers with `(_this select 1) Spawn WFBE_SE_FNC_HandlePVF`, and `Server/Functions/Server_HandlePVF.sqf:9-14` only unpacks `_script` plus `_parameters` before spawning the target handler.
- Result: the existing DR-1/DR-38 handler-name allowlist patch remains necessary, but it is not sufficient for DR-55. Legitimate handlers still need authenticated requester context and per-handler side/role/funds/object re-derivation.
- Routed this distinction through [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) and [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook#sender-authentication-boundary). No gameplay source changed.

## 2026-06-13T18:09:15+02:00 - Codex - Patrols v2 current-master route

- Claimed `patrols-v2-current-master-route` after `git fetch --all --prune` and a fast-forward to current `origin/master` `cf2a6d6a` showed stale patrol docs still described `89ae9dad` as current master.
- Source-checked current Chernarus and maintained Vanilla: `server_town_ai.sqf:44,220` retires the old town-based patrol gate, `server_side_patrols.sqf:24-58` drives the side-upgrade patrol dispatcher, `Common_RunSidePatrol.sqf:53-83` runs the patrol lifecycle, `Server_HandleSpecial.sqf:215-242` maintains side slots / `WFBE_ACTIVE_PATROLS`, `Client/FSM/updatepatrolmarkers.sqf:18-58` renders friendly patrol markers, and `server_patrols.sqf:26` now uses `&&` in both roots.
- Result: old DR-57 / AI1 "town patrols dead on current master" wording is now historical for `89ae9dad`-era branches. Current master has Patrols v2 source in both maintained roots, but still needs Arma smoke for upgrade levels 1/2/3, HC `delegate-sidepatrol`, friendly marker audience, patrol death, side-slot/cooldown release and Buy Units/RHUD AI-cap text.
- Updated [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Gameplay systems](Gameplay-Systems-Atlas), [Headless client scaling](Headless-Client-Scaling-And-Topology), [Current source status snapshot](Current-Source-Status-Snapshot), dashboard/status files and machine rows. No gameplay source changed.

## 2026-06-13T18:38:05+02:00 - Codex - P0 network current-master route

- Claimed `p0-network-current-master-route` as a docs-only refresh after current `origin/master` advanced to `cf2a6d6a`, Miksuu upstream to `b8389e74` and release to `a96fdda2`.
- Source-checked PVF dispatcher lookup across current master, Miksuu, perf and release in Chernarus plus maintained Vanilla: all checked roots still run `_parameters Spawn (Call Compile _script)` in `Server_HandlePVF.sqf:14`; current master/release clients run it at `Client_HandlePVF.sqf:32` after the HC filter, while Miksuu/perf clients keep `:22`.
- Source-checked direct `SEND_MESSAGE`: all checked refs/roots still register the direct PVEH at `Client/FSM/updateclient.sqf:12`, compile payload text at `Client_onEventHandler_SEND_MESSAGE.sqf:27`, and repeat helper compile/broadcast at `Common_SendMessage.sqf:26,38`. The `89ae9dad..cf2a6d6a` diff changes `updateclient.sqf` context but does not touch the receiver/helper compile files.
- Updated [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook#current-branch-matrix), [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix), [Networking and public variables](Networking-And-Public-Variables), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), dashboard/status files and machine rows. No gameplay source changed.

## 2026-06-13T21:01:34+02:00 - Codex - Coordination dashboard hygiene audit

- Claimed `coordination-dashboard-hygiene-audit` as a coordination-only maintenance lane for dashboard compactness, machine-file validity, active-claim sanity and wiki/docs mirror parity. No gameplay source edits planned.
- Validated [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json) and [`agent-events.jsonl`](agent-events.jsonl); all parsed cleanly. `agent-events.jsonl` had 1004 lines before this audit's append-only events.
- Checked the live active-claim set in [`agent-collaboration.json`](agent-collaboration.json): the only true active owner lane remains `documentation-finisher-loop`; Claude is `autonomous-ready`; the rest are watchlist, code-owner, smoke-pending or future-owner lanes. No conflicting active claim needed reassignment.
- Confirmed [Progress dashboard](Progress-Dashboard) Latest Batch already had five rows before this refresh, then added this audit as the newest row and trimmed the oldest row to keep the compact five-row rule. Verified docs/wiki and wiki-checkout parity for the coordination files before editing. No gameplay source changed.

## 2026-06-13T21:00:25+02:00 - Codex - Clickable text soundPush current-master refresh

- Claimed `clickabletext-soundpush-current-master-refresh` as a docs-only patch-ready queue refresh after current branch heads moved beyond the existing `89ae9dad` / `7ff18c49` matrix.
- Source-checked docs/source `HEAD` `f7bc72a8`, current `origin/master` `cf2a6d6a`, Miksuu `upstream/master` `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and UI theme branches `0767c0b5` / `87d86257`.
- Result: every checked Chernarus and maintained Vanilla root still keeps `class RscClickableText` at `Rsc/Ressources.hpp:541`, malformed `soundPush[] = {, 0.2, 1};` at `:556`, and valid empty-sound precedent `{"", 0.2, 1}` at `:92`. Current `origin/master` and release now have 14 derived `RscClickableText` controls per maintained root; docs/source, upstream, perf and UI theme branches have 17.
- Updated [Client UI systems](Client-UI-Systems-Atlas#clickable-text-soundpush-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Dead/stale code register](Dead-Code-And-Stale-Code-Register), dashboard/status files and machine rows. No gameplay source changed.
