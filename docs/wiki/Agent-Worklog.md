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
- Updated [Function and module index](Function-And-Module-Index#server-function-families), [AI, headless and performance](AI-Headless-And-Performance#commander-team-order-variables), [Server gameplay runtime](Server-Gameplay-Runtime-Atlas#runtime-loops), [SQF code atlas](SQF-Code-Atlas), the dashboard and machine records. No gameplay source changed.

## 2026-06-06T13:58:33+02:00 - Codex - Release 7ff18c49 PR8 delta route

- Claimed `release-7ff18c49-pr8-delta-route` after the release branch moved from the previously documented `7195b331` intermediate to current `origin/release/2026-06-feature-bundle` head `7ff18c49`. No gameplay source edits planned.
- Source-checked the `7195b331..7ff18c49` diff: it touches 16 files, with matching Chernarus and maintained Vanilla changes for delegated AI fallback/locality guards (`Client_DelegateAIStaticDefence.sqf:27`, `Client_DelegateTownAI.sqf:27`, `Common_CreateUnit.sqf:34-36`, `Common_CreateUnitForStaticDefence.sqf:68-69`) and cleaner/restorer startup hardening (`crater_cleaner.sqf:5,7,50`, `droppeditems_cleaner.sqf:5,7,46`, `ruins_cleaner.sqf:5,7,30`, `buildings_restorer.sqf:4,6,18,31`).
- Result: prior propagated-fix conclusions from `7195b331` carry forward at `7ff18c49`; the new delta is release-branch evidence only. It does not close DR-42 static-defense update-back/failover because update-back/failover work remains absent and still needs explicit design plus smoke.
- Updated [PR cleanup lab](PR-Cleanup-And-Integration-Lab#pr-8-head-refresh-a96fdda2), [Current source snapshot](Current-Source-Status-Snapshot), [Feature status](Feature-Status-Register), [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook), [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue), the dashboard, pruning ledger and machine records. No gameplay source changed.

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
- Added a compact canonical caveat to [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#parameter-cache-flow) and a short route from [Feature status](Feature-Status-Register). No gameplay source changed.

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
- Updated [Town-AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#historical-dr-48-capture-persistence-cleanup), the [Codebase coverage ledger](Codebase-Coverage-Ledger) AI/headless row, [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) (`town-defense-overhaul-capture-persistence-occupancy`) and `agent-collaboration.json`. No gameplay source changed.
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
- Filed [Deep-review findings](Deep-Review-Findings#round-41--agent-team-clearance-of-the-coverage-gap-backlog--dr-51dr-54-claude-2026-06-07) **Round 41**: **DR-51** (both server AI-respawn paths orphaned/uncalled → AI leaders never respawn), **DR-52** (support specials Paratroops/ParaVehi/ParaAmmo/UAV have no server authority + accept a client-supplied group handle — extends the client-authoritative class), **DR-53** (PR#1 supply-heli economy: client-forgeable SupplyAmount + non-cash double-reward, branch `feat/supply-helicopter`), **DR-54** (Core_US/USMC dedup guard broken + AH64D_EP1 faction mislabel).
- Routed dead code (AI_TLWPHandler.sqs, groupsMonitor.sqf, nil `Spawn UpdateSupplyTruck`) to [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and **corrected a stale false-positive note** there that claimed the non-vanilla AI respawn path was live. Folded the full config data-model map into [Assets/config atlas](Assets-Config-Localization-And-Parameters-Atlas). Updated the [coverage ledger](Codebase-Coverage-Ledger) AI/headless + Modules rows and added DR-51..DR-54 to [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).
- **Corrections preserved:** the long-suspected PR#1 stacked `Killed` EH is **refuted** (the `isNil` guard works; real residual is a double cooldown timer); the interdiction `Killed` EH is server-routed via `publicVariableServer` (not a client-authority hole). Marked the Round-36 coverage-gap list **cleared**. No gameplay source changed.
- Next action — Steff/code owner: DR-52 and DR-53 are P1 authority/economy fixes; DR-51/DR-54 are P2/P3. Codex: optionally promote DR-51..54 into Feature Status / Source-Fix-Propagation-Queue.

## 2026-06-07T20:30:00+02:00 - Claude - Deeper hazard-class sweep (68-agent team) -> DR-55..DR-57

- Goal: even-deeper agent-team pass. 7 whole-tree hazard-class sweepers + adversarial verifiers (68 agents, ~2.9M tokens), deduped vs DR-1..54.
- **DR-55 (CRITICAL, systemic):** the PVF/PVEH/direct-publicVariable handler surface lacks server-side sender authentication — `Server_HandlePVF.sqf:14` and `Init_PublicVariables.sqf:50` never forward the sender, so ~18 newly-enumerated handlers are client-forgeable (RequestVehicleLock, RequestChangeScore, RequestMHQRepair, RequestNewCommander direct-assign, RequestTeamUpdate, ATTACK_WAVE_DETAILS, WFBE_Server_PV_SupplyMissionCompleted, and RequestSpecial RespawnST/repair-camp/upgrade-sync/connected-hc/update-clientfps/update-town-delegation/update-teamleader, plus the Action_RepairMHQDepot client town-SV drain). Generalizes DR-1/27/41/44/52/53 to the whole surface; full table in [Deep-review findings](Deep-Review-Findings#round-42--deeper-hazard-class-sweep-68-agent-team--dr-55dr-57--systemic-authority-result-claude-2026-06-07).
- **DR-56 (HIGH):** `ARTY_HandleSADARM.sqf` infinite `while{true}` thread leak per air-kill + per-frame `setVelocity` busy-wait. **DR-57 (HIGH):** town patrols never spawn (`server_town_ai.sqf:67-68` resets the patrol timer every cycle).
- Routed minor (PLAYER_RADIATED perf, playerObjectsList double-PVEH, skillDiffCompensation no-gameover guard, monitorServerFPS dead orphan, Action_RepairMHQDepot `supplyvalue` casing, Client_BuildUnit dup HandleReload). Confirmed **still-unpatched on master**: SG4, SG5, SG9, AI1, AI2, V2 (PR#8/release-only fixes). Sharpened DR-7..10 (AntiStack `call compile` on `callExtension` output) and DR-46 (SEND_MESSAGE receiver `call compile`).
- Added DR-55/56/57 to [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and the coverage ledger. No gameplay source changed.
- Next action — Steff/code owner: DR-55 is the P0 — a single authentication change at the dispatcher plus per-handler side/role/funds re-derivation closes the whole forgery surface. Codex: cross-link DR-55 from Public-Variable-Channel-Index / Server-Authority-Migration-Map / Networking (atlas lane).

## 2026-06-07T22:30:00+02:00 - Claude - Wiki-maintenance megapass (71-agent team)

- Goal: large multi-agent wiki pass (dead code, doc improvement, LLM/token optimisation, resolved issues, low-relevancy condensation, unnecessary-document hunt). 9 read-only analysis lanes + adversarial verifiers (71 agents, ~3.5M tokens).
- **Dead code (headline):** added a 2026-06-07 deep dead-code-sweep section to [Dead/stale code register](Dead-Code-And-Stale-Code-Register) — ~18 newly-confirmed unreachable files (never-compiled helpers, compiled-but-never-called globals, commented-compile-intact), plus two ⚠️ flagged AI-commander functions (`Server_AI_Com_Upgrade`, `Server_AI_SetTownAttackPath`) that are uncalled — consistent with the dormant AI-commander FSM (DR-14/DR-15 note), so the AI-commander upgrade/attack-path audit analysis describes dormant code (owner verification flagged).
- **Resolved issue (the one genuine fix found):** **DR-15 is fixed on master** — `Server_AssignNewCommander.sqf:4` now reads `_side = _this select 0;`. Marked resolved in [Deep-review findings](Deep-Review-Findings), [Instructions for Codex](Instructions-For-Codex#false-positives-to-preserve) and [Feature status](Feature-Status-Register); only the redundant `new-commander-assigned` broadcast remains. The resolved-issue sweep otherwise confirmed DR-1..14, DR-16..57 all remain open on master (no false "resolved" claims).
- **Doc improvement:** added Feature-Status rows for DR-55 (systemic, P0), DR-49/50/52/53/56/57, and the DR-15 resolution. Fixed a broken `[Home](Home)` link.
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
## 2026-06-13T21:01:43+02:00 - Codex - AI supply-truck current-master safe-disable route

- Claimed `ai-supply-truck-current-master-safe-disable-route` after `origin/master` `cf2a6d6a` showed the old AI supply-truck nil-code/FSM trap had changed from current-source raw spawn to current-source warning/disable.
- Source-checked current Chernarus and maintained Vanilla: `Server/Init/Init_Server.sqf:37` still comments out `UpdateSupplyTruck`, `:383-384` initializes `wfbe_ai_supplytrucks` and logs that legacy AI supply-truck logistics are disabled, and `Server/AI/AI_UpdateSupplyTruck.sqf:17` still references missing `Server\FSM\supplytruck.fsm`.
- Branch result: release `a96fdda2` matches current master in both maintained roots; Miksuu upstream `b8389e74` and `origin/perf/quick-wins` `0076040f` still raw-spawn the missing worker; `origin/feat/ai-commander` `c20ce153` guards only Chernarus while Vanilla remains raw.
- Updated [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix), [Support specials](Support-Specials-And-Tactical-Modules-Atlas), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Dead/stale code](Dead-Code-And-Stale-Code-Register), dashboard/status files and machine rows. No gameplay source changed.

## 2026-06-13T21:04:23+02:00 - Codex - HQ kill score double-award branch route

- Claimed `hq-kill-score-double-award-branch-route` from the weak DR-50 Feature Status catch-all row as a docs-only branch/root matrix.
- Source-checked current source Chernarus and maintained Vanilla, stable `origin/master` `cf2a6d6a`, Miksuu upstream `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2`, and historical upstream score branches `ScoreForKillingFactories` `f17445c1` / `Fix0ScoreBountyBug` `415615c9`.
- Result: all current maintained refs keep the two-award HQ-kill shape. Current/release roots set `_points = 30000 / 100 * WFBE_C_BUILDINGS_SCORE_COEF` at `Server_OnHQKilled.sqf:23`, award it at `:52`, then award `_score = 900` again for non-teamkills at `:80-86`; Miksuu/perf keep the same shape at `:23,47,75,78,81`. The coefficient remains `3`, so enemy HQ kills pay `1800` and friendly/teamkill HQ kills still pay the unconditional `900`.
- Added the canonical matrix to [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas#hq-kill-score-and-bounty-branch-matrix), split DR-50 into its own [Feature status](Feature-Status-Register) row and added the patch-ready [Source fix propagation queue](Source-Fix-Propagation-Queue) route. No gameplay source changed.

## 2026-06-13T21:12:00+02:00 - Codex - Client UI atlas owner route prune

- Claimed `client-ui-atlas-owner-route-prune` as a docs-only architecture/atlas pass, with no gameplay source edits.
- Synced live wiki-only deltas for [Client UI systems](Client-UI-Systems-Atlas) and [SQF code atlas](SQF-Code-Atlas) into `docs/wiki`, including the client modal loop cadence, indicator surface matrix and server AI order-helper route.
- Source-checked UI branch heads across `origin/master` `cf2a6d6a`, Miksuu upstream `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2`: current/release Chernarus and Vanilla send Objective Ping `SetTask` at `Client/GUI/GUI_Menu_Command.sqf:336,344`, Miksuu still comments the sends, old town `TaskSystem` remains commented, fast-travel fee mode remains local/hide-then-debit, and `Rsc/Ressources.hpp:556` still has malformed `RscClickableText.soundPush[]` in all checked roots.
- Added a top owner-route table to [Client UI systems](Client-UI-Systems-Atlas), condensed the broad UI risk section into canonical owner links, refreshed fast-travel/clickable-text matrices to current branch heads and kept existing incoming anchors intact. No gameplay source changed.

## 2026-06-13T21:42:00+02:00 - Codex - Architecture overview owner route prune

- Claimed `architecture-overview-owner-route-prune` as a docs-only architecture gateway pass, with no gameplay source edits.
- Source-checked the bootstrap and owner anchors in the source mission: `description.ext:39-58`, `initJIPCompatible.sqf:121-123,214-238`, `Common/Init/Init_Common.sqf:273-308,369-371`, `Server/Init/Init_Server.sqf:355-386,507-538,577-620`, `Client/Init/Init_Client.sqf:360-388,459-509,773-789`, and `Headless/Init/Init_HC.sqf:11-15`.
- Source-checked propagation/tooling anchors: `Tools/LoadoutManager/FileManagement/FileManager.cs:176-188`, `SqfFileGenerator.cs:128-132`, and `ZipManager.cs:16,96`. Because root discovery is branch-sensitive, [Architecture overview](Architecture-Overview) now routes the branch matrix back to [Tools and build workflow](Tools-And-Build-Workflow).
- Refreshed [Architecture overview](Architecture-Overview) as a lean gateway: added a top routing table, replaced repeated init/data-flow prose with compact runtime owner and bootstrap maps, and kept detailed branch matrices/smoke gates on owner pages. No gameplay source changed.

## 2026-06-13T21:48:39+02:00 - Codex - SQF atlas compile registry refresh

- Claimed `sqf-atlas-compile-registry-refresh` as a docs-only architecture/atlas pass, with no gameplay source edits.
- Recounted the current docs/source checkout `docs/developer-wiki-index` at `04a60e43` against `Missions/[55-2hc]warfarev2_073v48co.chernarus` with `Select-String -SimpleMatch 'preprocessFile'` over all `.sqf` files.
- Result: 738 total compile references, 460 `preprocessFileLineNumbers`, 278 plain `preprocessFile`, 22 commented references; target areas are root/bootstrap 7, `Common` 492, `Client` 142, `Server` 92, `Headless` 4 and `WASP` 1. Top registrars remain `Init_Common.sqf` 196, `Init_Client.sqf` 111 and `Init_Server.sqf` 90.
- Refreshed [SQF code atlas](SQF-Code-Atlas) with a top "How To Use This Atlas" routing table, updated the compile-registry snapshot, and added a branch-local caveat because `origin/master` `cf2a6d6a` has mission-source drift from this docs checkout. No gameplay source changed.

## 2026-06-13T21:58:58+02:00 - Codex - Server runtime branch-scope route

- Claimed `server-runtime-branch-scope-route` as a docs-only server runtime atlas pass, with no gameplay source edits.
- Source-checked docs checkout `docs/developer-wiki-index` `6afcc58e` and stable `origin/master` `cf2a6d6a` server startup anchors. Docs checkout `Init_Server.sqf:36,383` comments the `UpdateSupplyTruck` compile but still raw-spawns it under the AI-commander/supply-system gate; `origin/master` `Init_Server.sqf:37,383-384` initializes `wfbe_ai_supplytrucks` and warning-disables legacy logistics instead.
- Source-checked Patrols v2 and FPS publisher drift: docs checkout has no `Server/FSM/server_side_patrols.sqf`, while `origin/master` starts it at `Init_Server.sqf:533` and the driver waits at `server_side_patrols.sqf:16`, runs from `:24`, dispatches HC at `:54` or local runner at `:56`. Docs checkout starts both `serverFpsGUI.sqf` and `monitorServerFPS.sqf` at `Init_Server.sqf:578,595`; `origin/master` starts only `serverFpsGUI.sqf` at `:580` and records the redundant publisher removal at `:596-598`.
- Refreshed [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) with a top routing table, branch-scope table and runtime-risk rows, and updated [Server runtime and operations](Server-Runtime-And-Operations) so broad server prompts route to the branch-scope section before citing line anchors. No gameplay source changed.

## 2026-06-13T22:07:39+02:00 - Codex - Networking public-variable route prune

- Claimed `networking-public-variable-route-prune` as a docs-only networking atlas pass, with no gameplay source edits.
- Source-checked current stable network anchors on `origin/master` `cf2a6d6a`: PVF registration still wires client/server PVEHs at `Common/Init/Init_PublicVariables.sqf:48,53`; generic dispatch still runs `Spawn (Call Compile _script)` at `Server/Functions/Server_HandlePVF.sqf:14` and `Client/Functions/Client_HandlePVF.sqf:32`.
- Source-checked the direct `SEND_MESSAGE` path on the same ref: `Client/FSM/updateclient.sqf:12` registers the PVEH, `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf:27` compiles payload text on receivers, and `Common/Functions/Common_SendMessage.sqf:26,38` keeps the helper compile/broadcast path.
- Refreshed [Networking and public variables](Networking-And-Public-Variables) with a top routing table and branch-scope anchors, and marked the PVF command list as orientation only. Full channel inventory stays on [Public variable channel index](Public-Variable-Channel-Index), dispatcher branch status on [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), and per-handler authority on [Server authority migration map](Server-Authority-Migration-Map). No gameplay source changed.

## 2026-06-13T22:17:09+02:00 - Codex - Support specials route and upgrade-sync refresh

- Claimed `support-specials-route-upgrade-sync-refresh` as a docs-only support/tactical atlas pass, with no gameplay source edits.
- Source-checked `upgrade-sync` on docs checkout `295cc9d5`: Chernarus and maintained Vanilla keep mixed `_args` / `_this` reads at `Server_HandleSpecial.sqf:67-73`, send the client timer sync at `GUI_UpgradeMenu.sqf:171`, and store/wait/release the sync variable at `Server_ProcessUpgrade.sqf:26,29,35`.
- Source-checked current branch heads: stable `origin/master` `cf2a6d6a` shifts the caller to `GUI_UpgradeMenu.sqf:268`; Miksuu `b8389e74` and `perf/quick-wins` `0076040f` keep `:241`; release `a96fdda2` keeps `:254`. All checked roots still keep the same mixed parser at `Server_HandleSpecial.sqf:67-73`; no branch rescue was found.
- Refreshed [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas) with a top route table, branch-scope note and current-head `upgrade-sync` matrix. Deep authority remains routed to [Server authority migration map](Server-Authority-Migration-Map), [ICBM authority](ICBM-Authority-Playbook), [Service menu affordability guards](Service-Menu-Affordability-Guards) and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook). No gameplay source changed.

## 2026-06-13T22:24:55+02:00 - Codex - Source-fix queue branch-scope refresh

- Claimed `source-fix-queue-branch-scope-refresh` as a docs-only propagation-queue hygiene pass, with no gameplay source edits.
- Source-checked LoadoutManager root discovery across docs checkout `56d2f856`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f` and release `a96fdda2`. Docs checkout, stable and release now accept repo-shaped roots; Miksuu/perf still require an ancestor named `a2waspwarfare`.
- Source-checked propagated-fix branch scope in Chernarus and maintained Vanilla. Docs checkout `56d2f856` carries paratrooper registration, single `Skill_Init`, two guarded FPS publishers, typed supply scan, player-list indexing and commander-team ARTY gunner handoff. Stable `cf2a6d6a` and release `a96fdda2` carry the same families but use one guarded FPS publisher, heli-aware supply scan and marker-based commander ARTY discovery.
- Refreshed [Source fix propagation queue](Source-Fix-Propagation-Queue) with a top current-branch scope table, updated root-discovery facts, corrected the propagated supply/commander ARTY rows and added a guard that older patch-ready queue rows preserve lane-specific checked refs until their owner pages are refreshed. No gameplay source changed.

## 2026-06-13T22:41:09+02:00 - Codex - Economy atlas branch-scope route

- Claimed `economy-atlas-branch-scope-route` as a docs-only economy/atlas gateway pass, with no gameplay source edits.
- Source-checked resource income, supply mission reward flow, AI commander upgrade debit and side-supply clamp/reason status across docs checkout `6d05cb5a`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots.
- Confirmed the resource-income cap/display drift is unchanged across checked refs: `Server/FSM/updateresources.sqf:31,42-43,49,63,67` still gates/updates payouts while `Client/Functions/Client_GetIncome.sqf:24-28` omits the income-system `4` `1.5` display multiplier.
- Confirmed the branch split for supply rewards and AI debit: docs/Miksuu/perf keep the older truck-only reward path and swapped AI commander debit, while stable/release carry heli/cash-run state and fixed AI commander debit order. Side-supply arithmetic remains open except for Chernarus-only floor-to-zero arithmetic in `perf/quick-wins`.
- Refreshed [Economy, towns and supply](Economy-Towns-And-Supply) with a top route table, current branch scope, resource-income matrix, branch-split supply reward section and owner-page routes for side-supply, AI commander and supply authority.
- Aligned the linked [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) debit matrix so it now separates docs checkout/Miksuu/perf swapped debit from stable/release fixed debit order. No gameplay source changed.

## 2026-06-13T22:54:23+02:00 - Codex - Construction atlas branch-scope route

- Claimed `construction-atlas-branch-scope-route` as a docs-only construction/atlas gateway pass, with no gameplay source edits.
- Source-checked Construction/CoIn, auto-wall, SmallSite/MediumSite, StationaryDefense ARTY and salvage paths across docs checkout `1aa178f8`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots.
- Confirmed branch split: docs checkout carries the StationaryDefense `_availweapons` null guard at `Construction_StationaryDefense.sqf:12-15` plus commander-team ARTY gunner handoff at `:91-93`; stable/release use marker-based ARTY discovery at `Construction_StationaryDefense.sqf:133-135` and `Common_GetTeamArtillery.sqf:46-78`; Miksuu/perf keep the older `DefenseTeam` shape and no null guard.
- Confirmed no branch rescue for the patch-ready construction debt: auto-wall remains global, SmallSite remains add/add while MediumSite removes, and salvage still carries lowercase `ChangePlayerfunds`, the `updatesalvage.sqf:10` `||` loop and client-local deletion/reward.
- Refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas) with a top route table, current branch-scope matrix and branch-split ARTY/auto-wall/salvage wording; aligned [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) construction rows to the same owner-page evidence. No gameplay source changed.

## 2026-06-13T23:13:32+02:00 - Codex - Factory purchase atlas branch-scope route

- Claimed `factory-purchase-atlas-branch-scope-route` as a docs-only factory/purchase atlas pass, with no gameplay source edits.
- Source-checked buy-menu price/key and destroyed-factory refund behavior across docs checkout `8d611092`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/buymenu-easa-qol` `a66d4691` in maintained Chernarus and Vanilla roots.
- Confirmed branch split: stable/release now fix selected-detail price display in both maintained roots, mirror both driver-default keys, pass `_currentCost` into `BuildUnit` and refund the dead/null factory abort at `Client_BuildUnit.sqf:212-216`; docs checkout/Miksuu/perf keep the older selected-detail/key/refund shape, and the QoL branch fixes selected-detail display only in Chernarus.
- Confirmed the level-0 `UNIT_COST_MODIFIER` reset remains open everywhere checked: `Client_UIFillListBuyUnits.sqf:11,14` still only writes discounted levels, while `Init_CommonConstants.sqf` initializes the global once.
- Refreshed [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas) with a top route table, current branch-scope matrix and updated price/key plus refund matrices; aligned [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) factory rows to the same owner-page evidence. No gameplay source changed.

## 2026-06-13T23:29:18+02:00 - Codex - Upgrades research atlas branch-scope route

- Claimed `upgrades-research-atlas-branch-scope-route` as a docs-only upgrades/research atlas pass, with no gameplay source edits.
- Source-checked player upgrade UI, `RequestUpgrade`, server processing, `upgrade-sync`, AI commander upgrade debit/cost lookup and stale old upgrade dialog remnants across docs checkout `e785f1e9`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2`, `origin/feat/ai-commander` `c20ce153` and `origin/feat/upgrade-queue-stacking` `b061c905` in maintained Chernarus and Vanilla roots.
- Confirmed player upgrade requests remain client-authoritative across checked refs: `RequestUpgrade.sqf:5` still only spawns `WFBE_SE_FNC_ProcessUpgrade`, while `Server_ProcessUpgrade.sqf:12-18` trusts side/id/level/player flag from the payload.
- Confirmed branch split: docs checkout/Miksuu/perf still swap AI commander funds/supply debit at `Server_AI_Com_Upgrade.sqf:47,50`; stable/release/upgrade-queue fix debit order but still use raw AI-order level as the cost index at `:27`; `feat/ai-commander` fixes both only in Chernarus.
- Confirmed stale old `RscMenu_Upgrade` remains in docs checkout/Miksuu/perf but no checked hits remain on stable, release or upgrade-queue maintained roots.
- Refreshed [Upgrades and research](Upgrades-And-Research-Atlas) with a top route table and current branch-scope matrix; aligned [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) and [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix). No gameplay source changed.

## 2026-06-13T23:39:21+02:00 - Codex - Towns/camps atlas branch-scope route

- Claimed `towns-camps-capture-atlas-branch-scope-route` as a docs-only towns/camps atlas pass, with no gameplay source edits.
- Source-checked camp capture flags, `repair-camp`, zero-camp helpers, camp-helper consumers and Patrols v2 startup across docs checkout `3eefcb00`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots.
- Confirmed branch split: stable/release fix independent camp-capture flags in both maintained roots at `server_town_camp.sqf:83-86`; docs checkout still uses old `_side` at `:135`, Miksuu at `:89`, and perf fixes only Chernarus while Vanilla remains old-shape. `repair-camp` still changes side and broadcasts `CampCaptured` without a flag refresh in every checked ref.
- Confirmed no branch rescue for zero-camp helper semantics: all checked roots keep `Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16` returning `1`, with consumer line drift now documented for capture mode 2, threeway respawn and depot Buy Units gates.
- Refreshed [Towns, camps and capture](Towns-Camps-And-Capture-Atlas) with a top route table and current branch-scope matrix; aligned [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) camp rows to the same owner-page evidence. No gameplay source changed.

## 2026-06-13T23:54:31+02:00 - Codex - AI runtime/HC loop branch-scope route

- Claimed `ai-runtime-hc-loop-branch-scope-route` as a docs-only AI runtime/HC atlas pass, with no gameplay source edits.
- Source-checked AI supply-truck startup, tracked town-AI vehicle cleanup and missing `Server_CleanupExpiredTownDefenseAssets.sqf` path across docs checkout `b9e80da0`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/ai-commander` `c20ce153` in maintained Chernarus and Vanilla roots.
- Confirmed branch split: docs checkout/Miksuu/perf still raw-spawn the commented/missing `UpdateSupplyTruck` worker, stable/release warning-disable legacy AI supply-truck logistics at `Init_Server.sqf:383-384`, and `feat/ai-commander` guards only Chernarus while Vanilla remains raw.
- Confirmed DR-45 remains patch-ready across checked roots: inactive tracked town-AI vehicles still delete with only `!(isPlayer leader group _x)` and no player `crew` check at docs checkout `server_town_ai.sqf:214`, stable `:207`, Miksuu `:195`, perf `:219` and release `:200` in both maintained roots.
- Confirmed no checked ref in this pass contains `Server_CleanupExpiredTownDefenseAssets.sqf`; older `89ae9dad` persistent-defense helper evidence is now routed as historical branch evidence, not current branch truth.
- Refreshed [AI runtime and HC loop map](AI-Runtime-HC-Loop-Map) with a top route table and current branch-scope matrix; refreshed [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#current-branch-matrix); aligned [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) AI/town rows to the same owner-page evidence. No gameplay source changed.

## 2026-06-14T00:07:14+02:00 - Codex - Commander vote/reassign branch-scope route

- Claimed `commander-vote-reassign-branch-scope-route` as a docs-only commander correctness pass, with no gameplay source edits.
- Source-checked commander vote/reassignment, UI selector and Objective Ping scope across docs checkout `e2c9f6ed`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/ai-commander` `c20ce153` in maintained Chernarus and Vanilla roots.
- Confirmed DR-47 remains unpatched everywhere checked: `Server_VoteForCommander.sqf:18,27,43` still counts `_aiVotes` then selects any non-tied player candidate, while `GUI_VoteMenu.sqf:88` previews AI/no commander on row 0 or no strict majority.
- Confirmed DR-15 is branch-split: docs checkout still has `_side = _this` in `Server_AssignNewCommander.sqf:3`, while stable/Miksuu/perf/release/AI-commander fix helper unpacking at `:4-5`; all checked refs still keep duplicate `new-commander-assigned` senders and visible-name commander selection at `GUI_Commander_VoteMenu.sqf:33,37`.
- Refreshed [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) with a top route table and current branch-scope matrix; refreshed [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix); aligned commander rows in [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue), including Objective Ping current stable/release targeted-send evidence. No gameplay source changed.

## 2026-06-14T00:26:00+02:00 - Codex - Marker cleanup/restoration branch-scope route

- Claimed `marker-cleanup-restoration-branch-scope-route` as a docs-only marker/lifecycle cleanup atlas pass, with no gameplay source edits.
- Source-checked empty-vehicle cleanup across docs checkout `634a907b`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots.
- Confirmed no branch rescue for the empty supply-truck timeout: all checked roots still drain `WF_Logic` `emptyVehicles` through `Server/FSM/emptyvehiclescollector.sqf:9,15-19,30`, then `Server/Functions/Server_HandleEmptyVehicle.sqf:21-23` overrides supply-truck classes to `_delay = 86400`; ordinary empty-vehicle and medical/repair double-timeout paths remain separate at `Server_HandleEmptyVehicle.sqf:12,18`.
- Refreshed [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas) with a top route table, current branch scope and current cleanup startup anchors (`Init_Server.sqf:528-560`); aligned the empty supply-truck row in [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue). No gameplay source changed.

## 2026-06-14T00:44:00+02:00 - Codex - Modules atlas Reaktiv branch-scope route

- Claimed `modules-atlas-reaktiv-branch-scope-route` as a docs-only module atlas cleanup pass, with no gameplay source edits.
- Source-checked module init and attach edges on docs checkout `20a19676`: common init compiles ICBM/IRS/CIPHER at `Init_Common.sqf:319-323`, client init compiles or starts AFKkick/EASA/CM/Zeta/Skill/AutoFlip/Valhalla at `Init_Client.sqf:256-264,535,547,577,588-589,751,954`, server init compiles supply/MASH/AntiStack and starts NEURO/serverFPS at `Init_Server.sqf:66-81,85-87,105-114,595-608`, and built vehicles attach Engines/IRS handlers at `Client_BuildUnit.sqf:336-356`.
- Refreshed Reaktiv branch scope across docs checkout `20a19676`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2`: docs/Miksuu/perf still carry unreachable maintained-root `Common/Module/Reaktiv` files with no init call; stable/release have no maintained-root Reaktiv hits; all checked refs still carry stale modded Napf/Eden/Lingor copies.
- Refreshed [Modules atlas](Modules-Atlas) with a top route table, compact owner-page routes for high-risk/integration modules, and the current Reaktiv branch matrix; aligned [Dead/stale code](Dead-Code-And-Stale-Code-Register), dashboard/pruning ledger and machine records. No gameplay source changed.

## 2026-06-14T00:45:00+02:00 - Codex - Gameplay systems atlas route prune

- Claimed `gameplay-systems-atlas-route-prune` as a docs-only gameplay gateway cleanup pass, with no gameplay source edits.
- Source-checked broad gameplay anchors on docs checkout `ca40f202` and comparison refs stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2`.
- Confirmed `Server_AssignNewCommander.sqf` DR-15 is branch-split: docs checkout still reads `_side = _this` and `_commander = _this select 1`, while stable/Miksuu/perf/release use `_this select 0/1`; duplicate notifications and UI identity remain owner-page concerns.
- Confirmed HQ score line drift across checked refs: docs checkout awards score through `Server_OnHQKilled.sqf:23,47,49`, stable/release through `:23,52,54`, and `WFBE_C_BUILDINGS_SCORE_COEF` lines differ by branch. The gameplay page now routes HQ score/idempotency to the Commander/HQ owner matrix instead of preserving stale universal line refs.
- Confirmed static search across docs checkout, stable, Miksuu, perf and release finds `AIBuyUnit` only compiled at `Server/Init/Init_Server.sqf:10` plus worker-local `Server_BuyUnit.sqf` log strings; no active caller was found in the checked maintained source roots.
- Refreshed [Gameplay systems atlas](Gameplay-Systems-Atlas) with a top route table, current branch scope, corrected commander/HQ wording, factory latent-worker scope and a victory owner route. No gameplay source changed.

## 2026-06-14T00:56:40+02:00 - Codex - Victory/endgame branch-scope route

- Claimed `victory-endgame-branch-scope-route` as a docs-only victory/endgame atlas pass, with no gameplay source edits.
- Source-checked default victory detection, win logging, stale `Server/PVFunctions/LogGameEnd.sqf` presence and `Init_Server.sqf` duplicate bind status across docs checkout `2f2132f8`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots.
- Confirmed the default victory defect remains open across checked maintained roots: `server_victory_threeway.sqf:23-41` still mixes elimination/all-towns winner semantics, only guards the all-towns clause with `!WFBE_GameOver`, has no side-loop break after recording a result and calls the live logger at `:41`.
- Confirmed branch split for stale logger archaeology: `Server/PVFunctions/LogGameEnd.sqf` exists in docs checkout/Miksuu/perf maintained roots and is absent from stable/release maintained roots. The live logger remains `Server/Functions/Server_LogGameEnd.sqf`.
- Confirmed branch split for DR-43b init binds: docs checkout/Miksuu keep live duplicates in both maintained roots; stable/release keep one live bind per function in both maintained roots; perf de-duplicates Chernarus while maintained Vanilla remains old-shape.
- Refreshed [Victory/endgame atlas](Victory-And-Endgame-Atlas) with a top route table and branch-scope note; aligned [Server init bind cleanup](Server-Init-Bind-Cleanup), [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions), [SQF code atlas](SQF-Code-Atlas) and [Dead/stale code](Dead-Code-And-Stale-Code-Register). No gameplay source changed.

## 2026-06-14T01:07:20+02:00 - Codex - Gear/EASA branch-scope route

- Claimed `gear-easa-branch-scope-route` as a docs-only gear/service atlas pass, with no gameplay source edits.
- Source-checked gear profile/template save/import/creation, cargo equip loops, EASA purchase/debit and service action guards across docs checkout `8b71e2a1`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/buymenu-easa-qol` `a66d4691` in maintained Chernarus and Vanilla roots.
- Confirmed profile/template debt remains open everywhere checked: undefined `_u_upgrade` in `Client_UI_Gear_SaveTemplateProfile.sqf:33,52,75`, six-field `Init_ProfileGear.sqf:17` guard before reading `:25`, AddTemplate Barracks-or-Gear gate at `Client_UI_Gear_AddTemplate.sqf:136` and Gear-only FillTemplates at `Client_UI_Gear_FillTemplates.sqf:17`.
- Corrected cargo loop branch scope: docs checkout/Miksuu/EASA QoL still carry inclusive `Common_EquipVehicle.sqf:27,33,39` and `Common_EquipBackpack.sqf:35,41` loops in both maintained roots; stable and release fix all five loops in both maintained roots; perf fixes Chernarus only while perf Vanilla remains inclusive.
- Corrected service/EASA scope: stable and release partially guard service rearm/refuel in both maintained roots, but repair/heal context/funds guards and exact-funds EASA remain open; Miksuu/perf/EASA QoL keep unguarded rearm/refuel action debits, and all checked refs still use strict `_funds > price` plus client-side `EASA_Equip` / `ChangePlayerFunds`.
- Refreshed [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Service menu affordability guards](Service-Menu-Affordability-Guards), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue). No gameplay source changed.

## 2026-06-14T01:21:28+02:00 - Codex - SQF atlas source snapshot route

- Claimed `sqf-atlas-source-snapshot-route` as a docs-only SQF atlas cleanup pass, with no gameplay source edits.
- Rechecked the Chernarus compile-registry snapshot on docs checkout `b13308ff`: `git diff --quiet 04a60e43..HEAD -- ":(literal)Missions/[55-2hc]warfarev2_073v48co.chernarus"` confirms the mission source tree is unchanged from the original `04a60e43` snapshot.
- Reran the preprocess counter on `Missions/[55-2hc]warfarev2_073v48co.chernarus`: 738 total `preprocessFile` references, 460 `preprocessFileLineNumbers`, 278 plain `preprocessFile`, 22 commented refs; target-area counts remain `Common` 492, `Client` 142, `Server` 92, root/bootstrap 7, `Headless` 4 and `WASP` 1.
- Branch-checked `Server/Init/Init_Server.sqf` duplicate/runtime bind shape across docs `b13308ff`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots: docs/Miksuu keep live duplicate `LogGameEnd`, `PlayerObjectsList` and `AwardScorePlayer` binds at `:64,69,83,89,91,93`; stable/release keep one live bind per function; perf fixes Chernarus only.
- Refreshed [SQF code atlas](SQF-Code-Atlas) to name the current source-snapshot check, fix the regenerate command's path trim, and route branch-sensitive `UpdateSupplyTruck` and server-FPS monitor caveats to [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix) plus [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors). No gameplay source changed.

## 2026-06-14T01:29:26+02:00 - Codex - Server runtime atlas source-scope route

- Claimed `server-runtime-atlas-source-scope-route` as a docs-only server runtime atlas cleanup pass, with no gameplay source edits.
- Rechecked server-runtime anchors on docs checkout `92c5cf05`: relevant `Server/` runtime paths plus Patrols v2 probe paths are unchanged from the earlier `6afcc58e` anchor snapshot, so existing docs-checkout line refs remain valid for that branch.
- Branch-checked AI supply-truck startup, Patrols v2 file presence and server FPS publisher shape across docs `92c5cf05`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots.
- Confirmed stable `cf2a6d6a` log-disables legacy AI supply-truck logistics and starts Patrols v2; release `a96fdda2` matches the supply-truck and FPS single-publisher cleanup but does not carry Patrols v2 files; Miksuu/perf retain the raw supply-truck spawn and two unguarded FPS publishers in checked roots.
- Refreshed [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) and [Server runtime and operations](Server-Runtime-And-Operations) to route branch-sensitive startup/FPS/Patrols claims through the atlas instead of treating old docs-checkout anchors as current-master evidence. No gameplay source changed.

## 2026-06-14T01:40:37+02:00 - Codex - Client UI atlas source-scope route

- Claimed `client-ui-atlas-source-scope-route` as a docs-only Client UI atlas cleanup pass, with no gameplay/UI source edits.
- Rechecked docs checkout `a71b42fe`: `Rsc`, `GUI_Menu.sqf`, vote/help menu controllers and `Init_Client.sqf` paths used by the Client UI atlas are unchanged from the earlier `f7bc72a8` anchor snapshot, so existing docs-checkout line refs remain valid.
- Branch-checked `RscClickableText.soundPush[]`, `MenuAction` `17/18/19`, help lifecycle variables and vote-loop line refs across docs `a71b42fe`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and release `a96fdda2` in maintained Chernarus and Vanilla roots.
- Confirmed `MenuAction = 19` is branch-sensitive: docs/Miksuu/perf expose `CA_FPSHUD_Button` and toggle the FPS HUD, while stable/release expose `CA_GPS_Button` and enable GPS; every checked root still keeps handler-only `MenuAction == 17/18` GPS zoom routes.
- Refreshed [Client UI systems atlas](Client-UI-Systems-Atlas) source-scope note, main-menu router row, vote/help/main-menu matrix and clickable-text matrix. No gameplay source changed.

## 2026-06-14T01:52:54+02:00 - Codex - Architecture overview source-scope route

- Claimed `architecture-overview-source-scope-route` as a docs-only architecture gateway source-scope pass, with no gameplay/source edits.
- Rechecked docs checkout `1bef8801`: `description.ext`, `initJIPCompatible.sqf`, `Init_Common.sqf`, `Init_Server.sqf`, `Init_Client.sqf`, `Init_HC.sqf`, `FileManager.cs`, `SqfFileGenerator.cs` and `ZipManager.cs` are unchanged from the earlier `1aa178f8` architecture overview anchor snapshot, so existing docs-checkout line refs remain valid.
- Branch-checked LoadoutManager root discovery across docs `1bef8801`, stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`: docs accepts ancestor-name or `Missions`/`Missions_Vanilla`/project-file repo shape, stable/release use mission-path plus `Tools/LoadoutManager` plus `AGENTS.md`, and Miksuu/perf still require an ancestor named `a2waspwarfare`.
- Refreshed [Architecture overview](Architecture-Overview) with a current source-scope note, compact branch-scope table and sharper LoadoutManager root wording. No gameplay source changed.

## 2026-06-14T02:02:42+02:00 - Codex - Mission lifecycle source-scope route

- Claimed `mission-lifecycle-source-scope-route` as a docs-only lifecycle entrypoint cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `9da5f1d0` against the Chernarus source mission root: `description.ext:39,41-58,64,66-67`, `initJIPCompatible.sqf:52-56,212,214-215,218-220,224-233,237-238`, `mission.sqm:128,3265`, `Common/Init/Init_Town.sqf:18,42,92,134`, `Common/Init/Init_Common.sqf:282,303,371`, `Server/Init/Init_Server.sqf:117,127,507`, `Client/Init/Init_Client.sqf:360,367,384,394-397,463,467,490,595,787-789,956,960,962` and `Headless/Init/Init_HC.sqf:12,15`.
- Confirmed the 2026-06-14 checkout has no tracked or present generated `version.sqf` files in checked Chernarus or Vanilla Takistan roots, while `.gitignore:1,23` still ignores those generated paths. The clean-checkout/build warning remains, but the page no longer claims local ignored files are present.
- Branch-checked front-door topology across docs `9da5f1d0`, stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`: all checked refs still start Common/Towns and then route Server, Client and Headless from `initJIPCompatible.sqf`; stable line refs drift to `:217-241`, perf has `serverInitFull` at `Init_Server.sqf:502`, and stable/release/Miksuu have HC sleep/register at `Init_HC.sqf:14,17`.
- Refreshed [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) with a source-scope section and replaced the duplicate boot-flag mini-table with a link to [Lifecycle wait-chain](Lifecycle-Wait-Chain); refreshed [Lifecycle wait-chain](Lifecycle-Wait-Chain) with the same source-scope warning plus current `VERSION_SET`, `clientInitComplete`, `CLIENT_INIT_READY` and blackout line refs. No gameplay source changed.

## 2026-06-14T02:13:01+02:00 - Codex - Function/module index source-scope route

- Claimed `function-module-index-source-scope-route` as a docs-only SQF source-family gateway cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `1f0b9018` function-family anchors: `Common/Init/Init_Common.sqf:128,134`, `Client/Init/Init_Client.sqf:102,110`, `Server/Init/Init_Server.sqf:48,53,57`, `Common/Init/Init_PublicVariables.sqf:39,45-51`, `Server_AssignNewCommander.sqf:3-4,9`, `Server_AI_Com_Upgrade.sqf:12,27,41,47,50` and `Common/Module/Reaktiv/Reaktiv_Init.sqf:5`.
- Branch-checked commander reassignment helper shape across docs `1f0b9018`, stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`: docs Chernarus/Vanilla still use `_side = _this`, while the other checked refs use `_this select 0/1` in both maintained roots but keep duplicate `new-commander-assigned` senders.
- Branch-checked paratrooper marker registration: docs/stable/release register `HandleParatrooperMarkerCreation` in both maintained roots (`:39` on docs, `:34` on stable/release), Miksuu omits it in both roots, and perf registers Chernarus only at `Init_PublicVariables.sqf:40`.
- Branch-checked MASH/Reaktiv module scope: docs/Miksuu/perf keep orphaned MASH marker relay and Reaktiv files in maintained roots; stable/release have no maintained-root `Client/Module/MASH`, `Server/Module/MASH` or `Common/Module/Reaktiv` tree entries and no MASH init hooks, while stable/release `Skill_Apply.sqf:43` records the MASH deploy ability removal and config/classname residues remain.
- Refreshed [Function and module index](Function-And-Module-Index) with source scope and route tables, routed branch-sensitive module detail to owner pages, and aligned [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas) plus [Feature status](Feature-Status-Register) for current MASH/paratrooper branch evidence. No gameplay source changed.

## 2026-06-14T02:24:12+02:00 - Codex - AI/headless performance gateway route

- Claimed `ai-headless-performance-gateway-route` as a docs-only AI/HC/performance atlas cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `ee383941` against the earlier `b9e80da0` AI runtime pass: the checked AI/headless paths (`Rsc/Parameters.hpp`, `Init_CommonConstants.sqf`, `initJIPCompatible.sqf`, `Headless/Init/Init_HC.sqf`, `Server_HandleSpecial.sqf`, `server_town_ai.sqf`, `updateavailableactions.fsm`, `updateclient.sqf`) are unchanged, so existing docs-checkout line refs remain valid.
- Verified current comparison refs: stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and `origin/feat/ai-commander` `c20ce153`.
- Branch-checked Patrols v2 file presence: stable `origin/master` carries `Server/FSM/server_side_patrols.sqf`, `Common/Functions/Common_RunSidePatrol.sqf` and `Client/FSM/updatepatrolmarkers.sqf` in both maintained roots; docs checkout, release, Miksuu, perf and `feat/ai-commander` lack those Patrols v2 files in checked maintained roots. Release keeps the older patrol loop-exit fix only.
- Refreshed [AI, headless and performance](AI-Headless-And-Performance) with a route table, source-scope note and branch-scope table; corrected the current `feat/ai-commander` head from old `4dba060e` wording to `c20ce153`; and corrected [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) Patrols v2 wording so release is no longer overstated. No gameplay source changed.

## 2026-06-14T02:35:57+02:00 - Codex - Networking/public-variable source-scope route

- Claimed `networking-public-variable-source-scope-route` as a docs-only networking gateway cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `59deb306` in source Chernarus and maintained Vanilla: registered PVF lists/PVEHs are at `Init_PublicVariables.sqf:9-21,26-40,46,51`; generic dispatch-time compile is still `Server_HandlePVF.sqf:14` and `Client_HandlePVF.sqf:22`; direct `SEND_MESSAGE` remains registered at `updateclient.sqf:12` with receiver/helper compile at `Client_onEventHandler_SEND_MESSAGE.sqf:27` and `Common_SendMessage.sqf:26,37-38`.
- Verified current comparison refs: stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and `origin/feat/ai-commander` `c20ce153`.
- Branch-checked commander `SetTask` / Objective Ping status: docs checkout, Miksuu, perf and `feat/ai-commander` register `SetTask` but leave commander-menu sends commented at `GUI_Menu_Command.sqf:335,337,343`; stable and release send targeted Objective Ping tasks at `GUI_Menu_Command.sqf:336,344` in both maintained roots. Old town `Client_TaskSystem.sqf` remains commented everywhere checked.
- Refreshed [Networking and public variables](Networking-And-Public-Variables) with current source-scope and branch-route wording, kept full inventory on [Public variable channel index](Public-Variable-Channel-Index), kept dispatcher branch status on [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), and corrected Objective Ping release wording from historical `7ff18c49` to current `a96fdda2`. No gameplay source changed.

## 2026-06-14T02:46:13+02:00 - Codex - Support specials source-scope route

- Claimed `support-specials-source-scope-route` as a docs-only support/tactical atlas cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `ff8dd884` in source Chernarus and maintained Vanilla for Tactical menu support anchors, `RequestSpecial` PVF transport, `Server_HandleSpecial.sqf`, artillery/fire-mission helpers, UAV/nuke/Zeta leaf modules and the RU para-ammo config trap.
- Verified current comparison refs: stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and `origin/feat/upgrade-queue-stacking` `b061c905`.
- Branch-checked `upgrade-sync`: docs checkout keeps the mixed `_args` / `_this` parser at `Server_HandleSpecial.sqf:67-73` and the client timer caller at `GUI_UpgradeMenu.sqf:171` in both maintained roots; stable/upgrade-queue callers drift to `:268`, Miksuu/perf to `:241` and release to `:254`. `_args = _this` still makes this consistency cleanup rather than a proven current runtime break.
- Refreshed [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas) with a current source snapshot and less repeated dispatch/artillery prose; aligned [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) for the refreshed `upgrade-sync` evidence. No gameplay source changed.

## 2026-06-14T03:00:14+02:00 - Codex - Commander/HQ source-scope route

- Claimed `commander-hq-source-scope-route` as a docs-only commander/HQ atlas cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `f82a9127` in source Chernarus and maintained Vanilla for commander vote, reassignment, HQ kill score, MHQ repair, base-area and commander task anchors.
- Verified current comparison refs: stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and `origin/feat/ai-commander` `c20ce153`.
- Branch-checked HQ score double-award: docs/Miksuu/perf use `Server_OnHQKilled.sqf:23,49,78,81`, stable/release use `:23,54,83,86`, and feat-ai uses `:23,49,78,81`; all checked roots still keep generic HQ building score plus the second HQ bounty.
- Branch-checked commander scope: vote AI/no-commander semantics remain unpatched everywhere checked; docs checkout still has the DR-15 helper `_side = _this`, while stable/Miksuu/perf/release/feat-ai fix helper unpacking but keep duplicate `new-commander-assigned` senders; docs/Miksuu/perf/feat-ai leave maintained-root `SetTask` sends commented, while stable/release send targeted Objective Ping tasks.
- Refreshed [Commander and HQ lifecycle](Commander-HQ-Lifecycle-Atlas) with top route/source-scope tables and aligned [Feature status](Feature-Status-Register) plus [Source fix propagation queue](Source-Fix-Propagation-Queue) for HQ score, reassignment, Objective Ping and old `TaskSystem` residue. No gameplay source changed.

## 2026-06-14T03:12:25+02:00 - Codex - Assets/config/parameters source-scope route

- Claimed `assets-config-parameters-source-scope-route` as a docs-only config/media atlas cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `85679dba`: source Chernarus has 20 local texture `.paa`, 45 client image `.paa`, 26 sound `.ogg` and 2 music `.ogg` files; `Sounds/description.ext` still defines 26 non-wrapper sound classes; `Rsc/Dialogs.hpp` has 18 top-level dialog classes; `Rsc/Titles.hpp` has 99 title class rows.
- Confirmed Chernarus and maintained Vanilla `Rsc/Parameters.hpp` have identical SHA-256 hashes, expose 89 active lobby-visible parameters plus one commented upgrade-clearance class, and currently have no present or tracked generated `version.sqf` files.
- Verified comparison refs stable `cf2a6d6a`, Miksuu `b8389e74`, perf `0076040f` and release `a96fdda2` do not track generated Chernarus/Vanilla `version.sqf` and still keep the IR-smoke lobby/runtime name split plus live bomb-distance/commented bomb-altitude shape.
- Refreshed [Assets/config/localization/parameters atlas](Assets-Config-Localization-And-Parameters-Atlas) with route/source-scope tables, reduced duplicated parameter caveats by linking to [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs) and [Mission start parameters index](Mission-Start-Parameters-Index), and corrected generated `version.sqf` wording in [Mission config/version include graph](Mission-Config-Version-Include-Graph), [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs), [Mission start parameters index](Mission-Start-Parameters-Index), [Feature status](Feature-Status-Register), [Tools/build workflow](Tools-And-Build-Workflow), [Coverage ledger](Codebase-Coverage-Ledger), [Hardening roadmap](Hardening-Implementation-Roadmap) and [Pending owner decisions](Pending-Owner-Decisions). No gameplay source changed.

## 2026-06-14T03:30:14+02:00 - Codex - Supply mission architecture branch-scope route

- Claimed `supply-mission-architecture-branch-scope-route` as a docs-only supply owner-page cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `8a6695b8` against earlier `6d05cb5a` mission-root anchors and confirmed the maintained Chernarus/Vanilla mission roots are unchanged for this supply pass.
- Verified comparison refs: stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`.
- Branch-checked supply mission status: docs/source Chernarus and maintained Vanilla keep truck-only flow with typed terminal scan at `supplyMissionStarted.sqf:25,28`, lowercase/uppercase cooldown split and dead `WFBE_SE_FNC_SupplyMissionActive` compile; stable and release carry heli-aware scan/cash-run state plus `SupplyByHeli` cleanup, cooldown casing/default fix and dead-twin removal in both maintained roots; Miksuu/perf remain broad-scan truck-only with the cooldown/dead-twin debt.
- Refreshed [Supply mission architecture](Supply-Mission-Architecture) with current branch scope, replaced stale PR-vs-master wording with a truck-only versus stable/release supply-heli matrix, refreshed [Economy/Towns/Supply](Economy-Towns-And-Supply) docs-checkout refs, and aligned supply rows in [Feature status](Feature-Status-Register). No gameplay source changed.

## 2026-06-14T03:39:38+02:00 - Codex - Current source status snapshot route

- Claimed `current-source-status-snapshot-route` as a docs-only source-status routing pass, with no gameplay source edits.
- Verified comparison refs: docs checkout `docs/developer-wiki-index` `76674ae4`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`.
- Branch-checked current status rows: paratrooper registration is docs/stable/release in both maintained roots, Miksuu absent and perf Chernarus-only; `Skill_Init` is single-call on docs/stable/release and duplicated on Miksuu/perf; hosted FPS is two guarded publishers on docs, one guarded publisher on stable/release, and two unguarded publishers on Miksuu/perf; supply scan is docs truck-only typed, stable/release heli-aware typed, Miksuu/perf broad; commander-built ARTY is docs commander-team handoff, stable/release marker-based discovery and Miksuu/perf old `DefenseTeam`.
- Corrected a queue drift found during the pass: docs/source moves `_i = 0` before the supply `WFBE_SE_PLAYERLIST` loop at `playerObjectsList.sqf:17`, while stable/release/Miksuu/perf still reset it inside the loop at `:18`.
- Refreshed [Current source status snapshot](Current-Source-Status-Snapshot) with a 2026-06-14 current-ref matrix and marked older 2026-06-03/05 matrices historical; aligned [Source fix propagation queue](Source-Fix-Propagation-Queue) so stable/release are not overstated as carrying the supply player-list index fix. No gameplay source changed.

## 2026-06-14T03:56:15+02:00 - Codex - Construction/CoIn atlas current-source route

- Claimed `construction-coin-atlas-current-source-route` as a docs-only construction/CoIn atlas cleanup pass, with no gameplay source edits.
- Rechecked docs checkout `4bd37b98` against earlier construction atlas anchors and confirmed the checked construction, CoIn, artillery, salvage and LoadoutManager source files remain unchanged from the earlier source snapshots, so existing docs-checkout line refs remain valid.
- Branch-checked construction status across docs checkout `4bd37b98`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`: docs carries the StationaryDefense base-area guard and commander-team ARTY handoff; stable/release use marker-based commander ARTY discovery but still lack the base-area guard; Miksuu/perf have neither ARTY discovery shape nor the guard.
- Refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas) to reduce repeated auto-wall, StationaryDefense, SmallSite/MediumSite and salvage branch prose; refreshed [Construction logic list cleanup](Construction-Logic-List-Cleanup) with the same 2026-06-14 refs; and aligned [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [Function/module index](Function-And-Module-Index) to the current source-fix anchor. No gameplay source changed.

## 2026-06-14T04:06:51+02:00 - Codex - Upgrades/research current-source route

- Claimed `upgrades-research-current-source-route` as a docs-only upgrade atlas/source-scope pass, with no gameplay source edits.
- Rechecked docs checkout `d4cfef80` against the earlier `e785f1e9` upgrade-atlas anchors and confirmed the checked upgrade UI/server, AI upgrade, `upgrade-sync` and stale-dialog files are unchanged, so existing docs-checkout line refs remain valid.
- Branch-checked the AI upgrade debit and stale old upgrade dialog scope across stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, `origin/feat/ai-commander` `c20ce153` and `origin/feat/upgrade-queue-stacking` `b061c905`: docs/Miksuu/perf still keep swapped AI debit and stale `RscMenu_Upgrade`, stable/release/upgrade-queue fix debit order and remove the stale dialog, and `feat/ai-commander` fixes cost-index lookup only in Chernarus.
- Refreshed [Upgrades and research](Upgrades-And-Research-Atlas), [AI commander autonomy](AI-Commander-Autonomy-Audit), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) for the current docs checkout while keeping implementation status routed to the owner pages. No gameplay source changed.

## 2026-06-14T04:16:08+02:00 - Codex - Hosted FPS current-branch route

- Claimed `hosted-fps-current-branch-route` as a docs-only hosted server FPS owner/status refresh, with no gameplay source edits.
- Verified current comparison refs: docs checkout `db7667c9`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`.
- Branch-checked FPS publisher shape: docs/source Chernarus and maintained Vanilla keep two guarded publishers at `Server/GUI/serverFpsGUI.sqf:1` and `Server/Module/serverFPS/monitorServerFPS.sqf:1`, started from `Server/Init/Init_Server.sqf:578,595`; stable and release keep one guarded `serverFpsGUI.sqf:4` publisher and remove the old monitor path, with removal comments at stable `Init_Server.sqf:596-598` and release `Init_Server.sqf:595-597`; Miksuu/perf keep the old two-loop shape.
- Refreshed [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) with a current branch matrix and aligned [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions), release readiness and machine status rows so stable/release are no longer documented as old-loop current truth. No gameplay source changed.

## 2026-06-14T04:32:40+02:00 - Codex - Economy authority current-branch route

- Claimed `economy-authority-current-branch-route` as a docs-only economy authority/status refresh, with no gameplay source edits.
- Verified current comparison refs: docs checkout `f52ccee8`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`.
- Branch-checked side-supply clamp/reason and resource income scope: docs/stable/release/Miksuu still keep the overspend-as-credit floor, payload-side temp-channel trust and reason-string off-by-one in both maintained roots; perf fixes only the Chernarus side-supply arithmetic floor and leaves perf Vanilla plus validation/reason work open; resource income keeps the cap-guard and income-system `4` server/client display drift everywhere checked.
- Refreshed [Economy authority first cut](Economy-Authority-First-Cut), aligned [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), `agent-feature-status.jsonl` and `agent-hardening-backlog.jsonl` to the current branch evidence. No gameplay source changed.

## 2026-06-14T04:44:00+02:00 - Codex - PR8 release current-branch route

- Claimed `pr8-release-current-branch-route` as a docs-only release/PR8 status cleanup, with no gameplay source edits.
- Verified comparison refs: docs checkout `f2773aa9`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`.
- Source-checked current release Chernarus and maintained Vanilla for delegated AI and commander ARTY anchors: town HC groups register and report back through `Client_DelegateTownAI.sqf:29-44` and `Server_HandleSpecial.sqf:86-115`; static-defense HC update-back remains commented at `Client_DelegateAIStaticDefence.sqf:27-30`; stable/release marker-based commander ARTY uses `Construction_StationaryDefense.sqf:132-135` and `Common_GetTeamArtillery.sqf:46-78`.
- Refreshed [PR cleanup lab](PR-Cleanup-And-Integration-Lab), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Feature status](Feature-Status-Register), `agent-release-readiness.json`, [Progress Dashboard](Progress-Dashboard) and [Wiki pruning ledger](Wiki-Pruning-And-Relevance-Ledger) so `a96fdda2` is the current release head, older `7195b331` / `7ff18c49` rows are historical, commander-built ARTY is no longer documented as absent on stable/release, and HC/static delegation plus Arma smoke remain explicit release gates. No gameplay source changed.

## 2026-06-14T05:00:37+02:00 - Codex - SQF PVF registry route

- Claimed `sqf-pvf-registry-route` as a docs-only atlas/channel-index cleanup, with no gameplay source edits.
- Verified comparison refs: docs checkout `40c97e74`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and `origin/feat/ai-commander` `c20ce153`.
- Source-checked Chernarus and maintained Vanilla `Common/Init/Init_PublicVariables.sqf`: docs checkout has 13 server PVFs at `:9-21` plus 15 client PVFs at `:25-40` with `HandleParatrooperMarkerCreation` at `:39`; stable/release add `RequestEnqueue` and `RequestDequeue` at `:22-23` in both maintained roots; Miksuu and `feat/ai-commander` omit paratrooper registration in both maintained roots; perf registers paratrooper only in Chernarus at `:40`.
- Replaced the stale registered-command tables in [SQF code atlas](SQF-Code-Atlas) with a source-scoped registry summary and routed command inventory to [Public variable channel index](Public-Variable-Channel-Index#current-branch-registry-matrix). Aligned [Networking/public variables](Networking-And-Public-Variables) and coordination records so older command-count notes do not override current source evidence. No gameplay source changed.

## 2026-06-14T05:11:17+02:00 - Codex - Client skill init current-branch route

- Claimed `client-skill-init-current-branch-route` as a docs-only owner/status refresh, with no gameplay source edits.
- Verified comparison refs: docs checkout `719455a2`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f` and `origin/feat/ai-commander` `c20ce153`.
- Branch-checked Chernarus and maintained Vanilla `Client/Init/Init_Client.sqf`: docs checkout keeps one `Skill_Init.sqf` call at `:547` plus `WFBE_SK_FNC_Apply` at `:571`; stable uses `:564` plus apply `:587`; release uses `:563` plus apply `:586`; Miksuu duplicates at `:560` and `:584`; perf and `feat/ai-commander` duplicate at `:561` and `:585`.
- Refreshed [Client skill init idempotency](Client-Skill-Init-Idempotency), [Feature status](Feature-Status-Register), `agent-feature-status.jsonl` and `agent-context.json` so older stable/release wording no longer overrides current branch evidence. Arma Soldier/non-Soldier, respawn reapply and dedicated/JIP smoke remain pending. No gameplay source changed.

## 2026-06-14T05:23:03+02:00 - Codex - SQF/network branch caveat route

- Claimed `sqf-network-branch-caveat-route` as a docs-only gateway cleanup for [SQF code atlas](SQF-Code-Atlas) and [Networking/public variables](Networking-And-Public-Variables), with no gameplay source edits.
- Verified docs checkout `8701aacc` has no maintained mission-root or `Tools/LoadoutManager` source changes since the older `04a60e43`, `40c97e74`, `59deb306` and `92c5cf05` atlas anchors, so the existing docs-checkout line refs remain valid.
- Branch-checked AI supply-truck startup: docs checkout and Miksuu still spawn `UpdateSupplyTruck` after a commented compile, perf does the same with Chernarus line drift, stable/release log-disable the path at `Init_Server.sqf:384`, and `feat/ai-commander` guards only Chernarus at `:389`; all checked `AI_UpdateSupplyTruck.sqf` copies still reference missing `Server\FSM\supplytruck.fsm`.
- Branch-checked supply-heli source: docs checkout, Miksuu and perf are truck-only; stable `origin/master` `cf2a6d6a` and release `a96fdda2` carry `SupplyByHeli`, supply-heli load/unload, reward multiplier and commander cash-run source in both maintained roots. Updated the gateway caveats so supply-heli is no longer described as PR-only everywhere. No gameplay source changed.

## 2026-06-14T05:33:02+02:00 - Codex - Client UI title/resource current-branch route

- Claimed `client-ui-title-resource-current-branch-route` as a docs-only client UI atlas/resource parity refresh, with no gameplay source edits.
- Verified comparison refs: docs checkout `2fef1e3d`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`.
- Branch-checked UI resource parity: docs/Miksuu/perf keep stale `RscMenu_Upgrade`, Economy `23004`/`23005`/`23006` writes and EASA/Economy duplicate `idd=23000` in both maintained roots; stable/release remove the stale upgrade class, rewrite Economy around `23020`, and split EASA to `idd=24000` in both maintained roots.
- Branch-checked title resources: `RscOverlay`/`OptionsAvailable` still duplicate `idd=10200` everywhere checked, and `OptionsAvailable` plus `EndOfGameStats` still share `uiNamespace["currentCutDisplay"]`; no checked maintained root has `findDisplay 23000` or `findDisplay 10200` callers. Refreshed [Client UI systems](Client-UI-Systems-Atlas), [UI resource parity cleanup](UI-Resource-Parity-Cleanup), [UI IDD collision repair](UI-IDD-Collision-Repair), status rows and machine rows. No gameplay source changed.

## 2026-06-14T05:47:40+02:00 - Codex - Client UI economy/fast-travel status route

- Claimed `client-ui-economy-fast-travel-status-route` as a docs-only status refresh for stale Economy and Tactical fast-travel rows, with no gameplay source edits.
- Verified comparison refs: docs checkout `d2a3f995`, stable `origin/master` `cf2a6d6a`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f`.
- Branch-checked Economy UI parity: docs/Miksuu/perf still write `23004`/`23005`/`23006` from `GUI_Menu_Economy.sqf:7-8` in both maintained roots while the current `RscMenu_Economy` controls declare `23002`, `23003` and `23008`; stable/release use dashboard `23020` at `GUI_Menu_Economy.sqf:25` and declare it in both maintained roots.
- Branch-checked Tactical fast-travel fee UX: all checked refs keep the same `GUI_Menu_Tactical.sqf:146-147,185-217,403-406` policy TODO, hidden unaffordable town destinations, marker-only price text and local debit shape; constants line-drift between docs/Miksuu/perf, stable and release only.
- Refreshed [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), `agent-feature-status.jsonl` and coordination records so older `89ae9dad` / `7ff18c49` wording no longer overrides current branch evidence. No gameplay source changed.

## 2026-06-14T05:56:37+02:00 - Codex - Architecture/SQF anchor continuity route

- Claimed `architecture-sqf-anchor-continuity-route` as a docs-only gateway/source-anchor continuity pass, with no gameplay source edits.
- Verified docs checkout `4277a2ad` after fetch. Targeted `git diff --name-only` checks from `1bef8801`, `8701aacc`, `92c5cf05` and `59deb306` to `HEAD` returned no changes for the checked architecture, SQF, server-runtime and network source paths.
- Regenerated the SQF compile-count command over source Chernarus and confirmed the atlas counts still hold: `738` total `preprocessFile` matches, `460` `preprocessFileLineNumbers`, `278` plain `preprocessFile` and `22` commented matches.
- Refreshed [Architecture overview](Architecture-Overview), [SQF code atlas](SQF-Code-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Server runtime and operations](Server-Runtime-And-Operations) and [Networking/public variables](Networking-And-Public-Variables) so current readers see `4277a2ad` as the docs-checkout source-continuity checkpoint while older hashes remain preserved as line-anchor provenance. No gameplay source changed.

## 2026-06-14T06:05:45+02:00 - Codex - Client UI atlas continuity route

- Claimed `client-ui-atlas-continuity-route` as a docs-only UI atlas/source-continuity pass, with no gameplay source edits.
- Verified current docs checkout `b5219d47`. Targeted `git diff --name-only` checks from `a71b42fe`, `2fef1e3d` and `f7bc72a8` to `HEAD` returned no changes for the checked `Rsc`, `Client/GUI`, client init, RHUD and `updateavailableactions.fsm` paths.
- Rechecked the UI caveats that depend on those anchors: no maintained-root `findDisplay 23000` / `findDisplay 10200` callers were found; docs/source still has malformed `RscClickableText.soundPush[]`, visible `MenuAction = 19` as FPS HUD, handler-only `17/18` GPS zoom routes and the same vote/help/router anchors.
- Refreshed [Client UI systems atlas](Client-UI-Systems-Atlas), [UI resource parity cleanup](UI-Resource-Parity-Cleanup), [UI IDD collision repair](UI-IDD-Collision-Repair), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current readers see `b5219d47` as the docs-checkout source-continuity checkpoint while older UI hashes remain line-anchor provenance. No gameplay source changed.

## 2026-06-14T06:20:20+02:00 - Codex - Networking/PV gateway prune route

- Claimed `networking-pv-gateway-prune-route` as a docs-only networking gateway cleanup pass, with no gameplay source edits.
- Rechecked current docs head `aa1a4b76`: targeted `git diff --name-only 4277a2ad..HEAD` checks returned no changes for the checked Chernarus and maintained Vanilla PVF registration, dispatcher, `SEND_MESSAGE` and attack-wave source paths.
- Pruned [Networking and public variables](Networking-And-Public-Variables) from `234` to `157` lines by replacing copied PVF command lists, duplicated dispatch wrapper detail, residual authority proof and attack-wave proof with route tables to [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), [Server authority migration map](Server-Authority-Migration-Map) and [Attack-wave authority](Attack-Wave-Authority-Playbook). Kept the registered client PVF runtime matrix because owner pages still route runtime/JIP behavior there.
- Updated [Public variable channel index](Public-Variable-Channel-Index) wording so it reflects that Networking and SQF atlas now route there for command/channel inventory. No gameplay source changed.

## 2026-06-14T06:29:17+02:00 - Codex - SQF atlas compile route prune

- Claimed `sqf-atlas-compile-route-prune` as a docs-only SQF atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `34212d6a`: targeted `git diff --name-only 4277a2ad..HEAD` checks returned no changes for the checked PVF registration, server-init, client-init, common-init and AI supply-truck source paths.
- Source-checked the disabled/deferred compile anchors: `UpdateSupplyTruck` compile/spawn at `Init_Server.sqf:36,383` plus missing `supplytruck.fsm`; old client TaskSystem, MASH marker receiver, plural blink/add-track comments; dormant common AT/bomb hooks; and the commented-but-execed second FPS publisher at `Init_Server.sqf:65,90,595`.
- Pruned [SQF code atlas](SQF-Code-Atlas) so PVF branch counts route to [Public variable channel index](Public-Variable-Channel-Index#current-branch-registry-matrix), direct attack-wave proof routes to [Attack-wave authority](Attack-Wave-Authority-Playbook), `LogGameEnd` duplicate-bind status routes to [Server init bind cleanup](Server-Init-Bind-Cleanup), and disabled/deferred compile signals route to their owner pages instead of restating branch matrices. No gameplay source changed.

## 2026-06-14T06:39:21+02:00 - Codex - Server runtime gateway route prune

- Claimed `server-runtime-gateway-route-prune` as a docs-only server runtime gateway/atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `a6785f51`: targeted `git diff --name-only 4277a2ad..HEAD` checks returned no changes for checked server runtime paths: `Init_Server.sqf`, `Server/FSM`, `Server/Module`, `Server_SideMessage.sqf`, `Server_OnHQKilled.sqf` and `serverFpsGUI.sqf`.
- Refreshed [Server runtime and operations](Server-Runtime-And-Operations) and [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) so `a6785f51` is the visible server-runtime source-continuity checkpoint while older hashes remain line-anchor provenance.
- Pruned repeated runtime-risk branch detail: hosted FPS, AI supply-truck startup, Patrols v2 and dormant server hooks now route to the branch-scope table plus owner pages instead of repeating exact branch proof in both places. No gameplay source changed.

## 2026-06-14T06:47:40+02:00 - Codex - Architecture overview tooling route prune

- Claimed `architecture-overview-tooling-route-prune` as a docs-only Architecture overview cleanup pass, with no gameplay source edits.
- Rechecked current docs head `adb9dbc8`: targeted `git diff --name-only 4277a2ad..HEAD` checks returned no changes for overview runtime/tooling paths: `description.ext`, `initJIPCompatible.sqf`, Common/Server/Client/Headless init, `FileManager.cs`, `SqfFileGenerator.cs` and `ZipManager.cs`.
- Refreshed [Architecture overview](Architecture-Overview) so `adb9dbc8` is the visible source-continuity checkpoint while older overview hashes remain line-anchor provenance.
- Pruned repeated LoadoutManager root-discovery, generated-target and packaging detail by routing branch matrices and operational rules to [Tools and build workflow](Tools-And-Build-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [Mission config/version include graph](Mission-Config-Version-Include-Graph). No gameplay source changed.

## 2026-06-14T06:58:31+02:00 - Codex - Client UI atlas branch route prune

- Claimed `client-ui-atlas-branch-route-prune` as a docs-only Client UI atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `a03a1fb5`: targeted `git diff --name-only b5219d47..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla UI/Rsc paths: `Rsc`, `Client/GUI`, `Init_Client.sqf`, `Client_UpdateRHUD.sqf` and `updateavailableactions.fsm`.
- Refreshed [Client UI systems atlas](Client-UI-Systems-Atlas) so `a03a1fb5` is the visible UI source-continuity checkpoint while older UI hashes remain line-anchor provenance.
- Pruned Branch-Only UI Theme Work: `origin/feat/wf-menu-ops-console` and `origin/feat/buymenu-easa-qol` now route to [Feature status](Feature-Status-Register#partial--deferred--needs-review), [Pending owner decisions](Pending-Owner-Decisions#branch-only-feature-promotion-decisions), [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) and [BuyMenu/EASA QoL branch audit](BuyMenu-EASA-QoL-Branch-Audit) instead of restating branch details locally. No gameplay source changed.

## 2026-06-14T07:08:45+02:00 - Codex - AI/headless gateway FPS route prune

- Claimed `ai-headless-gateway-fps-route-prune` as a docs-only AI/headless/performance gateway cleanup pass, with no gameplay source edits.
- Rechecked current docs head `ca028bff`: targeted `git diff --name-only ee383941..HEAD` checks returned no changes for checked AI/HC/performance paths, and broader `git diff --name-only b9e80da0..HEAD` checks returned no mission-source changes under checked Chernarus or maintained Vanilla roots.
- Refreshed [AI, headless and performance](AI-Headless-And-Performance) and [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) so `ca028bff` is the visible AI/HC source-continuity checkpoint while older AI hashes remain line-anchor provenance.
- Pruned repeated server-FPS publisher detail from the AI gateway: publisher branch shape, hosted/listen no-spin proof and smoke wording now route to [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Testing workflow](Testing-Debugging-And-Release-Workflow) and [Source fix propagation queue](Source-Fix-Propagation-Queue#validation-matrix). No gameplay source changed.

## 2026-06-14T07:18:06+02:00 - Codex - Factory purchase atlas route prune

- Claimed `factory-purchase-atlas-route-prune` as a docs-only Factory and purchase atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `3b911594`: targeted `git diff --name-only 8d611092..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla factory/purchase source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f` and `feat/buymenu-easa-qol` `a66d4691`.
- Refreshed [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) so `3b911594` is the visible source-continuity checkpoint and pruned repeated buy-menu price/key, destroyed-factory refund and queue-risk prose by routing to the existing atlas matrices plus [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup). No gameplay source changed.

## 2026-06-14T07:26:55+02:00 - Codex - Upgrades atlas route prune

- Claimed `upgrades-atlas-route-prune` as a docs-only Upgrades and research atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `1b07716d`: targeted `git diff --name-only d4cfef80..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla upgrade UI, `RequestUpgrade`, server upgrade worker, AI upgrade worker, `Server_HandleSpecial`, upgrade constants/config and `Rsc/Dialogs.hpp` paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f`, `feat/ai-commander` `c20ce153` and `feat/upgrade-queue-stacking` `b061c905`.
- Refreshed [Upgrades and research atlas](Upgrades-And-Research-Atlas) so `1b07716d` is the visible source-continuity checkpoint and pruned repeated AI debit, `upgrade-sync` and stale old upgrade-dialog branch proof by routing to [AI commander autonomy](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix), [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix) and [UI resource parity cleanup](UI-Resource-Parity-Cleanup). No gameplay source changed.

## 2026-06-14T07:35:31+02:00 - Codex - Economy/supply atlas route prune

- Claimed `economy-supply-atlas-route-prune` as a docs-only Economy, towns and supply cleanup pass, with no gameplay source edits.
- Rechecked current docs head `8cb43e4e`: targeted `git diff --name-only 8a6695b8..HEAD` and `6d05cb5a..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla economy/supply constants, resource loop, income display, supply mission, side-supply helper, AI upgrade, kill-bounty and stringtable paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Economy, towns and supply](Economy-Towns-And-Supply) so `8cb43e4e` is the visible source-continuity checkpoint and pruned repeated AI debit, side-supply, supply-mission truck/heli and AI logistics branch proof by routing to [Economy authority first cut](Economy-Authority-First-Cut), [Supply mission architecture](Supply-Mission-Architecture), [AI commander autonomy](AI-Commander-Autonomy-Audit) and [Upgrades and research](Upgrades-And-Research-Atlas). No gameplay source changed.

## 2026-06-14T07:43:19+02:00 - Codex - Support specials authority route prune

- Claimed `support-specials-authority-route-prune` as a docs-only Support specials/tactical modules cleanup pass, with no gameplay source edits.
- Rechecked current docs head `6c919abf`: targeted `git diff --name-only ff8dd884..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla Tactical UI, `RequestSpecial`, artillery, UAV/Nuke/Zeta/MASH, AAR/ordnance, para-ammo and Rsc parameter paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f`, `feat/upgrade-queue-stacking` `b061c905`, `feat/drone-saturation-strike` `8ca4be90` and `feat/recon-uav` `563418ea`.
- Refreshed [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas) so `6c919abf` is the visible support/tactical source-continuity checkpoint. Pruned repeated `RequestSpecial` authority and transport scout prose into [Server authority migration](Server-Authority-Migration-Map), [ICBM authority](ICBM-Authority-Playbook), [Service menu affordability guards](Service-Menu-Affordability-Guards), [AI commander autonomy](AI-Commander-Autonomy-Audit), [Client UI systems](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register) and [Testing workflow](Testing-Debugging-And-Release-Workflow). No gameplay source changed.

## 2026-06-14T07:55:58+02:00 - Codex - Towns/camps atlas route prune

- Claimed `towns-camps-atlas-route-prune` as a docs-only Towns, camps and capture cleanup pass, with no gameplay source edits.
- Rechecked current docs head `5243f91d`: targeted `git diff --name-only 3eefcb00..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla town init, town/camp AI loops, camp helpers, respawn, buy-menu and patrol source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f` and `feat/ai-commander` `c20ce153`.
- Refreshed [Towns, camps and capture](Towns-Camps-And-Capture-Atlas) so `5243f91d` is the visible source-continuity checkpoint. Pruned repeated camp-flag and zero-camp helper branch prose into [Current Branch Scope](Towns-Camps-And-Capture-Atlas#current-branch-scope), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue), while preserving Patrols v2 routing through the atlas and AI runtime pages. No gameplay source changed.

## 2026-06-14T08:09:25+02:00 - Codex - Commander/HQ atlas route prune

- Claimed `commander-hq-atlas-route-prune` as a docs-only Commander/HQ lifecycle cleanup pass, with no gameplay source edits.
- Rechecked current docs head `8c3942d2`: targeted `git diff --name-only f82a9127..HEAD` and `e2c9f6ed..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla commander vote, reassignment, HQ score, disconnect, Objective Ping/task and base-area/HQ authority source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f` and `feat/ai-commander` `c20ce153`.
- Refreshed [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) so `8c3942d2` is the visible source-continuity checkpoint. Pruned repeated manual-reassignment proof into [Commander reassignment call shape](Commander-Reassignment-Call-Shape) and [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), added missing commander-disconnect and HQ build/base-area source anchors, and aligned [Feature status](Feature-Status-Register) plus [Source fix propagation queue](Source-Fix-Propagation-Queue). No gameplay source changed.

## 2026-06-14T08:22:52+02:00 - Codex - Victory/endgame atlas route prune

- Claimed `victory-endgame-atlas-route-prune` as a docs-only Victory/endgame cleanup pass, with no gameplay source edits.
- Rechecked current docs head `a0a86da2`: targeted `git diff --name-only 2f2132f8..HEAD` checks returned no changes for checked Chernarus victory constants, victory loop, live/stale loggers and server-init bind source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Victory/endgame atlas](Victory-And-Endgame-Atlas) so `a0a86da2` is the visible source-continuity checkpoint. Pruned stale `LogGameEnd` and server-init duplicate-bind branch proof into [Dead/stale code register](Dead-Code-And-Stale-Code-Register) plus [Server init bind cleanup](Server-Init-Bind-Cleanup), and added a compact patch-ready row to [Source fix propagation queue](Source-Fix-Propagation-Queue). No gameplay source changed.

## 2026-06-14T08:33:00+02:00 - Codex - Gameplay systems atlas route prune

- Claimed `gameplay-systems-atlas-route-prune` as a docs-only Gameplay Systems atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `2d88dd5a`: targeted `git diff --name-only ca40f202..HEAD` checks returned no changes for checked Chernarus town, town-AI/patrol, economy, commander, construction, factory and victory source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Gameplay systems atlas](Gameplay-Systems-Atlas) so `2d88dd5a` is the visible source-continuity checkpoint. Pruned repeated DR-15 helper-unpacking, Patrols v2, latent `AIBuyUnit` and victory/endgame source prose into [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Towns/camps/capture](Towns-Camps-And-Capture-Atlas), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Factory/purchase systems](Factory-And-Purchase-Systems-Atlas) and [Victory/endgame atlas](Victory-And-Endgame-Atlas). No gameplay source changed.

## 2026-06-14T08:40:44+02:00 - Codex - Function/module index route prune

- Claimed `function-module-index-route-prune` as a docs-only Function and Module index cleanup pass, with no gameplay source edits.
- Rechecked current docs head `6ecac3ae`: targeted `git diff --name-only 1f0b9018..HEAD` checks returned no changes for checked Chernarus common/client/server init, commander helper, AI upgrade, MASH, Reaktiv and paratrooper support source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Function and module index](Function-And-Module-Index) so `6ecac3ae` is the visible source-family checkpoint. Pruned repeated commander DR-15, Reaktiv, MASH and paratrooper branch prose into [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), [Modules atlas](Modules-Atlas), [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [Paratrooper marker revival](Paratrooper-Marker-Revival). No gameplay source changed.

## 2026-06-14T08:47:31+02:00 - Codex - Modules atlas current-scope route prune

- Claimed `modules-atlas-current-scope-route-prune` as a docs-only Modules atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `86244c24`: targeted `git diff --name-only 20a19676..HEAD` checks returned no changes for checked Chernarus common/client/server init, unit-creation, module folders and paratrooper support source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Modules atlas](Modules-Atlas) so `86244c24` is the visible module source-continuity checkpoint. Updated the Reaktiv dormant-module table to current docs head and kept exact branch matrices routed to owner pages except for that compact local module table. No gameplay source changed.

## 2026-06-14T08:53:55+02:00 - Codex - Respawn lifecycle atlas source-scope route prune

- Claimed `respawn-lifecycle-atlas-source-scope-route-prune` as a docs-only Respawn and death lifecycle atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `a640e722`: targeted `git diff --name-only 1f0b9018..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla respawn, MASH, skill, camp/threeway and AI-respawn source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas) so `a640e722` is the visible respawn/MASH source-continuity checkpoint. Updated the MASH branch row to current docs head, replaced duplicate MASH risk-row source detail with links back to the atlas MASH split matrix, and aligned [Feature status](Feature-Status-Register). No gameplay source changed.

## 2026-06-14T09:01:18+02:00 - Codex - Lifecycle entrypoints / wait-chain source-scope route prune

- Claimed `lifecycle-entrypoints-wait-chain-source-scope-route-prune` as a docs-only lifecycle architecture cleanup pass, with no gameplay source edits.
- Rechecked current docs head `05664f17`: targeted `git diff --name-only 9da5f1d0..HEAD` checks returned no changes for checked Chernarus bootstrap, mission-object town init, common/server/client/headless init and HC role-helper source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) and [Lifecycle wait-chain](Lifecycle-Wait-Chain) so `05664f17` is the visible lifecycle source-continuity checkpoint. Routed duplicated branch-scope wording from the wait-chain page back to the entrypoints Source Scope. No gameplay source changed.

## 2026-06-14T09:13:06+02:00 - Codex - Construction/CoIn atlas source-scope route prune

- Claimed `construction-coin-atlas-source-scope-route-prune` as a docs-only Construction and CoIn atlas cleanup pass, with no gameplay source edits.
- Rechecked current docs head `7d248610`: targeted `git diff --name-only 4bd37b98..HEAD` and `1aa178f8..HEAD` checks returned no changes for checked Chernarus and maintained Vanilla construction/CoIn, base-area, structure-config, commander-built ARTY and salvage source paths.
- Verified branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f`.
- Refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas) so `7d248610` is the visible construction/CoIn source-continuity checkpoint. Routed repeated auto-wall, SmallSite, StationaryDefense and salvage branch proof back to the atlas Current Branch Scope, [Construction logic list cleanup](Construction-Logic-List-Cleanup), [Source fix propagation queue](Source-Fix-Propagation-Queue) and the local salvage matrix, and aligned [Feature status](Feature-Status-Register). No gameplay source changed.

## 2026-06-14T09:26:53+02:00 - Codex - Gear/EASA atlas source-scope route prune

- Claimed `gear-loadout-easa-atlas-source-scope-route-prune` to keep the gear/loadout/EASA page as a route-first atlas instead of a second branch-status register.
- Source-checked current docs head `3fdf1898` against the earlier gear/EASA checkpoint `8b71e2a1`; targeted diffs over checked Chernarus, maintained Vanilla and `Tools/LoadoutManager` gear/EASA paths returned no source changes. Branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, perf `0076040f` and BuyMenu/EASA QoL `a66d4691`.
- Result: [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas) now names `3fdf1898` as the visible source-continuity checkpoint and routes repeated profile-template, import-guard, cargo-loop, service/EASA and UI IDD branch proof to [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Service menu affordability guards](Service-Menu-Affordability-Guards), [UI IDD collision repair](UI-IDD-Collision-Repair) and [BuyMenu EASA QoL branch audit](BuyMenu-EASA-QoL-Branch-Audit). [Feature status](Feature-Status-Register) is aligned. No gameplay source changed. Early `docs/validate-wiki.ps1` and touched JSON/JSONL parse checks passed; final mirror/parity checks run with the batch.

## 2026-06-14T09:36:34+02:00 - Codex - Marker cleanup atlas source-scope route prune

- Claimed `marker-cleanup-atlas-source-scope-route-prune` to keep the marker/object-lifecycle cleanup page as the canonical route for empty supply-truck timeout evidence.
- Source-checked current docs head `7eea6b6c` against the earlier marker/cleanup checkpoint `634a907b`; targeted diffs over checked Chernarus and maintained Vanilla marker, cleaner, restorer and empty-vehicle paths returned no source changes. Branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and perf `0076040f`.
- Result: [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas) now names `7eea6b6c` as the visible marker/cleanup source-continuity checkpoint. Repeated empty supply-truck 24-hour timeout proof now routes to the atlas [Empty Supply Truck Branch Matrix](Marker-Cleanup-Restoration-Systems-Atlas#empty-supply-truck-branch-matrix), while [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) carry compact route-first rows. No gameplay source changed.

## 2026-06-14T09:43:52+02:00 - Codex - Networking/PV gateway source-scope route prune

- Claimed `networking-pv-gateway-source-scope-route-prune` to keep [Networking and public variables](Networking-And-Public-Variables) as a transport/trust-boundary gateway instead of a duplicate PVF branch matrix.
- Source-checked current docs head `1e16527b` against the earlier network checkpoint `4277a2ad`; targeted diffs over checked Chernarus and maintained Vanilla network, PVF and direct-channel paths returned no source changes. Branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and perf `0076040f`.
- Result: Networking now names `1e16527b` as the visible network/PVF source-continuity checkpoint, keeps older `4277a2ad` / `8701aacc` / `59deb306` as provenance, and routes repeated dispatch-time `Call Compile` proof to [Current Branch Scope](Networking-And-Public-Variables#current-branch-scope), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook) and [Server authority migration map](Server-Authority-Migration-Map). No gameplay source changed.

## 2026-06-14T09:53:29+02:00 - Codex - SQF atlas current source-scope route prune

- Claimed `sqf-atlas-current-source-scope-route-prune` to keep [SQF code atlas](SQF-Code-Atlas) as a compile/source ownership map rather than a duplicate PVF or disabled-compile branch-status page.
- Source-checked current docs head `94b09c73` against the earlier SQF atlas checkpoints `34212d6a` and `4277a2ad`; targeted diffs over checked Chernarus and maintained Vanilla PVF, bootstrap, common/client/server/headless init, AI supply-truck, server-FPS, MASH marker, `SEND_MESSAGE`, `AttackWave`, `SetTask` and `LogGameEnd` paths returned no source changes. The compile count command still returns `738` total `preprocessFile` references, `460` `preprocessFileLineNumbers`, `278` plain `preprocessFile` and `22` commented references. Branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and perf `0076040f`.
- Result: SQF code atlas now names `94b09c73` as the visible compile/source-continuity checkpoint while preserving the original `04a60e43` count snapshot as provenance. Repeated PVF no-drift proof now routes back to the compile summary plus [Public variable channel index](Public-Variable-Channel-Index), [Networking and public variables](Networking-And-Public-Variables) and [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), and local PVF dispatch risk now has explicit `Server_HandlePVF.sqf:14` / `Client_HandlePVF.sqf:22` anchors. No gameplay source changed.

## 2026-06-14T10:01:35+02:00 - Codex - Architecture overview current source-scope route prune

- Claimed `architecture-overview-current-source-scope-route-prune` to keep [Architecture overview](Architecture-Overview) as the top owner-route gateway rather than a stale docs-head checkpoint.
- Source-checked current docs head `2de2de92` against the earlier architecture overview checkpoint `adb9dbc8` and broader source checkpoint `4277a2ad`; targeted diffs over cited runtime, bootstrap and LoadoutManager tooling paths returned no source changes. Branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and perf `0076040f`.
- Result: Architecture overview now names `2de2de92` as the visible source-continuity checkpoint while preserving earlier `adb9dbc8`, `4277a2ad`, `1bef8801` and `1aa178f8` provenance. The Current Branch Scope row now explicitly covers runtime/bootstrap/tooling anchors and routes branch behavior, line drift and smoke gates to linked subsystem owner pages. No gameplay source changed.

## 2026-06-14T10:09:14+02:00 - Codex - Server runtime operations current source-scope route prune

- Claimed `server-runtime-operations-current-source-scope-route-prune` to keep [Server runtime and operations](Server-Runtime-And-Operations) as a short gateway instead of a stale docs-head checkpoint.
- Source-checked current docs head `f74b3822` against earlier server-runtime checkpoints `a6785f51` and `4277a2ad`; targeted diffs over checked Chernarus and maintained Vanilla `Init_Server.sqf`, server FSM/module paths, `Server_SideMessage.sqf`, `Server_OnHQKilled.sqf` and server-FPS publisher paths returned no source changes. Branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and perf `0076040f`.
- Result: Server runtime and operations now names `f74b3822` as the visible server-runtime source-continuity checkpoint while preserving `a6785f51`, `4277a2ad`, `92c5cf05` and `6afcc58e` provenance. Branch-sensitive AI supply-truck startup, Patrols v2 and FPS publisher cleanup remain routed to [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors). No gameplay source changed.

## 2026-06-14T10:17:44+02:00 - Codex - Client UI atlas current source-scope route prune

- Claimed `client-ui-atlas-current-source-scope-route-prune` to keep [Client UI systems atlas](Client-UI-Systems-Atlas) as a current source-backed UI route map rather than a stale docs-head checkpoint.
- Source-checked current docs head `68bd4dc5` against earlier UI atlas checkpoints `a03a1fb5` and `b5219d47`; targeted diffs over checked Chernarus and maintained Vanilla `description.ext`, `Rsc`, `Client/GUI`, `Init_Client.sqf`, `Client_UpdateRHUD.sqf`, client action/marker FSMs and core UI helper paths returned no source changes. Branch refs still resolve to stable `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74`, perf `0076040f`, `wf-menu-ops-console` `0767c0b5` and BuyMenu/EASA QoL `a66d4691`.
- Result: Client UI systems atlas now names `68bd4dc5` as the visible UI/Rsc source-continuity checkpoint while preserving `a03a1fb5`, `b5219d47`, `a71b42fe`, `2fef1e3d` and `f7bc72a8` provenance. Detailed resource parity, title-handle, vote/help/router, clickable-text and branch-only UI behavior remains routed to owner pages. No gameplay source changed.

## 2026-06-15T11:07:15+02:00 - Codex - Deploy AI commander Experital merge-risk audit

- Claimed `deploy-aicom-experital-merge-risk-audit` from Steff's request to work the `deploy/2026-06-12-aicom-experital` branch and report on GitHub every 30 minutes.
- Operating scope: source-backed Arma 2 OA SQF review of `deploy/2026-06-12-aicom-experital@984195ae` against `origin/master@cf2a6d6a`, `origin/release/2026-06-feature-bundle@a96fdda2`, `origin/experital` and PR #34. Initial focus is AI commander, wildcard events, marker/performance loops, server FSM/PVF edges and merge-risk deltas.
- Coordination note: Claude leads branch implementation. Codex is auditing/reporting first; any gameplay code change candidate will be posted as a proposed-change notice with source paths and branch refs before edits. GitHub issue tracking is disabled, so broad status uses PR #30 unless a narrower target is chosen.

## 2026-06-16T20:30:23+02:00 - Codex - Wiki mirror current wiki sync

- Claimed `wiki-mirror-current-wiki-sync` after fetching the standalone wiki to `origin/master@3745638` and finding `35` top-level SHA256 drift candidates against the repo `docs/wiki` mirror on `docs/developer-wiki-index@e2d994246`.
- Scope is docs-only mirror reconciliation: copy current human-wiki pages into `docs/wiki`, keep coordination records compact, validate JSON/JSONL/wiki links where practical and avoid gameplay source edits.
- Result: mechanical mirror copy touched only `docs/wiki` files in the repo mirror and the standalone wiki coordination log. No mission source files changed.
- Validation passed: `docs/validate-wiki.ps1`, touched JSON/JSONL parse, `git diff --check` in both worktrees and full top-level wiki/docs normalized-content parity (`diffCount=0`). The validator emitted only the known non-failing legacy JSONL envelope warnings.

## 2026-06-16T20:38:47+02:00 - Codex - AICOM PR board current-state refresh

- Claimed `aicom-pr-board-current-state-refresh` after GitHub PR metadata showed [PR cleanup and integration lab](PR-Cleanup-And-Integration-Lab) still presented PR #8 and PR #14 as open release/test candidates.
- Source scope: `gh pr list --repo rayswaynl/a2waspwarfare --state open --limit 100 --json number,title,headRefName,baseRefName,isDraft,updatedAt,url` plus `gh pr view 8` and `gh pr view 14`. PR #8 is merged from `release/2026-06-feature-bundle` into `master` at 2026-06-09T07:47:34Z; PR #14 is merged from `feat/ai-commander` into `master` at 2026-06-10T13:40:19Z.
- Result: PR cleanup lab now routes current AICOM/Experital work through PR #35 as the `deploy/2026-06-12-aicom-experital` -> `master` umbrella, treats PR #34 and PR #36-#41 as deploy-child/review/note lanes, adds current rows for PR #20/#21/#29-#41 and preserves active `deploy-aicom-experital-merge-risk-audit` coordination. No gameplay source changed.
- Validation passed: `docs/validate-wiki.ps1`, touched JSON/JSONL parse, `git diff --check` and docs/wiki mirror parity after copying to the standalone wiki checkout. The wiki validator emitted only the known non-failing legacy JSONL envelope warnings.

## 2026-06-16T21:32:45+02:00 - Codex - GUER insurgents branch intake

- Claimed `guer-insurgents-branch-intake` from the Brain-ready handoff at `C:\Users\Chill\Documents\Codex\2026-06-16\look-for-work-in-brain-3\outputs\Guer-Insurgents-Branch-Intake.md`, after confirming the wiki mirror sync lane was complete and both docs/wiki plus standalone wiki worktrees were clean.
- Source-checked `origin/feat/guer-insurgents-faction@41550bd33` against `origin/master@cf2a6d6a`: merge-base `cf2a6d6a`, `462` changed files, `25816` insertions, `2249` deletions, `241` Chernarus mission paths and `208` maintained Vanilla paths. `git diff --check origin/master..origin/feat/guer-insurgents-faction` still reports blank-EOF/trailing-whitespace failures, including `Server/Functions/AI_Commander_Wildcard.sqf:1055,1085,1094,1102,1113`.
- Result: [Gameplay systems atlas](Gameplay-Systems-Atlas#merged-guer-insurgents-source-status-and-historical-intake) now owns the detailed branch-intake matrix; [Feature status](Feature-Status-Register) carries a compact broad Chernarus-first branch-review row; [Testing workflow](Testing-Debugging-And-Release-Workflow#branch-only-feature-smoke-pack) and `agent-release-readiness.json` now carry planned GUER smoke gates. No gameplay source changed.

## 2026-06-21T10:16:13+02:00 - Codex - Default gear template content catalog

- Claimed `default-gear-template-content-catalog` after verifying the wiki covers gear-template profile bugs but does not catalog the shipped predefined template content itself.
- Source scope: clean `master@0139a346`, `Common/Config/Loadout/Loadout_*.sqf`, `Common/Config/Config_SetTemplates.sqf`, `Common/Config/readme.txt`, `Client/GUI/GUI_BuyGearMenu.sqf`, `Client/Functions/Client_UI_Gear_FillTemplates.sqf` and `Client_UI_Gear_ParseTemplateContent.sqf`.
- Planned result: one docs-only page, `Default-Gear-Template-Content-Catalog`, with source-cited tables showing that current master ships one empty seed template per loadout file and derives any visible price/label/upgrade behavior at runtime. No gameplay source changes planned.

## 2026-06-21T10:25:25+02:00 - Codex - Default gear template content catalog complete

- Result: added [Default gear template content catalog](Default-Gear-Template-Content-Catalog), wired it into [Home](Home), `_Sidebar.md` and `agent-context.json`, and left gameplay source untouched.
- Source proof: clean `master@0139a346`; all ten `Common/Config/Loadout/Loadout_*.sqf` files ship the same empty predefined template seed and `Config_SetTemplates.sqf` keeps only the first per-side seed unless the caller passes the third `false` parameter.
- Validation: citation line scan passed, A3-only term scan clean, JSON/JSONL parse passed, `git diff --check` passed with only normal Windows LF/CRLF warnings, and `Tools/ValidateWiki.ps1 -WikiPath <wiki> -SkipGitDiffCheck` reached `[OK] markdown links resolve` plus `[OK] agent-context page lists match wiki mirror` before the known pre-existing machine-reference failure.

## 2026-06-21T10:16:11+02:00 - Codex - Gear store price and upgrade catalog

- Claimed `gear-store-price-upgrade-catalog` after checking that [Gear, loadout and EASA atlas](Gear-Loadout-And-EASA-Atlas) maps the runtime/config flow but does not publish a gear-store content catalog; [Commanders handbook](Commanders-Handbook) only gives two coarse gear-level examples.
- Scope is one source-cited docs-only page for current `master` Chernarus high-impact player gear-store prices and upgrade gates, sourced from `Common/Config/Gear/Gear_*.sqf`, then wired through sidebar, Home and `agent-context.json`. No gameplay source edits planned.
- Result: added [Gear store price and upgrade catalog](Gear-Store-Price-And-Upgrade-Catalog) for current `master@0139a346` Chernarus gear rows with price `>= 300` or gear level `>= 4`; the documented table reconciles to `68` qualifying source rows with no missing or extra rows.
- Validation: reopened every citation against `Missions/[55-2hc]warfarev2_073v48co.chernarus`, checked forbidden Arma 3-only constructs, confirmed all local wiki links resolve after repairing three stale temporary-path links in [Artillery reference](Artillery-Reference-Per-Faction#continue-reading), confirmed `agent-context.json` page-list parity and ran `git diff --check`.

## 2026-06-21T10:15:50+02:00 - Codex - Earplugs audio toggle reference

- Claimed `earplugs-audio-toggle-reference` after verifying no existing wiki markdown page covered `EarplugToggle`, `WFBE_WASP_Earplug*` variables or the current `fadeSound` / `fadeRadio` earplug behavior.
- Source-checked stable `master@0139a346` Chernarus paths: `WASP/actions/AddActions.sqf`, `WASP/actions/EarplugToggle.sqf`, `Client/GUI/GUI_Menu.sqf`, `Rsc/Dialogs.hpp`, `briefing.html`, `Client/GUI/GUI_Menu_Help.sqf`, respawn and skin-selector re-add paths.
- Result: [Earplugs audio toggle](Earplugs-Audio-Toggle-Reference) now documents the split between the WASP scroll/vehicle path (`WFBE_WASP_EarplugActive`, `fadeSound` plus `fadeRadio`) and the WF menu `EAR` path (`WFBE_Earplugs`, `fadeSound` only). [WASP overlay](WASP-Overlay) now routes earplugs instead of saying only HQ recovery is active from `AddActions.sqf`. No gameplay source changed.

## 2026-06-21T10:16:25+02:00 - Codex - Gear store loadout route catalog

- Claimed `gear-store-loadout-route-catalog` as a docs-only coverage-gap page after verifying existing gear pages describe runtime/data-model defects and the price catalog covers high-impact price/gate rows, but neither catalogs side-root loadout imports, row counts and dynamic/gated gear coverage together.
- Source scope: current source `master@0139a346`, Chernarus mission `Common/Config/Gear`, `Common/Config/Loadout`, `Common/Config/Core_Root` and the `Config_Weapons`, `Config_Magazines`, `Config_Backpack`, `Config_SetTemplates`, `Config_SortWeapons` and `Config_SortMagazines` helpers.
- Result: added [Gear store loadout route catalog](Gear-Store-Loadout-Route-Catalog) as a source-cited Chernarus `master@0139a346` content catalog for side-root loadout imports, loadout row counts, price/gate extrema and config-gated/dynamic gear content. Citation ranges, numeric counts/prices/gates, internal links and Arma 2-only language were checked before wiring the page into Home, sidebar, `agent-context.json` and [Gear store price and upgrade catalog](Gear-Store-Price-And-Upgrade-Catalog). No gameplay source changed.

## 2026-06-21T10:49:29+02:00 - Codex - AutoFlip vehicle recovery reference

- Claimed `autoflip-vehicle-recovery-reference` after confirming AutoFlip is only covered by a compact Modules Atlas row and historical mentions, not a dedicated live-feature page.
- Source scope: clean `master@0139a346`, `Client/Module/AutoFlip/AutoFlip.sqf`, `Client/Init/Init_Client.sqf`, `Common/Init/Init_Unit.sqf`, `WASP/actions/FlipVehicle.sqf` and `stringtable.xml`.
- Planned result: one docs-only page, `AutoFlip-Vehicle-Recovery-Reference`, with source-cited tables for automatic stuck-vehicle recovery and the separate manual Flip Vehicle action. No gameplay source changes planned.

## 2026-06-21T10:53:03+02:00 - Codex - AutoFlip vehicle recovery reference complete

- Result: added [AutoFlip vehicle recovery](AutoFlip-Vehicle-Recovery-Reference), wired it into [Home](Home), `_Sidebar.md` and `agent-context.json`, and left gameplay source untouched.
- Source proof: clean `master@0139a346`; AutoFlip starts from client init, scans the player's mounted vehicle and mounted group vehicles, requires the documented tilt/speed/ground/water/cooldown/stuck gates, rights vehicles with `setVectorUp`, `setPos` and `setVelocity`, and is separate from the manual tank/car **Flip Vehicle** action.
- Validation: reopened every citation against the Chernarus mission source, checked forbidden Arma 3-only constructs, confirmed local wiki links resolve, confirmed `agent-context.json` page-list parity and ran `git diff --check`.

## 2026-06-21T10:48:46+02:00 - Codex - CIPHER sort utilities reference

- Claimed `cipher-sort-utilities-reference` after confirming [Modules atlas](Modules-Atlas#cipher--stringarray-sort-utility-commonmodulecipher-by-benny) only gives a route-level CIPHER summary and no dedicated page owns the helper contracts, upgrade-label sort output or reverse-helper typo.
- Scope is one source-cited docs-only page for current `master@0139a346` Chernarus CIPHER helpers and their active call site: `Common/Module/CIPHER/CIPHER_Init.sqf`, `Common/Module/CIPHER/CIPHER_Sort.sqf`, `Common/Config/Core_Upgrades/Labels_Upgrades.sqf` and `Common/Init/Init_Common.sqf`. No gameplay source edits planned.
- Result: [CIPHER sort utilities reference](CIPHER-Sort-Utilities-Reference) documents the helper contracts, the `WFBE_C_UPGRADES_SORTED` build and the Upgrade menu consumer path, routes from Home/sidebar/agent-context plus the module owner pages, and corrects the stale [Modules atlas](Modules-Atlas#cipher--stringarray-sort-utility-commonmodulecipher-by-benny) `Labels_Upgrades.sqf:127` reference to current line `133`.
- Validation: source citation range check passed for `29` page refs, local wiki links resolve, `agent-context.json` documentation pages match `187` top-level markdown pages, A3-only token scan for the new page returned no matches, JSON/JSONL parse passed, repo `docs/wiki` validator passed after mirror sync and `git diff --check` passed with line-ending warnings only.

## 2026-06-21T10:54:11+02:00 - Codex - Operator monitor and CPU affinity tools reference

- Claimed `operator-monitor-cpu-affinity-tools-reference` after verifying the wiki mentions RPT/performance workflows broadly but has no dedicated page for `Tools/Monitor/Get-WindowedRpt.ps1` or `Tools/Ops/Set-WaspCpuAffinity.ps1`.
- Source-checked clean `master@0139a346` repo-root paths: `Tools/Monitor/Get-WindowedRpt.ps1`, `Tools/Ops/Set-WaspCpuAffinity.ps1` and `docs/testing/hc-scaling-test.md`.
- Result: [Operator monitor and CPU affinity tools](Operator-Monitor-And-CPU-Affinity-Tools-Reference) now documents the RPT windowing parameters, non-locking `FileShare.ReadWrite` read, optional regex/tail filtering, dry-run-first affinity masks, `arma2oaserver.exe` / `ArmA2OA.exe -client` process targeting, connection-order HC masks and the not-applied live-host caution. Routed through [Home](Home), `_Sidebar.md` and `agent-context.json`. No gameplay source changed.
- Validation: 54 citation ranges resolve against clean source, internal page links resolve, forbidden Arma 3-only token scan is clean, touched JSON/JSONL parse passes, `docs/validate-wiki.ps1` passes after mirroring the wiki into `docs/wiki` and `git diff --check` reports only normal Windows LF/CRLF warnings.

## 2026-06-21T12:22:01+02:00 - Codex - Skin selector class swap reference

- Claimed `skin-selector-class-swap-reference` after confirming the wiki had no dedicated Skin Selector page and only incidental mentions of skin-selector action restoration in [Earplugs audio toggle](Earplugs-Audio-Toggle-Reference).
- Source scope: clean `master@0139a346`, canonical Chernarus `Common/Init/Init_CommonConstants.sqf`, `Rsc/Dialogs.hpp`, `Client/GUI/GUI_Menu.sqf`, `Client/GUI/GUI_SkinSelectorMenu.sqf`, `Client/Init/Init_Keybind.sqf`, `Client/Module/Skill/Skill_Init.sqf`, `Client/Functions/Client_OnRespawnHandler.sqf`, `Common/Functions/Common_CreateUnit.sqf`, `WASP/actions/SkinSelector/*` and representative maintained Vanilla parity paths.
- Result: added [Skin selector and class swap](Skin-Selector-And-Class-Swap-Reference), documenting the default-off gate, hidden WF-menu shortcut, join/WF-menu/User11 openers, WEST/EAST class pools, Spotter-only ghillie filter, replacement-player apply lifecycle, handler/action restore, commander build-action restore and respawn persistence. Wired Home, sidebar, Player UI workflow, Player skill abilities, WASP overlay, Feature Status and `agent-context.json`. No gameplay source changed.
- Validation: 49 source refs in the new page resolve against clean source, touched-page internal links resolve, `agent-context.json` page-list parity is `205/205`, JSON/JSONL parse checks pass, `git diff --check` reports only normal Windows LF/CRLF warnings, and this clean source checkout has no `docs/wiki` mirror or wiki validator script to run.

## 2026-06-21T12:17:46+02:00 - Codex - Player vehicle and travel actions reference

- Claimed `player-vehicle-travel-actions-reference` after verifying current wiki coverage is scattered: MHQ/camp repair has owner-page coverage, but Push, Taxi Reverse, HALO, Cargo Eject and basic lock/unlock behavior are mostly one-line route mentions.
- Source scope: clean `master@0139a346`, Chernarus `Common/Init/Init_Unit.sqf`, `Client/Action/Action_Push.sqf`, `Action_TaxiReverse.sqf`, `Action_HALO.sqf`, `Action_EjectCargo.sqf`, `Action_ToggleLock.sqf`, `Action_ToggleMHQLock.sqf`, `Client/PVFunctions/SetVehicleLock.sqf`, `SetMHQLock.sqf` and `Server/PVFunctions/RequestVehicleLock.sqf`.
- Planned result: one docs-only page, `Player-Vehicle-And-Travel-Actions-Reference`, with source-cited registration/effect tables and Continue Reading routes to Valhalla, AutoFlip, vehicle countermeasures, Commander/HQ lifecycle and Player skill abilities. No gameplay source changes planned.
- Result: added [Player vehicle and travel actions](Player-Vehicle-And-Travel-Actions-Reference), wired it through [Home](Home), `_Sidebar.md`, [AutoFlip vehicle recovery](AutoFlip-Vehicle-Recovery-Reference), [Valhalla vehicle climbing-assist](Valhalla-Vehicle-Climbing-Assist), [Player UI workflow](Player-UI-Workflow-Map) and `agent-context.json`, and left gameplay source untouched. The stable `master` source tree has no `docs/wiki` mirror directory, so no repo mirror files were touched in this pass.
- Validation: 48 citation ranges resolve against clean Chernarus source, touched internal links resolve, A3-only token scan is clean, touched JSON/JSONL parse passes, `agent-context.json` page count matches top-level markdown page count, and `git diff --check` reports only normal Windows LF/CRLF warnings.

## 2026-06-21T12:23:23+02:00 - Codex - Engine stealth fuel toggle reference

- Claimed `engine-stealth-fuel-toggle-reference` after confirming `Client/Module/Engines` had live source files, current audit notes and only a compact [Modules atlas](Modules-Atlas#engines--stealth-engine-off-clientmoduleengines) summary, with no dedicated owner page.
- Source-checked clean `master@0139a346` Chernarus paths: `Client/Module/Engines/Engine.sqf`, `Startengine.sqf`, `Stopengine.sqf`, `Client/Functions/Client_BuildUnit.sqf`, `Server/Init/Init_Server.sqf` and `Client/Functions/Client_SupportRefuel.sqf`.
- Result: added [Engine stealth fuel toggle](Engine-Stealth-Fuel-Toggle-Reference) as a source-cited reference for the `STEALTH ON` / `STEALTH OFF` flow, vehicle state keys `ID` / `Fuel` / `stopped`, purchased tank/wheeled-APC attach, WASP extra start-vehicle attach and the refuel-service guard. Routed through [Home](Home), `_Sidebar.md`, [Modules atlas](Modules-Atlas), [Function and module index](Function-And-Module-Index) and `agent-context.json`. No gameplay source changed.
- Validation: 27 source citation ranges resolve, internal links resolve, Arma 3-only token scan is clean, touched JSON/JSONL parse passes, standalone wiki validator reaches markdown link/page-list OK before the known machine-reference failure, current repo `docs/wiki` validator passes with known legacy JSONL warnings only, and `git diff --check` passes with line-ending warnings only.

## 2026-06-21T12:42:33+02:00 - Codex - Engine stealth fuel toggle rebase enhancement

- Rebased over parallel wiki commits that had already published the canonical [Engine stealth fuel toggle](Engine-Stealth-Fuel-Toggle-Reference) page; dropped the duplicate local `Engine-Stealth-Toggle-Reference` slug and kept all navigation/context on the canonical page.
- Enhancement: added the `"stopped"` mission-variable caveat to separate it from unrelated Arma `stopped` command hits, plus a compact Smoke Targets table for action visibility, fuel-drain, fuel-restore/refuel-guard and WASP extra start-vehicle checks.
- Validation: the enhanced canonical page now resolves `40` source citation ranges against clean `master@0139a346`; local links, JSON/JSONL, page-list parity, Arma 3-only token scan and `git diff --check` were rerun after rebase resolution.

## 2026-06-21T12:51:02+02:00 - Codex - QoL trio player hints reference

- Claimed `qol-trio-player-hints-reference` after verifying existing wiki coverage only indexed the QoL constants and scattered consumer line refs, without a canonical page for the live client-visible hint surfaces.
- Source scope: clean `master@0139a346`, Chernarus `Common/Init/Init_CommonConstants.sqf`, `Client/Init/Init_Client.sqf`, `Client/FSM/updatesalvage.sqf`, `Client/GUI/GUI_Menu_BuyUnits.sqf`, `Client/Functions/Client_FNC_Special.sqf` and `Client/Functions/Client_QOL_Advisor.sqf`.
- Result: added [QoL trio player hints](QoL-Trio-Player-Hints-Reference), documenting the master gates, salvage toast, upgrade banner/sound split, last-purchase timestamp coupling and advisor nudges, then wired Home, sidebar, Player UI workflow, Experimental feature flags and `agent-context.json`. No gameplay source changed.
- Validation: source citation ranges resolve against clean Chernarus source, touched internal links resolve, A3-only token scan is clean, touched JSON/JSONL parse passes, `agent-context.json` page count matches top-level markdown page count, and `git diff --check` reports only normal Windows LF/CRLF warnings. The stable source tree has no `docs/wiki` mirror or wiki validator script.

## 2026-06-21T17:27:47+02:00 - Codex - Wiki mirror current wiki sync

- Claimed `wiki-mirror-current-wiki-sync-2026-06-21` after comparing live wiki `master@743daf4` with repo mirror branch `origin/docs/developer-wiki-index@11f535d9` and finding `116` top-level normalized-content differences.
- Scope: reconcile the repo `docs/wiki` mirror to the current GitHub wiki checkout, then validate parity and JSON/JSONL. No gameplay source edits planned.
- Result: copied `260` top-level wiki files into `docs/wiki`, removed the mirror-only `GUER-Insurgents-Branch-Audit.md`, and updated coordination records so the current human wiki and repo mirror carry the same top-level content again. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; the required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, normalized wiki/docs parity and `git diff --check`.

## 2026-06-21T17:38:27+02:00 - Codex - cf2 source stamp current-head caveat

- Claimed `cf2-source-stamp-current-head-caveat` after fetching clean source/wiki/docs worktrees and confirming `cf2a6d6a4` is an ancestor of current `origin/master@0139a346`.
- Scope: docs-only correction for broad page headers that still used the `cf2a6d6a4` master stamp, so they read as then-current/historical master evidence with a current-head recheck caveat. No gameplay source edits planned.
- Planned validation: mirror touched wiki pages into `docs/wiki`, parse touched JSON/JSONL, run the wiki validator, verify wiki/docs parity and run `git diff --check`.
- Result: updated `38` source-verification headers to preserve `cf2a6d6a4` as then-current/historical master evidence while warning that current `origin/master` is `0139a346`; also changed the [Player skill abilities](Player-Skill-Abilities-Reference) Officer/MASH note to snapshot wording so its stale line refs are not current-head proof.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, normalized touched-file wiki/docs parity and `git diff --check`.

## 2026-06-21T17:31:00+02:00 - Codex - Wiki mirror and GUER current-source sync

- Claimed `wiki-mirror-and-guer-current-source-sync` after the broad mirror sync removed the docs-only GUER audit, then source-checked whether that useful page should stay deleted or return in corrected form.
- Scope: docs-only mirror reconciliation plus source-backed GUER status correction. Used a clean temporary wiki worktree so the existing dirty standalone checkout was not touched.
- Result: rebased over live wiki `master@e4fc668`, restored the docs-only [GUER Insurgents branch audit](GUER-Insurgents-Branch-Audit) as a source-refreshed wiki page, rewrote it against current `origin/master@0139a346`, and aligned [Feature status](Feature-Status-Register), [Gameplay systems atlas](Gameplay-Systems-Atlas), `_Sidebar.md` and `agent-context.json`. No gameplay source changed.
- Source proof: `9af83596` is an ancestor of `origin/master@0139a346`; `git grep` finds `WFBE_C_GUER_PLAYERSIDE`, `Root_GUE_PlayerOverlay`, `Server_GuerStipend`, `Action_GuerVbiedDetonate` and `guer-vbied-detonate` in both maintained roots, correcting the stale Chernarus-only/Takistan-dormant wording.
- Validation: JSON/JSONL parse passed in both the repo mirror and clean wiki worktree; `docs/validate-wiki.ps1` passed with known legacy JSONL warnings only; `git diff --check` passed in both worktrees with LF/CRLF warnings only; final wiki/docs SHA parity is `261` files each with `0` missing and `0` differing common files.

## 2026-06-21T17:43:28+02:00 - Codex - ClickableText soundPush current stable closeout

- Claimed `clickabletext-soundpush-current-stable-closeout` after the current-source check showed the old patch-ready matrix was stale: `origin/master@0139a346` now keeps valid `RscClickableText.soundPush[] = {"", 0.2, 1};` at `Rsc/Ressources.hpp:556` in both maintained roots.
- Source evidence: Chernarus blame points to `1a5e0b40` (`fix(experital): malformed soundPush array in RscClickableText`); maintained Vanilla blame points to `9b49883c` (`chore: regenerate Takistan + generated files via Tools/LoadoutManager`). Current master has no maintained-root `{, 0.2, 1}` hit and still derives 14 `RscClickableText` controls per root at the refreshed `Rsc/Dialogs.hpp` line refs.
- Result: refreshed [Client UI systems](Client-UI-Systems-Atlas#clickable-text-soundpush-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable is source-present/smoke-pending, while older docs/source, Miksuu, perf, release and UI theme evidence remains branch-scoped until rechecked or merged. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, wiki/docs parity for touched files and `git diff --check`.

## 2026-06-21T17:41:55+02:00 - Codex - Source fix queue docs-source refresh

- Claimed `source-fix-queue-docs-head-refresh-2026-06-21` after the mirror sync advanced the docs branch to `docs/developer-wiki-index@4c01dfb7` while [Source fix propagation queue](Source-Fix-Propagation-Queue) still used `4bd37b98` as the propagation source anchor.
- Source check: `git diff --name-only 4bd37b98..4c01dfb7` returned no changes for the queue's checked propagation path families: public-variable init, client init, FPS publishers, supply mission start/player list, commander ARTY construction/discovery in Chernarus and maintained Vanilla, plus LoadoutManager root discovery.
- Result: added a compact docs-source refresh note and Agent Index fact update to [Source fix propagation queue](Source-Fix-Propagation-Queue), preserving `4bd37b98` as line-anchor proof while making the current mirror head explicit. No gameplay source changed.

## 2026-06-21T17:47:40+02:00 - Codex - PR board AICOM closure refresh

- Claimed `pr-board-aicom-closure-refresh-2026-06-21` after `gh pr list --repo rayswaynl/a2waspwarfare --state all --limit 80` showed the 2026-06-16 AICOM deploy stack had closed or merged: PR #29 and #31 merged on 2026-06-17, PR #35 and deploy-child PR #34/#36-#39/#41 are closed, PR #43 is the new open master-target soak/proposals PR, PR #40 remains open on closed base `fix/aicom-review-batch-2026-06-15`, and PR #9 remains open.
- Scope: docs-only refresh of [PR cleanup and integration lab](PR-Cleanup-And-Integration-Lab), dashboard/current-lane routing and machine coordination records. No gameplay source edits planned.
- Planned validation: mirror touched wiki pages into `docs/wiki`, parse touched JSON/JSONL, run the wiki validator, verify touched-file parity and run `git diff --check`.
- Result: refreshed the PR cleanup lab and Progress Dashboard so PR #35 plus deploy-child PR #34/#36-#39/#41 are closed historical AICOM deploy evidence, PR #29/#31 are merged history, PR #43 is the live master-target soak/proposals route, PR #40 is open but stacked on a closed base, and PR #9 remains separate map/content work. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, stale live-lane string scan and `git diff --check`.

## 2026-06-21T17:41:14+02:00 - Codex - ICBM launched PVEH branch-scope refresh

- Claimed `icbm-launched-pveh-branch-scope-refresh` to tighten the dead/stale-code row for the receiver-only `ICBM_launched` PVEH without touching gameplay source.
- Source scope: `docs/developer-wiki-index@4c01dfb`, `origin/master@0139a346`, `upstream/master@b8389e74` and `origin/perf/quick-wins@0076040f`, checked across Chernarus source and maintained Vanilla. `git ls-remote --heads origin release/*` returned no current release heads on 2026-06-21.
- Planned result: refresh [Dead/stale code register](Dead-Code-And-Stale-Code-Register) with exact refs, current `RequestSpecial "ICBM"` / `HandleSpecial "icbm-display"` route anchors and an explicit owner-decision handoff. No gameplay source edits planned.
- Result: refreshed the receiver-only `ICBM_launched` row, the P1 backlog row and the revive-candidate row with exact refs, no-sender evidence, current nuke-route line drift and an explicit absent-release-head caveat. Dashboard, pruning ledger and machine records were updated; no gameplay source changed.
- Validation: JSON/JSONL parse passed, `docs/validate-wiki.ps1` passed with pre-existing legacy JSONL warnings only, touched-file docs/wiki to wiki-checkout parity was verified after mirroring, and `git diff --check` passed with line-ending warnings only.

## 2026-06-21T18:04:28+02:00 - Codex - HQ score current stable refresh

- Claimed `hq-score-current-stable-refresh` after the DR-50 Feature Status and Source Fix queue rows still treated older `origin/master@cf2a6d6a` stable evidence as current, while the fetched stable branch is `origin/master@0139a346`.
- Source evidence: current Chernarus and maintained Vanilla both keep `_points = 30000 / 100 * WFBE_C_BUILDINGS_SCORE_COEF` at `Server/Functions/Server_OnHQKilled.sqf:23`, award the generic score at `:52` / `:54`, gate only the second `_score = 900` bounty at `:80`, set it at `:83`, award it at `:86`, and keep `WFBE_C_BUILDINGS_SCORE_COEF = 3` at `Common/Init/Init_CommonConstants.sqf:529`.
- Result: refreshed [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas#hq-kill-score-and-bounty-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable is explicitly still patch-ready/current-stable-unpatched, while older docs/Miksuu/perf/release/feat-ai rows stay branch-scoped. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, source evidence probe and `git diff --check`.

## 2026-06-21T17:54:00+02:00 - Codex - Map boundaries current-head refresh

- Claimed `map-boundaries-current-head-refresh` after the cf2 stamp caveat batch left [Map boundaries and off-map enforcement](Map-Boundaries-And-Offmap-Enforcement) marked as historical `cf2a6d6a4` evidence.
- Scope: recheck that one compact page against current `origin/master@0139a346`, update shifted line anchors and fix any stale path wording. No gameplay source edits planned.
- Source proof in progress: `cf2a6d6a4..origin/master` touches shared constants, parameters, support paradrop files and `stringtable.xml`, but the boundary geometry and off-map handler shapes remain present; current line drift includes `Init_Common.sqf:326`, `Init_CommonConstants.sqf:387,427`, `Rsc/Parameters.hpp:291`, `Init_Client.sqf:69-70` and `stringtable.xml:1118`.
- Result: refreshed the page header to current `origin/master@0139a346`, updated shifted source anchors, clarified the `Server/Init/Init_Towns.sqf` town-distribution path and preserved the existing boundary/off-map behavior summary. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are source-anchor spot checks, internal link/wiki validator, JSON/JSONL parse, wiki/docs parity and `git diff --check`.

## 2026-06-21T18:36:15+02:00 - Codex - PVF dispatch current-stable partial closeout

- Claimed `pvf-dispatch-current-stable-partial-closeout` after follow-up source checks sharpened the current-stable PVF matrix: `origin/master@0139a346` source Chernarus and maintained Vanilla no longer use dispatch-time `Call Compile` in `Server_HandlePVF.sqf` or `Client_HandlePVF.sqf`.
- Source evidence: current stable resolves `_code = missionNamespace getVariable _script` and spawns only `CODE` at server `:14-15` and client `:32-33` in both maintained roots. Chernarus blame is `7d60b02b4`; maintained Vanilla propagation is `9b49883cb`. `Init_PublicVariables.sqf:55-61` still lacks registered-handler allowlists/logging. Miksuu `b8389e74` and `origin/perf/quick-wins@0076040f` still use `Spawn (Call Compile _script)` in both maintained roots, and current origin exposes no `release/*` heads on 2026-06-21.
- Result: expanded the PVF closeout into the PVF playbook, Networking gateway, Public Variable Channel Index, Feature Status, Source Fix queue, Server Authority map, Hardening roadmap, Pending Owner Decisions, Deep Review notes, SQF atlas, Performance sweep and machine-readable PVF records so current stable is partial source-present rather than unpatched. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, source evidence probes, wiki/docs parity and `git diff --check`.

## 2026-06-21T18:34:47+02:00 - Claude (claude-gaming) - B67 built, verified and DEPLOYED LIVE on Chernarus

- Built, verified and DEPLOYED build **b67** to the live Chernarus server (MISSINIT `_b67`, ErrInExpr=0, 3/3 up) via the freshname service flow. UNLIKE most worklog entries this one SHIPS GAMEPLAY SOURCE and is live, not docs-only. Packed by `_pack_b67.py` (overlay onto `_b54_ch.zip`; 40 content guards + brace check + round-trip). Source on branch `claude/b57-soak-proposals` (push pending). Verified by per-feature adversarial fleets (all SHIP) + a whole-build double-check fleet (GO, 0 critical).
- **Spawn "same 2 spots" root cause SOLVED (canonical).** In `Server/Init/Init_Server.sqf` MODE-2 (Random, the live default) random placement, `_startG` (the 3rd / GUER base) is initialised `[0,0,0]` and never reassigned, yet the West/East accept-tests required every candidate be `> startingDistance` (7500m) from it = a PHANTOM base at map corner `[0,0,0]`, sterilising a quadrant and collapsing the pool (Chernarus 19->16 candidates, valid W/E pairs 27->7, one side pinned to id297). The three prior fixes (B57 RNG-advance, B62/B66 rotation + egress) all operated DOWNSTREAM of an already-collapsed pool, so none helped. Fix: a `_guerReal` gate disables the `_startG` distance check when GUER has no real base. Live RPT now shows `candidates=15, 14 pass egress, all sides placed [random] after 8 attempts` (no force-fall to the fixed wfbe_default markers). Spawn diagnostics were also converted to raw `diag_log ## B67SPAWN` because the prior `WFBE_CO_FNC_LogContent` calls are no-ops in prod (WF_LOG_CONTENT is commented out) - the 3 prior fixes flew blind.
- **Cash-rich AI commander (no supply inflation).** `Common/Init/Init_CommonConstants.sqf`: stipend 2000->6000 (Hard 9000), `WFBE_C_ECONOMY_INCOME_COEF` 8->14, `WFBE_C_AICOM_INCOME_MULT_MAX` 3.0->4.0, `WFBE_C_AI_COMMANDER_START_FUNDS` restored to 200000, `WFBE_C_AICOM_UPGRADE_FUNDS_RATE` reverted to 1; `WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL` kept at 300 (tech is interval-gated, money-independent, so cash cannot speed tech). All edits are on the CASH path (`updateresources.sqf:95/103`); `WFBE_C_ECONOMY_SUPPLY_INCOME_MULT` stays 0.35 and no supply knob was touched.
- **Hybrid commander (#5) ENABLED.** `WFBE_C_AI_COMMANDER_LOCK` 1->0 so players can vote out the AI commander; the AI then keeps founding/refilling teams in assist mode (`AI_Commander.sqf`, gated by `WFBE_C_AI_COMMANDER_HYBRID_REFILL`) and a human order on an HC team is published via `wfbe_aicom_order` so it is not inert (`AI_Commander_Execute.sqf`); the AI treasury keeps earning under a human commander (`updateresources.sqf` 3 income gates). Relevant: [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook).
- **GUER map visibility.** GUER (resistance) side-patrols now actually DISPATCH: `server_side_patrols.sqf` overrides the defender `_lvl` to new const `WFBE_C_GUER_PATROLS_LEVEL` (resistance has no upgrade system so the level was always 0 and the existing `WFBE_ACTIVE_PATROLS` -> `updatepatrolmarkers.sqf` path, which already supports resistance, had an empty feed). NEW GUER-air marker feed `WFBE_ACTIVE_GUER_AIR` (`Server_GuerAirDef.sqf` rebuild+publish each interval + `Server_OnPlayerConnected.sqf` JIP `publicVariableClient` catch-up + an additive air block in `updatepatrolmarkers.sqf`, distinct blue "GUER Air" arrow). Relevant: [Client marker FSM updater](Client-Marker-FSM-Updater-Map).
- **GUER kit.** VBIED now pays the detonator personally + the team (new `Client/PVFunctions/GuerVbiedBounty.sqf` receiver, registered in `Init_Common.sqf`); high-climbing forced on the VBIED; AK family + RPG7V buyable at gear level 0 (`Gear_GUE.sqf` `_z`->0); BAF IED v1-v4 added to the GUER gear menu; IED kills pay only `WFBE_C_GUER_IED_KILL_COEF` (0.30) via a `Fired`-EH tag attached on FIRST life (`Common/Init/Init_Unit.sqf`) AND on respawn (`Client_OnRespawnHandler.sqf`). `Gear_GUE.sqf`/`Loadout_GUE.sqf` ported to Takistan.
- **AI build + movement.** Factory min centre-to-centre spacing + wider placement ring (`AI_Commander_Base.sqf`, `WFBE_C_AICOM_STRUCT_SPACING`=45 / `WFBE_C_AICOM_FACTORY_RING_MIN/MAX`=60/110); open `isFlatEmpty` spawn apron for AI-owned factories so units stop spawning in trees (`Server_BuyUnit.sqf`); MHQ relocation routes only through own-side towns with a generous buffer outside enemy/GUER activation rings, GUER-aware (`AI_Commander_MHQReloc.sqf`, `WFBE_C_AICOM_MHQ_TOWN_BUFFER`=1000); EAST single-survivor retreat-thrash cull (`AI_Commander_Produce.sqf`).
- **Correctness fixes.** Victory banner showed the LOSER (`Client_EndGame.sqf` inverted a payload that is the winner) - fixed; once-per-tick double-fire guard (`server_victory_threeway.sqf`); GUER end-game label (`GUI_EndOfGameStats.sqf` + `STR_WF_PARAMETER_Side_Guer`); town-AI despawn no longer deletes a player-crewed vehicle (`server_town_ai.sqf` crew scan); removed dead `WFBE_C_MODULE_BIS_HC` lobby param; corrected the stale `STR_Supplies_2` 4x reward text to the real reward (supply value, +25% heli); registered `wfbe_supply_temp_resistance` side-supply PVEH (`Server_ChangeSideSupply.sqf`); deleted orphaned `Server/AI/AI_TLWPHandler.sqs`.
- **Pending:** push the `claude/b57-soak-proposals` source commit; Takistan full-parity build. Dashboard changelog build 67 already published. Live monitor re-pointed to `_b67` (15-min WaspSoakWatch + WaspB57Soak keep-alive). NOTE: gameplay source DID change and is LIVE.

## 2026-06-21T18:25:19+02:00 - Codex - SEND_MESSAGE current stable refresh

- Claimed `send-message-current-stable-refresh` after the DR-46 Public Variable Channel Index matrix, Feature Status row and Source Fix queue row still treated older `origin/master@cf2a6d6a` as current evidence while the fetched stable branch is `origin/master@0139a346`.
- Source evidence: current Chernarus and maintained Vanilla still register direct `"SEND_MESSAGE" addPublicVariableEventHandler` at `Client/FSM/updateclient.sqf:12`, compile payload text in `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf:27`, and helper-compile/broadcast via `Common/Functions/Common_SendMessage.sqf:26,38`. Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2` keep the same shape; current origin exposes no `release/*` heads on 2026-06-21.
- Result: refreshed [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so DR-46 is current-stable-unpatched and the old release evidence is explicitly historical/branch-scoped. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, source evidence probe and `git diff --check`.

## 2026-06-21T18:17:28+02:00 - Codex - WASP marker wait current stable refresh

- Claimed `wasp-marker-wait-current-stable-refresh-2026-06-21` after [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) still cited the older `89ae9dad` / `7ff18c49` branch check and helper launch line, while current `origin/master@0139a346` has moved the maintained-root launch to `Client/Init/Init_Client.sqf:309`.
- Source scope: current stable `origin/master@0139a346`, Miksuu upstream `b8389e74` fetched into `FETCH_HEAD`, `origin/perf/quick-wins@0076040f` and `git ls-remote --heads origin release/*` returning no current release heads on 2026-06-21. Checked Chernarus source and maintained Vanilla `WASP/global_marking_monitor.sqf` plus `Client/Init/Init_Client.sqf`.
- Finding: current stable still keeps `disableUserInput true`, the unslept `while {time < _this}` display-54 wait and keyUp/keyDown wiring at `global_marking_monitor.sqf:57,62,65,69-70`, with the throttled display-12 sibling at `:81`, in both maintained roots. No gameplay source edits planned.
- Planned validation: mirror touched wiki files into `docs/wiki`, parse touched JSON/JSONL, run the wiki validator, verify wiki/docs parity, check Latest Batch row count and run `git diff --check`.
- Result: refreshed the WASP owner/status route so current stable evidence is explicit, older release wording is historical until a release head exists again, and future code-owner work remains scoped to the tiny display-54 wait/backoff patch plus marker-dialog smoke. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, wiki/docs parity, Latest Batch five-row check and `git diff --check`.

## 2026-06-21T18:15:26+02:00 - Codex - SEND_MESSAGE direct compile current stable refresh

- Claimed `send-message-direct-compile-current-stable-refresh` to update the DR-46 direct-channel RCE branch matrix from stale `cf2a6d6a` current-stable wording to current fetched `origin/master@0139a346`.
- Source scope: docs head `16247fc8f`, current stable `origin/master@0139a346`, Miksuu `upstream/master@b8389e74` and `origin/perf/quick-wins@0076040f`, checked across Chernarus source and maintained Vanilla. `git ls-remote --heads origin release/*` returned no current release heads on 2026-06-21.
- Planned result: refresh [Public variable channel index](Public-Variable-Channel-Index), [Networking/public variables](Networking-And-Public-Variables), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) with exact current refs and the unchanged receiver/helper compile proof. No gameplay source edits planned.
- Result: refreshed the DR-46 `SEND_MESSAGE` branch matrix and linked network/status rows so current stable is `origin/master@0139a346`, the checked docs/stable diffs do not touch the receiver/helper paths, Miksuu/perf remain unrescued, and older release `a96fdda2` is historical because current origin advertises no `release/*` heads. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, Latest Batch five-row check and `git diff --check`.

## 2026-06-21T18:04:03+02:00 - Codex - PVF dispatcher current stable closeout

- Claimed `pvf-dispatcher-current-stable-closeout-2026-06-21` after checking current `origin/master@0139a346` and finding registered PVF dispatch no longer uses `Call Compile _script` in the maintained Chernarus and Vanilla dispatcher files.
- Scope: docs-only current-stable status refresh for [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Networking and public variables](Networking-And-Public-Variables) and [Public variable channel index](Public-Variable-Channel-Index). Keep sender authentication (DR-55) and direct-PV `SEND_MESSAGE` compile separate. No gameplay source edits planned.
- Result: updated the PVF owner pages and status rows to mark DR-1/DR-38 dispatch-time compile removal source-present/partial on current stable, because both maintained roots use `missionNamespace getVariable` plus `typeName _code == "CODE"` at `Server_HandlePVF.sqf:14-15` and `Client_HandlePVF.sqf:32-33`. The docs checkout and `origin/perf/quick-wins` rows still show old `Spawn (Call Compile _script)` evidence; earlier Miksuu/release rows remain historical until rechecked.
- Boundaries preserved: current stable has no explicit `PVF_ALLOWED` allowlist, DR-55 sender authentication is still open, and current stable still compiles direct `SEND_MESSAGE` payload text at `Client_onEventHandler_SEND_MESSAGE.sqf:27` / `Common_SendMessage.sqf:26`.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, wiki/docs parity and `git diff --check`.

## 2026-06-21T18:53:35+02:00 - Codex - PVF dispatch cross-link follow-up

- Claimed `pvf-dispatch-crosslink-followup-2026-06-21` after the published PVF current-stable closeout left three routing pages with stale "replace Call Compile" current-state wording.
- Source evidence: current stable `origin/master@0139a346` includes `7d60b02b`; maintained-root dispatchers use `_code = missionNamespace getVariable _script` plus `typeName _code == "CODE"` at `Server/Functions/Server_HandlePVF.sqf:14-15` and `Client/Functions/Client_HandlePVF.sqf:32-33`. The current-stable closeout still records no explicit registered-handler allowlist.
- Result: refreshed [Hardening roadmap](Hardening-Implementation-Roadmap), [Pending owner decisions](Pending-Owner-Decisions) and [Server authority migration map](Server-Authority-Migration-Map) so the remaining current-stable dispatcher task is explicit registered `SRVFNC*` / `CLTFNC*` membership and forged-name rejection, not the already-merged namespace lookup. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, source evidence probe and `git diff --check`.

## 2026-06-21T18:56:27+02:00 - Codex - Salvage current stable refresh

- Claimed `salvage-current-stable-refresh-2026-06-21` after the salvage matrix/status rows still treated older `origin/master@cf2a6d6a` and release-head wording as current-facing evidence while fetched stable is `origin/master@0139a346` and current origin exposes no `release/*` heads.
- Source scope: docs checkout `docs/developer-wiki-index@10097961`, current stable `origin/master@0139a346`, Miksuu upstream `b8389e74` fetched into `FETCH_HEAD` from `https://github.com/Miksuu/a2waspwarfare.git`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2`, checked across source Chernarus and maintained Vanilla salvage paths.
- Finding: all checked roots still keep lowercase `ChangePlayerfunds` in both salvage payout paths while client init compiles `ChangePlayerFunds`; all checked roots keep `updatesalvage.sqf:10` as `while {!gameOver || !(alive _vehicle)}` and keep client-local wreck deletion/reward.
- Result: refreshed the canonical salvage matrix, Feature Status and Source Fix queue plus live machine rows so current stable is `origin/master@0139a346` and `a96fdda2` is preserved as historical release evidence because no live `release/*` head exists. No gameplay source changed.
- Validation: JSON/JSONL parse passed in wiki and docs/wiki; `docs/validate-wiki.ps1` passed with known legacy JSONL warnings only; full wiki/docs parity passed across `275` files; Latest Batch is five rows; `git diff --check` passed in both worktrees with LF/CRLF warnings only.

## 2026-06-21T18:59:54+02:00 - Codex - Attack-wave current stable refresh

- Claimed `attack-wave-current-stable-refresh-2026-06-21` after the attack-wave playbook, Feature Status and Source Fix queue still cited older `origin/master@cf2a6d6a` stable evidence and treated `a96fdda2` / `c20ce153` as live branch heads.
- Source evidence: current stable `origin/master@0139a346` Chernarus and maintained Vanilla still gate the action client-side at `Client/FSM/updateclient.sqf:260`, send `ATTACK_WAVE_INIT` from `Common_AttackWaveActivate.sqf:6,8`, trust payload `_supply` / `_side` in `Server_AttackWave.sqf:5-6,15,23,27,36,38`, and trust/debit detail payloads in `AttackWave.sqf:19,23-25,40`. Miksuu `b8389e74`, perf `0076040f`, historical AI-commander commit `c20ce153`, historical release commit `a96fdda2` and historical `upstream/AttackWave` commit `994150da` keep the same shape; current origin exposes no `release/*` or `feat/ai-commander` heads.
- Result: refreshed [Attack-wave authority](Attack-Wave-Authority-Playbook#branch--root-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Public variable channel index](Public-Variable-Channel-Index) and [Server authority migration map](Server-Authority-Migration-Map) so DR-41 remains patch-ready/current-stable-unpatched with current line refs and historical branch scope. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, source evidence probe and `git diff --check`.

## 2026-06-21T19:15:49+02:00 - Codex - Source fix queue current stable scope refresh

- Claimed `source-fix-queue-current-stable-scope-refresh-2026-06-21` after [Source fix propagation queue](Source-Fix-Propagation-Queue) still named older `origin/master@cf2a6d6a` / current release wording in its branch-scope area while fetched stable is `origin/master@0139a346` and current origin exposes no `release/*` heads.
- Source scope: `docs/developer-wiki-index@d30d23466`, `origin/master@0139a346`, `upstream/master@b8389e74`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, Chernarus source and maintained Vanilla queue path families.
- Source evidence: checked queue PVFs/paratrooper registration, `Skill_Init`/apply, guarded FPS publisher shape, heli-aware supply scan, supply player-list index placement, commander ARTY marker variables/discovery and Patrols v2 `Server/FSM` route line refs in current stable; `git diff --name-only 4bd37b98..d30d23466` is empty for the queue's checked propagation path families.
- Result: refreshed Current Branch Scope, Latest Propagation Run, Branch Implementation Caveat, current queue rows, smoke wording and Agent Index facts so current stable evidence is explicit, the supply player-list index fix remains docs/source-only, and `a96fdda2` is historical until a release head is restored or rechecked. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are source probes, JSON/JSONL parse, `docs/validate-wiki.ps1`, wiki/docs parity, Latest Batch five-row check and `git diff --check`.

## 2026-06-21T19:25:02+02:00 - Codex - Commander vote current stable closeout

- Claimed `commander-vote-current-stable-closeout-2026-06-21` after the commander vote playbook and Feature Status row still treated the old DR-47 server comparison as source-unpatched everywhere checked.
- Source evidence: current stable `origin/master@0139a346` Chernarus and maintained Vanilla still count `_aiVotes` at `Server_VoteForCommander.sqf:18,26-27`, but now assign a player commander only when `_highest >= _aiVotes` at `:43`. Chernarus blame points to `cbc2294c4`; maintained Vanilla propagation points to `91dc6a75`. `GUI_VoteMenu.sqf:88` still uses row-0 / strict-majority preview logic. Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, historical release commit `a96fdda2` and historical AI-commander commit `c20ce153` still keep the old `>= || <=` condition at `Server_VoteForCommander.sqf:43`; current origin exposes no `release/*` or `feat/ai-commander` heads.
- Result: refreshed [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook#current-branch-scope), [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) so current stable is source-present/smoke-pending for the server comparison, while UI preview/policy alignment and old-branch porting remain open. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, wiki/docs parity, source evidence probe, Latest Batch five-row check and `git diff --check`.

## 2026-06-21T19:28:53+02:00 - Claude (claude-gaming) - B68 hotfix deployed live (AI attack-bias + supply-marker leak + retreat-cull)

- Hotfix on top of b67, DEPLOYED LIVE Chernarus (MISSINIT `_b68`, ErrInExpr=0, 3/3). Ships gameplay source. Driven by two b67 playtest bugs + Ray's directive "DEFENSE should matter MUCH LESS than ATTACK." Source commit `b8a1505f` on `claude/b57-soak-proposals`; verified adversarial SHIP + content-guarded pack + boot-smoke clean.
- **MARKER LEAK (canonical):** `Server/Functions/AI_Commander_Wildcard.sqf:994` - the W17 "Supply Convoy" wildcard created a GLOBAL marker (`createMarker` + `setMarker*`, all non-Local) labelled "Supply Convoy (WEST/EAST)" = replicated to ENEMY clients too. It was wrongly copied from the W18 Bounty card (which is *intentionally* global). Removed; the convoy truck already shows to its OWN side via the standard friendly unit-marker (Init_Unit SupplyVehicle path). Lesson: own-side-only info must use `createMarkerLocal` + a side gate (or a friendly unit-marker), never a server-side global `createMarker`.
- **AICOM ATTACK-BIAS - KEY FINDING:** `_posture` (PRESS/DEFEND/HOLD, Strategy:~554) and `wfbe_aicom_strat_mode` are **TELEMETRY-ONLY** (read only by `diag_log`/the AICOM BRIEF line). They change no behaviour. The EFFECTIVE attack-vs-defend levers are: LAST-STAND (`AI_Commander_Strategy.sqf` recall-all-to-HQ + exitWith), RELIEF diversion (`WFBE_C_AI_COMMANDER_RELIEF_MAX`), and the `_myStr` maneuver-strength compare that gates them. AssignTowns already attacks by default (garrison OFF).
- **FIXES:** (a) LAST-STAND tightened to `<= WFBE_C_AICOM_LASTSTAND_TOWNS (1)` town AND `< WFBE_C_AICOM_LASTSTAND_RATIO (0.45)` of enemy strength (was `<2 towns && <0.7` = fired while merely behind, so winning sides went passive). (b) `_myStr` now EXCLUDES stranded lone-survivor remnants (alive < `WFBE_C_AICOM_STR_LONE_ALIVE (2)` AND leader > `WFBE_C_AICOM_STR_LONE_FARHQ (1500)` m from HQ) + `wfbe_aicom_refit` teams, so a few far-flung survivors no longer deflate strength and falsely trip the defensive gates. (c) `WFBE_C_AICOM_RELIEF_HOLD` 240->180.
- **RETREAT-CULL REGRESSION (b67, mine):** the b67 progress-gated retreat budget never culled a lone survivor that slowly crawls home from far away (HC-churn stranded ~17km; closes >MIN_CLOSE/cycle so the counter keeps resetting) - it re-issued "retreat to HQ" every cycle, the team milled at base with its transport truck and never assaulted, and the remnant inflated `_myStr` -> the "EAST amasses strength but never attacks" stall. Added an ABSOLUTE re-issue cap (`wfbe_aicom_retreat_issues`, monotonic, NOT reset by progress; `WFBE_C_AICOM_RETREAT_MAX_ISSUES=8`) + a hard distance cap (`WFBE_C_AICOM_RETREAT_MAX_DIST=6000`) in `AI_Commander_Produce.sqf`, so far-stranded remnants are recycled instead of looping. (The "trucks dismount at base / no assault" symptom was this, NOT a transport bug - the b66 mount/dismount/capture flow is fine.)
- All new constants in `Common/Init/Init_CommonConstants.sqf` (default-ON, tunable, rollback-documented). Takistan parity still parked (map rotation off). NOTE: gameplay source DID change and is LIVE.
## 2026-06-21T19:27:00+02:00 - Codex - Victory/endgame current stable refresh

- Claimed `victory-endgame-current-stable-refresh-2026-06-21` after the victory/endgame atlas, Feature Status and Source Fix queue still treated the old-shape logger behavior as uniform across current stable.
- Source scope: docs checkout `a0a86da2` / `origin/docs/developer-wiki-index` source-unchanged for checked victory paths, current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2`. `git ls-remote --heads origin release/*` returned no current release heads on 2026-06-21.
- Finding: current stable Chernarus and maintained Vanilla still keep the mixed HQ/factory/all-towns condition and no side-loop break at `Server/FSM/server_victory_threeway.sqf:29-49`, but now add HQ nil guards at `:18-22`, WASPSTAT `ROUNDEND` with `_x` at `:41-46` and `[_x] call WFBE_CO_FNC_LogGameEnd` at `:49`. Old-shape docs/Miksuu/perf/historical release refs still invert `_x` before the logger at `:35-41`.
- Result: refreshed [Victory/endgame atlas](Victory-And-Endgame-Atlas), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and the hardening backlog rows so the patch-ready work is explicit winner/loser computation, a combined `!WFBE_GameOver` guard and one accepted endgame exit. No gameplay source changed.
- Validation: JSON/JSONL parse passed in wiki and docs/wiki; `docs/validate-wiki.ps1` passed from the docs-index checkout with known legacy JSONL envelope warnings only; touched-file wiki/docs parity passed; Latest Batch is five rows; `git diff --check` passed in both worktrees with LF/CRLF warnings only.

## 2026-06-21T19:50:55+02:00 - Codex - Upgrade-sync current stable refresh

- Claimed `upgrade-sync-current-stable-refresh-2026-06-21` after [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix), [Upgrades and research](Upgrades-And-Research-Atlas#current-branch-scope), [Feature status](Feature-Status-Register) and [Source fix queue](Source-Fix-Propagation-Queue) still carried older `origin/master@cf2a6d6a` / live release-branch wording for the `RequestSpecial ["upgrade-sync", ...]` tuple cleanup.
- Source scope: docs-source base `docs/developer-wiki-index@ad05401a3` is unchanged from line-anchor checkpoint `ff8dd884` for the checked handler/caller/process-upgrade paths; current stable is `origin/master@0139a346`; Miksuu is `b8389e74`; perf is `origin/perf/quick-wins@0076040f`; `a96fdda2` and `b061c905` are historical because current origin exposes no `release/*` or `feat/upgrade-queue-stacking` heads.
- Source evidence: current stable Chernarus and maintained Vanilla still keep the mixed `_args` / `_this` parser at `Server_HandleSpecial.sqf:67-73`; the current-stable caller is `GUI_UpgradeMenu.sqf:292`; sync variable lifecycle moved to `Server_ProcessUpgrade.sqf:32,35,41`; Miksuu/perf callers remain `:241`, historical release `:254`, historical upgrade-queue `:268`.
- Result: refreshed the support owner matrix, upgrades route, Feature Status row, Source Fix queue row, dashboard, pruning ledger and machine records so `upgrade-sync` remains patch-ready consistency cleanup/current-stable-unrescued without overclaiming a runtime break. No gameplay source changed.
- Validation: source probes passed for docs-source no-drift, absent live release/upgrade-queue heads, current stable parser/caller/lifecycle and old-ref caller lines; JSON/JSONL parse passed in wiki and docs/wiki; `docs/validate-wiki.ps1` passed with known legacy JSONL envelope warnings only; top-level wiki/docs parity passed across 275 files; Latest Batch is five rows; `git diff --check` passed in both worktrees with LF/CRLF warnings only.

## 2026-06-21T19:55:48+02:00 - Codex - B68 AICOM live branch route

- Claimed `b68-aicom-live-branch-route-2026-06-21` as a docs-only route for PR #43 / `origin/claude/b57-soak-proposals@b8a1505f`. Scope is canonical wiki/status routing only; no gameplay source edits planned.
- Source evidence in hand: `gh pr view 43` reports PR #43 open from `claude/b57-soak-proposals` to `master`, head `b8a1505f8a89881f487a03262f066c8b33eca94d`, updated `2026-06-21T17:26:33Z`; `origin/master` remains `0139a346`.
- B68 commit evidence: commit `b8a1505f` changes four Chernarus files only. It removes the W17 global Supply Convoy marker route in `Server/Functions/AI_Commander_Wildcard.sqf:994` while `origin/master` still creates that marker at `:981-984`; it adds attack/retreat controls at `Common/Init/Init_CommonConstants.sqf:277-284,319`, `Server/AI/Commander/AI_Commander_Strategy.sqf:41-68,99,441,571-590` and `Server/AI/Commander/AI_Commander_Produce.sqf:90-151`.
- Planned docs route: update the AI commander audit, marker content catalog, Feature Status and PR cleanup lab so B68 is visible as branch/live evidence without treating it as merged master or release-ready.
- Result: routed B68 into the canonical AI commander, marker, Feature Status and PR cleanup docs plus machine/coordination rows while preserving the current `origin/master@0139a346` and release-ready claims as separate. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, Latest Batch five-row check and `git diff --check`.

## 2026-06-21T20:18:24+02:00 - Codex - Headless client init mirror sync

- Claimed `headless-client-init-mirror-sync-2026-06-21` after rebasing the standalone wiki to `master@e03c3bf` and finding four top-level mirror gaps against repo branch `docs/developer-wiki-index@f81ec4145`: `_Sidebar.md`, `Home.md`, `agent-context.json` and missing `Headless-Client-Init-And-Stat-Loop.md`.
- Scope: mirror the live wiki routing and the new HC init/stat-loop reference into `docs/wiki` only. The page is already source-stamped against `origin/master@0139a346` and cites HC role detection, `Init_HC.sqf`, `HC_StatLoop.sqf`, `HCStat` and `HCSIDE` telemetry paths. No gameplay source edits planned.
- Result: copied the missing page and three routing/index files into `docs/wiki`, updated this coordination trail, and kept the Headless Client prose unchanged.
- Validation: JSON/JSONL parse, `docs/validate-wiki.ps1`, top-level wiki/docs parity, Latest Batch five-row count and `git diff --check` are the required gates for this mirror-only lane.

## 2026-06-21T20:18:55+02:00 - Codex - Victory/endgame stable-scope refinement

- Rebased the victory/endgame refresh over newer commander-vote, upgrade-sync and reference-page wiki commits, then kept those upstream rows while refining only the victory/endgame branch evidence.
- Source evidence retained: docs head `d30d23466` is source-unchanged from `a0a86da2` / `2f2132f8` for checked victory files; docs/Miksuu/perf/historical `a96fdda2` keep the older opposite-side logger block at `server_victory_threeway.sqf:23-41`; current stable `origin/master@0139a346` uses condition-side `_x` for WASPSTAT/logger at `:41-49`, so HQ/factory eliminations still log the loser; `origin/claude/b57-soak-proposals@b8a1505f` remains Chernarus-only live-support evidence.
- Result: kept the refined [Victory/endgame atlas](Victory-And-Endgame-Atlas#current-branch-scope), Feature Status, Source Fix queue, pruning ledger and machine backlog wording without changing gameplay source.
- Validation: final post-rebase validation is recorded in `agent-events.jsonl`.

## 2026-06-21T19:44:25+02:00 - Codex - Patrols v2 current stable refresh

- Claimed `patrols-v2-current-stable-refresh-2026-06-21` after Patrols v2 owner/status pages still cited `origin/master@cf2a6d6a`, older line refs and live release-branch wording while fetched stable is `origin/master@0139a346` and current origin exposes no `release/*` heads.
- Source scope: docs branch `docs/developer-wiki-index@d30d23466` is unchanged from the earlier `5243f91d` Patrols source anchors for checked paths. Current stable `origin/master@0139a346` was checked across Chernarus and maintained Vanilla Patrols paths.
- Finding: current stable still carries Patrols v2 in both maintained roots with `WFBE_UP_PATROLS = 23`, `WFBE_C_SIDE_PATROLS_MAX = 2`, defender cap `WFBE_C_SIDE_PATROLS_MAX_DEFENDER = 1`, driver start `Init_Server.sqf:690`, HC dispatch at `server_side_patrols.sqf:67`, friendly marker loop `Init_Client.sqf:405`, `server_patrols.sqf:31` `&&`, and level-4 convoy/camp-sweep hooks in `Common_RunSidePatrol.sqf`.
- Result: refreshed [Towns/camps/capture](Towns-Camps-And-Capture-Atlas#patrols-v2-side-upgrade-path), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map#current-branch-scope), [AI/headless gateway](AI-Headless-And-Performance#current-branch-scope), [Server runtime atlas](Server-Gameplay-Runtime-Atlas#branch-scope-for-source-anchors), [Feature status](Feature-Status-Register), [Source fix queue](Source-Fix-Propagation-Queue) and live machine rows. No gameplay source changed by this Codex lane.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, wiki/docs parity, Latest Batch five-row check and `git diff --check`.
## 2026-06-21T20:32:39+02:00 - Codex - Factory destroyed-purchase refund current stable refresh

- Claimed `factory-destroyed-purchase-refund-current-stable-refresh-2026-06-21` after [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas#destroyed-factory-refund-branch-matrix), Feature Status and Source Fix queue still mixed old `origin/master@cf2a6d6a` line anchors with live release/QoL branch wording.
- Source scope: docs branch `docs/developer-wiki-index@ebd86fad0` is source-unchanged from `8d611092` for checked Chernarus and maintained Vanilla buy/build paths; current stable is `origin/master@0139a346`; Miksuu is `b8389e74`; perf is `origin/perf/quick-wins@0076040f`; `a96fdda2`, `7ff18c49` and `a66d4691` are historical because current origin exposes no `release/*` or `feat/buymenu-easa-qol` heads.
- Planned route: refresh the factory refund matrix, adjacent Feature Status and Source Fix queue rows, hardening backlog and coordination files without touching gameplay source or reopening the broader player-buy authority migration.
- Finding: current stable Chernarus and maintained Vanilla now pass `_currentCost` into `BuildUnit` and refund the real dead/null factory abort at `Client_BuildUnit.sqf:276-280`; historical `a96fdda2` has the same dead/null refund at `:212-216`; intermediate `7ff18c49` only refunded the empty/crewless branch and is superseded. Docs/Miksuu/perf/historical QoL `a66d4691` remain old-shape with dead/null cleanup but no refund.
- Result: refreshed [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas#destroyed-factory-refund-branch-matrix), [Feature status](Feature-Status-Register), [Source fix queue](Source-Fix-Propagation-Queue), hardening backlog and live coordination rows so old-root patch guidance routes to the current-stable / `a96fdda2` dead/null refund payload. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event; required gates are JSON/JSONL parse, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, Latest Batch five-row check, conflict-marker scan and `git diff --check`.

## 2026-06-21T20:40:00+02:00 - Claude (claude-gaming) - TODO: b67 vehicle-tint legend "not found" — needs clean repack

- **Symptom (live b67 Chernarus):** at first spawn the client throws `Resource WFBE_VehicleTintLegend not found` — the b67 vehicle-tint legend pop-up (`cutRsc` on layer 12460, `Client/Init/Init_Client.sqf:350`). **Cosmetic / non-fatal**: gameplay, AICOM and economy are unaffected; it's just a red on-screen resource warning.
- **Root cause = build/deploy desync, NOT a source bug.** Repo source is in sync — `class WFBE_VehicleTintLegend` exists in `Rsc/Titles.hpp:854` (registered in `titles[]` at `:25`, base classes `RscText`/`RscStructuredText` defined in `Rsc/Ressources.hpp` and included before `Titles.hpp`) and the `cutRsc` reference is in `Init_Client.sqf`; both landed together in commit `7e29f801` (B67). But the deploy ships a pre-built staging PBO (`C:\WASP\staging\b67-ch.pbo`, copied to MPMissions by `_freshname_pbo_deploy_b67.ps1`), and that PBO carries the script's cutRsc but a STALE `Rsc/Titles.hpp` missing the class — the overlay-pack-onto-last-good-zip hazard (see [Source fix queue](Source-Fix-Propagation-Queue) / build-from-last-good-zip gotcha). `ErrInExpr=0` boot-smoke can't catch it — the cutRsc fires ~6s after first spawn, not during init.
- **Done (working tree, uncommitted, main repo b67 WIP):** hardened the legend gate at `Init_Client.sqf:345` to also require `isClass (missionConfigFile >> "RscTitles" >> "WFBE_VehicleTintLegend")`, so a desynced build stands the whole legend down silently (no keydown handler, no first-spawn auto-show) instead of erroring. A2-OA-1.64 safe (`isClass`/`missionConfigFile` only).
- **TODO / next action:** the live error only clears once the b67 staging PBO is **repacked with a CLEAN full pack** (must include `Rsc/Titles.hpp` + the guarded `Init_Client.sqf`), then redeployed via `_freshname_pbo_deploy_b67.ps1`. That both kills the error and makes the legend actually render. Verify by confirming the deployed PBO's `Titles.hpp` contains `WFBE_VehicleTintLegend`.
- **Related:** PR #45 (`claude/faction-tint-sidefix`) flips `WFBE_C_VEHICLE_TINTS` default 1→0 (opt-in); the legend only shows when tints are ON, so consider making the legend default-off too for coherence. That PR is decals-based and contains no legend code — this fix is separate, in the b67 WIP tree.
- No gameplay-behaviour source changed (client cosmetic guard only).

## 2026-06-21T20:11:38+02:00 - Codex - Commander reassignment current stable closeout

- Claimed `commander-reassignment-current-stable-closeout-2026-06-21` after [Commander reassignment call shape](Commander-Reassignment-Call-Shape) and status rows still framed helper unpacking as a current-source patch everywhere, while [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook#current-branch-scope) already showed current stable had the maintained-root helper fix.
- Source scope: docs branch `docs/developer-wiki-index@b44aaaf8`, current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f`, historical release `a96fdda2` and historical AI-commander `c20ce153`. `git ls-remote --heads origin release/* feat/ai-commander` returned no live heads on 2026-06-21.
- Finding: current stable Chernarus and maintained Vanilla unpack `_side = _this select 0` / `_commander = _this select 1` at `Server_AssignNewCommander.sqf:4-5`; Miksuu, perf and the historical release/AI refs match that maintained-root shape. Docs branch `b44aaaf8` still uses `_side = _this` at `:3`, and current stable full modded Napf/Eden/Lingor forks still use `_side = _this` at `Modded_Missions/*/Server/Functions/Server_AssignNewCommander.sqf:3`.
- Result: refreshed [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) and machine rows so current stable is partial source-present, not helper-unpatched. Duplicate `new-commander-assigned` senders, visible-name UI targeting, requester authority, old docs-branch shape and modded fork drift remain open. No gameplay source changed.

## 2026-06-21T20:48:44+02:00 - Codex - Gear template current stable scope refresh

- Claimed `gear-template-current-stable-scope-refresh-2026-06-21` after [Gear template profile filter](Gear-Template-Profile-Filter), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), Feature Status, Source Fix queue and machine rows flattened old docs/source evidence with current stable and contradicted whether `_u_upgrade` was fixed on master.
- Source evidence in hand: current docs branch `docs/developer-wiki-index@43c3ba05` is source-unchanged from `8b71e2a1` for checked gear-template paths and still has `_u_upgrade` at `Client_UI_Gear_SaveTemplateProfile.sqf:33,52,75` plus `Init_ProfileGear.sqf:17,25` six-field import guard in both maintained roots; current stable `origin/master@0139a346` fixes the save-filter comparisons at `:34,57,82` but keeps the import guard and creation/display policy. Miksuu `b8389e74`, perf `0076040f`, historical release `a96fdda2` and historical EASA QoL `a66d4691` keep the old save-filter shape.
- Planned result: refresh the owner/status/queue/machine wording so docs/source and old refs remain patch targets, current stable is not told to redo the save-filter fix, and profile-template import/policy work stays open. No gameplay source changes planned.
- Result: refreshed [Gear template profile filter](Gear-Template-Profile-Filter), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Feature status](Feature-Status-Register), [Source fix queue](Source-Fix-Propagation-Queue), dashboard, pruning ledger and gear machine rows so current stable is not told to redo the save-filter task-44 fix. Current stable profile-template work is now scoped to `Init_ProfileGear.sqf:17,25` import bounds plus the AddTemplate/FillTemplates creation/display policy. No gameplay source changed.
- Validation: source probes passed for docs-source no-drift, current-stable save-filter/import evidence, old-ref save-filter shape and absent live release/QoL heads; JSON/JSONL parse, `docs/validate-wiki.ps1`, top-level wiki/docs parity, Latest Batch five-row check and `git diff --check` are recorded in the matching `complete` event.

## 2026-06-21T20:38:31+02:00 - Codex - Side-supply current stable refresh

- Claimed `side-supply-current-stable-refresh-2026-06-21` after the side-supply clamp/reason rows still used older `origin/master@cf2a6d6a` and release-head wording while fetched stable is `origin/master@0139a346` and current origin exposes no `release/*` heads.
- Source scope: docs branch `7047da5d9` is source-unchanged from `f52ccee8` for checked `Common_ChangeSideSupply.sqf`, `Server_ChangeSideSupply.sqf`, `AttackWave.sqf` and `supplyMissionCompleted.sqf` paths; current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2` were kept branch-scoped.
- Finding: docs/current stable/Miksuu keep `_currentSupply - _amount` at `Common_ChangeSideSupply.sqf:25` and `Server_ChangeSideSupply.sqf:12,36` plus payload-side trust in both maintained roots. `origin/perf/quick-wins@0076040f` fixes only the Chernarus arithmetic floor to `0`; Vanilla propagation, side/channel/requester validation and reason parsing remain open.
- Result: refreshed [Economy authority first cut](Economy-Authority-First-Cut#side-supply-branch-matrix), Feature Status, Source Fix queue, pruning ledger and side-supply machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T08:54:39+02:00 - Codex - B69 AI commander mirror sync

- Claimed `b69-ai-commander-mirror-sync-2026-06-22` after a fresh comparison showed live wiki `master@3be04f1` and repo mirror `origin/docs/developer-wiki-index@77b38d07` were no longer in parity.
- Scope: mirror-only docs sync. The wiki has `AI-Commander-B69-Implementation-Sketches.md` and `AI-Commander-B69-Improvement-Roadmap.md`; `docs/wiki` missed both, and `_Sidebar.md` differed. No gameplay source edits planned.
- Result: copied only those mirror gaps into `docs/wiki`, kept the B69 source-backed pages unchanged, updated dashboard/status/collaboration/pruning records and left gameplay source untouched.
- Validation: JSON/JSONL parse passed in the wiki checkout and docs mirror; `docs/validate-wiki.ps1` passed with known legacy JSONL warnings only; top-level wiki/docs parity reports `290` files on each side with no missing/differing files; Latest Batch has five rows; `git diff --check` passed in both worktrees with LF/CRLF warnings only.

## 2026-06-22T08:57:00+02:00 - Codex - B69 AICOM wiki mirror catch-up

- Claimed `b69-aicom-wiki-mirror-catchup-2026-06-22` as a follow-up to the mirror-only lane after the B69 pages were present but [Home](Home), `agent-context.json` and the AI commander autonomy audit still needed current-stable routing/evidence correction.
- Scope: route the B69 roadmap/sketch pages through Home and machine context, correct stale no-active-loop wording, and update coordination records. No gameplay source edits planned.
- Planned validation: JSON/JSONL parse for touched agent files, `docs/validate-wiki.ps1`, touched-file wiki/docs parity, Progress Dashboard Latest Batch five-row check and `git diff --check` in both worktrees.
- Result: wired the B69 pages through Home and agent context, preserved the later [AI commander autonomy audit](AI-Commander-Autonomy-Audit#b69-roadmap-and-sketch-route) routing section, and corrected the audit plus `agent-context.json` so current stable `origin/master@0139a346` is described as having a source-present maintained-root supervisor route (`Init_Server.sqf:64,847`; `AI_Commander.sqf:127,253,161`) instead of the older no-active-loop wording. No gameplay source changed.
- Validation: final wiki/docs parity, `docs/validate-wiki.ps1`, Latest Batch five-row check and `git diff --check` are recorded in the matching `complete` event.

## 2026-06-22T09:03:41+02:00 - Codex - B69 AICOM routing follow-up

- Claimed `b69-aicom-routing-followup-2026-06-22` after the B69 pages were mirrored/sidebar-linked but not yet routed from the canonical AI commander owner page or the AI/headless task bundle in the LLM entry pack.
- Scope: docs routing only. Added [AI commander autonomy audit](AI-Commander-Autonomy-Audit#b69-roadmap-and-sketch-route) guidance that treats [B69 roadmap](AI-Commander-B69-Improvement-Roadmap) and [B69 implementation sketches](AI-Commander-B69-Implementation-Sketches) as live-B68 planning/sketch evidence, not merged `origin/master` or maintained Vanilla proof.
- Result: AI/headless work now naturally reaches the B69 pages from both the subsystem owner page and [LLM agent entry pack](LLM-Agent-Entry-Pack#common-task-bundles). No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T09:08:00+02:00 - Codex - Visible parameter runtime-consumer current stable refresh

- Claimed `visible-parameter-runtime-consumer-current-stable-refresh-2026-06-22` after Mission Parameters, Mission Start Parameters, Dead Code, Feature Status, Source Fix queue and Player AI cap pages still routed `WFBE_C_AI_MAX` and `WFBE_C_UNITS_CLEAN_TIMEOUT` as current no-op/comment-only parameter cleanup.
- Source scope, corrected later by direct Miksuu fetch: docs branch `origin/docs/developer-wiki-index@ac932fbe`, current stable `origin/master@0139a346`, current Miksuu `master@b8389e74`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2`; the earlier `d9506078` Miksuu label was wrong and belongs to `origin/claude/*` GUER branch evidence.
- Finding: docs/current Miksuu/perf/historical release refs keep the old shape; current stable reads `WFBE_C_AI_MAX` in `Server/AI/Commander/AI_Commander_Produce.sqf:89` and `WFBE_C_UNITS_CLEAN_TIMEOUT` in `Common_TrashObject.sqf:21`. Player follower caps still use `WFBE_C_PLAYERS_AI_MAX`, and empty vehicles still use `WFBE_C_UNITS_EMPTY_TIMEOUT`.
- Result: refreshed the owner/status/queue/machine wording so current stable is not routed as no-op/comment-only debt, while old-shape refs still have target-specific port/hide/label decisions. No gameplay source changed.

## 2026-06-22T09:12:09+02:00 - Codex - B69 Patch A branch-status refresh

- Claimed `b69-patch-a-branch-status-2026-06-22` after fetch exposed `origin/claude/b69@35547c47`, while the B69 wiki pages still mostly described the slate as roadmap/sketch material.
- Source scope: `origin/claude/b69@35547c47` is one Patch A commit on top of B68 head `b8a1505f`; `b8a1505f..35547c47` changes 3 files / +85 / -7: `B69-IMPLEMENTATION-PLAN.md`, Chernarus `Common/Init/Init_CommonConstants.sqf` and Chernarus `Server/AI/Commander/AI_Commander_Strategy.sqf`.
- Finding: Patch A order/gate/picker is source-present on the branch (`Init_CommonConstants.sqf:229-231`; `AI_Commander_Strategy.sqf:511-521,540-547,557-559`), but no maintained Vanilla diff exists, no PR exists for `claude/b69`, and capture interrupt remains unimplemented because only `WFBE_C_AICOM_CAPTURE_INTERRUPT` is declared while `Common_RunCommanderTeam.sqf` has no branch diff.
- Result: refreshed the AI commander audit, B69 roadmap/sketch pages, Feature Status and machine rows to preserve the branch proof without claiming stable/Vanilla/release readiness. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T09:16:49+02:00 - Codex - Indicator status-counter branch split

- Claimed `indicator-status-counter-branch-split-2026-06-22` from the open indicator backlog to split the status/debug/admin counter family instead of restarting a broad "all indicators" checklist.
- Source scope: current docs `docs/developer-wiki-index@a27086cd`, current stable `origin/master@0139a346`, Miksuu `master@b8389e74` fetched from `https://github.com/miksuu/a2waspwarfare.git`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2`; current origin exposes no `release/*` heads on 2026-06-22.
- Finding: docs-source Chernarus and maintained Vanilla keep two guarded dedicated-only FPS publishers: `Server/GUI/serverFpsGUI.sqf:1,6-7` publishes `SERVER_FPS_GUI`, `Server/Module/serverFPS/monitorServerFPS.sqf:1,5-6` publishes `WFBE_VAR_SERVER_FPS`, and `Client/Client_UpdateRHUD.sqf:113` reads `SERVER_FPS_GUI`. Current stable and historical `a96fdda2` use one guarded `serverFpsGUI.sqf` publisher in both maintained roots; Miksuu/perf keep the old branch-only-sleep two-publisher shape.
- Result: refreshed [Client UI systems](Client-UI-Systems-Atlas#status-counter-audience-split), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Performance opportunity sweep](Performance-Opportunity-Sweep), Feature Status, hosted-FPS machine row, dashboard and pruning ledger. The docs now keep player HUD FPS, compatibility PVs, admin/status signals and PerformanceAudit RPT/tooling output separate before pruning or consolidation. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T09:22:00+02:00 - Codex - Auto-wall current stable scope refresh

- Claimed `auto-wall-current-stable-scope-refresh-2026-06-22` after [Feature status](Feature-Status-Register) and [Source fix propagation queue](Source-Fix-Propagation-Queue) still cited stale `cf2a6d6a` / `b8389e74` branch evidence for the global auto-wall toggle.
- Source scope, corrected later by direct Miksuu fetch: docs branch `origin/docs/developer-wiki-index@89aadf8c`, current stable `origin/master@0139a346`, current Miksuu `master@b8389e74`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2` and B69 branch `origin/claude/b69@35547c47`; the earlier `d9506078` Miksuu label was wrong and belongs to `origin/claude/*` GUER branch evidence.
- Finding: every checked maintained root still routes CoIn `User14` through `RequestAutoWallConstructinChange.sqf:3-7` into one global `isAutoWallConstructingEnabled`. Docs/perf/direct current Miksuu default it `false` and consume it at SmallSite `:110` / MediumSite `:125`; current stable defaults it `true` and consumes it at SmallSite `:123` / MediumSite `:160` with AARadar plus related exclusions; historical `a96fdda2` only adds the AARadar guard; B69 matches current-stable global scope with line drift.
- Result: refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), Feature Status, Source Fix queue and machine rows so current stable is not routed through old line anchors. The global-vs-side/requester policy decision remains future construction-owner work; no gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T09:34:00+02:00 - Codex - Resource income current-stable refresh

- Claimed `resource-income-current-stable-refresh-2026-06-22` after Economy/Towns/Supply, Economy Authority, Feature Status and Source Fix queue still described current stable as keeping AI commander funds inside the resource cap guard.
- Source scope: docs branch `d7a30e15`, current stable `origin/master@0139a346`, Miksuu `master@b8389e74` fetched from `https://github.com/miksuu/a2waspwarfare.git`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, and no current `release/*` heads on 2026-06-22.
- Finding: docs/Miksuu/perf/historical release keep the old `updateresources.sqf:31` guard over side supply, team paychecks and AI commander funds. Current stable still guards side supply and team paychecks at `updateresources.sqf:45,63,77`, but AI commander over-cap income/stipend fallback is source-present at `:102-109`; income-system `4` display drift remains in all checked refs.
- Result: refreshed [Economy towns/supply](Economy-Towns-And-Supply#resource-income-branch-matrix), [Economy authority first cut](Economy-Authority-First-Cut), Feature Status, Source Fix queue, dashboard and pruning ledger. No gameplay source changed.

## 2026-06-22T09:40:35+02:00 - Codex - B69 Patch A-2 capture-interrupt branch refresh

- Claimed `b69-patch-a2-capture-interrupt-2026-06-22` after `git fetch` advanced `origin/claude/b69` from the documented Patch A head `35547c47` to `edb9f776`.
- Source scope: `edb9f776` is one new Chernarus-only commit over `35547c47`; `35547c47..edb9f776` changes only `Common/Functions/Common_RunCommanderTeam.sqf`, +16 / -1. The full B69 branch delta from B68 head `b8a1505f` is now 4 files / +101 / -8, still Chernarus-only.
- Finding: capture-phase interrupt now has branch executor code: order-seq snapshot at `Common_RunCommanderTeam.sqf:708-713`, camp-first abort at `:809-811`, `doFollow` release and bail at `:867-868`, depot-hold abort at `:894-896` and pre-`_captureDone` bail at `:916`. There is still no maintained Vanilla diff and no PR for `claude/b69`.
- Result: refreshed the B69 audit, roadmap, sketches, Feature Status and machine rows so Patch A-2 is source-present but remains branch-only / smoke-pending / propagation-pending. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T09:38:43+02:00 - Codex - Fast travel fee current-stable refresh

- Claimed `fast-travel-fee-current-stable-refresh-2026-06-22` after [Client UI systems](Client-UI-Systems-Atlas#tactical-fast-travel-fee-branch-matrix), Feature Status, Source Fix queue and fast-travel machine rows still mixed older `origin/master@cf2a6d6a` / `89ae9dad` stable wording with current stable `origin/master@0139a346`.
- Source scope: docs branch `docs/developer-wiki-index@a489e6ff`, current stable `origin/master@0139a346`, Miksuu `master@b8389e74` fetched from `https://github.com/miksuu/a2waspwarfare.git`, `origin/perf/quick-wins@0076040f` and historical release commit `a96fdda2`; current origin exposes no live `release/*` or fast-travel feature heads on 2026-06-22.
- Finding: current stable Chernarus and maintained Vanilla still hide unaffordable paid-mode destinations and draw `$fee` marker text at `GUI_Menu_Tactical.sqf:185,195-196,215`, then locally recalculate/debit at `:403-404`; constants now sit at `Init_CommonConstants.sqf:388,398-400`. The old completed fee-policy TODO is absent on current stable, but docs/Miksuu/perf/historical release still carry it at `GUI_Menu_Tactical.sqf:147` with the old fee/debit line shape.
- Result: refreshed the owner matrix, Feature Status, Source Fix queue, hardening/status/knowledge machine rows and coordination records so future code owners focus on hide-vs-disabled/prompt policy, final local funds/context recheck and Vanilla smoke instead of reopening current-stable TODO removal. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T09:59:09+02:00 - Codex - AI supply-truck current-stable anchor refresh

- Claimed `ai-supply-truck-current-stable-anchor-refresh-2026-06-22` after the AI supply-truck owner/status rows still cited `origin/master cf2a6d6a` and flattened docs-branch raw-spawn evidence with current stable safety.
- Source scope: docs branch `docs/developer-wiki-index@ea0e0f1b`, current stable `origin/master@0139a346`, Miksuu `master@b8389e74` fetched from `https://github.com/miksuu/a2waspwarfare.git`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, historical AI-commander commit `c20ce153`, and no current `release/*` or `feat/ai-commander` heads on 2026-06-22.
- Finding: docs branch/Miksuu/perf still comment out the `UpdateSupplyTruck` compile and raw-spawn the missing worker in both maintained roots (`Init_Server.sqf:36,382-383` on docs/Miksuu; perf Chernarus `:377-378`, Vanilla `:382-383`). Current stable comments the compile at `Init_Server.sqf:43`, initializes `wfbe_ai_supplytrucks` and warning-disables legacy AI supply-truck logistics at `:462-463`; `AI_UpdateSupplyTruck.sqf:17` still points at missing `Server/FSM/supplytruck.fsm` everywhere checked.
- Result: refreshed [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix), [Abandoned feature revival](Abandoned-Feature-Revival-Review), Feature Status, Source Fix queue, dashboard and pruning ledger. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T10:05:31+02:00 - Codex - PVF sender-auth current-stable refresh

- Claimed `pvf-sender-auth-current-stable-refresh-2026-06-22` after the DR-55/PVF rows still mixed older value-only/`Call Compile` evidence with current stable's namespace/CODE dispatcher lookup.
- Source scope: docs branch `HEAD@ade4d356`, current stable `origin/master@0139a346`, current Miksuu `master@b8389e74` fetched from `https://github.com/miksuu/a2waspwarfare.git`, `origin/perf/quick-wins@0076040f`, B69 `origin/claude/b69@0a1ccb4d`, and no current `release/*` heads on 2026-06-22.
- Finding: docs/Miksuu/perf keep value-only PVEHs plus old `Call Compile` dispatchers; current stable and B69 use `missionNamespace getVariable` + `CODE` dispatch but still forward only the PVEH value tuple at `Init_PublicVariables.sqf:56,61`, so DR-55 authenticated requester context is still absent. Current-stable high-risk examples remain `RequestVehicleLock`, `RequestChangeScore`, `RequestNewCommander`, `RequestTeamUpdate`, direct `AttackWave`, SupplyMissionCompleted and `RequestSpecial` tags.
- Result: refreshed [Feature status](Feature-Status-Register), [Server authority migration map](Server-Authority-Migration-Map), [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), [Networking and public variables](Networking-And-Public-Variables), dashboard, pruning ledger and PVF machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T10:17:04+02:00 - Codex - AI upgrade debit current-stable resolution refresh

- Claimed `ai-upgrade-debit-current-stable-resolution-refresh-2026-06-22` after the AI commander upgrade debit/cost rows still treated current stable as debit-fixed but cost-index-open.
- Source scope: docs branch `docs/developer-wiki-index@ade4d356`, current stable `origin/master@0139a346`, Miksuu `master@b8389e74` fetched from `https://github.com/miksuu/a2waspwarfare.git`, `origin/perf/quick-wins@0076040f`, historical commits `a96fdda2`, `b061c905` and `c20ce153`, and no current `release/*`, `feat/upgrade-queue-stacking` or `feat/ai-commander` heads on 2026-06-22.
- Finding: docs branch/Miksuu/perf still keep raw AI-order cost lookup and swapped debit at `Server_AI_Com_Upgrade.sqf:27,47,50`. Current stable resolves both maintained roots: current-level lookup at `:75`, affordability gates at `:89,92,97`, AI funds debit at `:125`, side supply debit at `:136` and opt-in funds-fallback surcharge at `:131-132`. Historical `a96fdda2`/`b061c905` fix debit order only, while historical `c20ce153` fixes cost/debit only in Chernarus.
- Result: refreshed [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix), [Upgrades and research](Upgrades-And-Research-Atlas#current-branch-scope), Feature Status, Source Fix queue, dashboard and pruning ledger. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T10:18:00+02:00 - Codex - B69 current-head 0a1ccb4d branch refresh

- Claimed `b69-current-head-0a1ccb4d-refresh-2026-06-22` after `origin/claude/b69` advanced beyond the documented Patch A/A-2 head `edb9f776`.
- Source scope: `origin/claude/b69@0a1ccb4d`, B68 base `origin/claude/b57-soak-proposals@b8a1505f`, prior B69 head `edb9f776`, empty maintained Vanilla diff for `b8a1505f..origin/claude/b69`, and `gh pr list --head claude/b69 --state all` returning `[]` on 2026-06-22.
- Finding: full B69 branch delta from B68 is now 13 files / +417 / -65, all Chernarus current mission plus `B69-IMPLEMENTATION-PLAN.md`; the post-`edb9f776` delta is 11 Chernarus files / +316 / -57. The branch now has source code for supervisor heartbeat/watchdog/jitter, territory-credit posture/garrison telemetry, relief min-alive, MHQ nudge, pending-slot reaper and bootstrap stipend hoist, plus branch-only QoL/FX additions. The HC-team metadata append is scaffolding until a top-up/merge consumer and smoke are recorded.
- Result: refreshed the AI commander audit, B69 roadmap/sketch note, Feature Status, dashboard, pruning ledger and machine rows so current B69 code is recorded without claiming stable, maintained Vanilla or release readiness. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T10:18:37+02:00 - Codex - Camp-count helper current-stable refresh

- Claimed `camp-count-helper-current-stable-refresh-2026-06-22` after [Feature status](Feature-Status-Register) and [Source fix queue](Source-Fix-Propagation-Queue) still cited stable `origin/master cf2a6d6a` as current camp-count fallback evidence.
- Source scope: docs branch `docs/developer-wiki-index@ade4d356`, current stable `origin/master@0139a346`, Miksuu `master@b8389e74`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, active B69 `origin/claude/b69@0a1ccb4d`, and no current origin `release/*`, `feat/*camp*` or `feat/*town*` heads on 2026-06-22.
- Finding: every checked maintained root still returns `1` for zero-camp towns at `Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16`. Current-stable consumers line-drift to `server_town.sqf:167-183`, `Client_GetRespawnAvailable.sqf:92` and `GUI_Menu_BuyUnits.sqf:120-121`; docs/perf, Miksuu, historical release and B69 each keep the same helper semantics with their own caller line drift.
- Result: refreshed [Towns, camps and capture](Towns-Camps-And-Capture-Atlas#current-branch-scope), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so future work stays focused on real-count versus safe-denominator semantics and 0/partial/all-camp smoke. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T10:41:06+02:00 - Codex - Camp flag texture current-stable refresh

- Claimed `camp-flag-texture-current-stable-refresh-2026-06-22` after Feature Status and Source Fix queue still cited stable `origin/master cf2a6d6a` as current camp-flag drift evidence.
- Source scope: docs branch `docs/developer-wiki-index@28a7d9c5`, current stable `origin/master@0139a346`, Miksuu `master@b8389e74`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, active B69 `origin/claude/b69@0a1ccb4d`, new `origin/feat/naval-hvt-objectives@2e1c5931`, and no current origin `release/*`, `feat/*camp*` or `feat/*town*` heads on 2026-06-22.
- Finding: docs branch and Miksuu still set independent camp-capture flag texture from old `_side`, perf fixes only Chernarus, and current stable/historical release/B69/naval HVT use `str _newSide` in both maintained roots. Every checked `repair-camp` path still changes camp `sideID` and broadcasts `CampCaptured` without `setFlagTexture`; current stable line drift is `Server_HandleSpecial.sqf:468,471`.
- Result: refreshed [Towns, camps and capture](Towns-Camps-And-Capture-Atlas#current-branch-scope), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so future code owners preserve the already-fixed independent capture branches while keeping repair-side flag refresh open. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T10:47:03+02:00 - Codex - Dead-code AI supply-truck current-stable refresh

- Claimed `dead-code-ai-supply-truck-current-stable-refresh-2026-06-22` after [Dead/stale code](Dead-Code-And-Stale-Code-Register#sqf-reachability-findings) still cited current `origin/master cf2a6d6a` for the AI supply-truck safe-disable row.
- Source scope: current docs checkout Chernarus and maintained Vanilla still comment the `UpdateSupplyTruck` compile at `Init_Server.sqf:36`, initialize `wfbe_ai_supplytrucks` at `:382` and raw-spawn `UpdateSupplyTruck` at `:383`; current stable `origin/master@0139a346` comments the compile at `:43` and warning-disables legacy logistics at `:462-463` in both maintained roots; `AI_UpdateSupplyTruck.sqf:17` still points at missing `Server/FSM/supplytruck.fsm`.
- Result: refreshed [Dead/stale code](Dead-Code-And-Stale-Code-Register#sqf-reachability-findings), dashboard, pruning ledger and coordination records so the dormant worker row matches the latest AI supply-truck current-stable anchor split. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T10:56:14+02:00 - Codex - Town AI vehicle despawn current-stable refresh

- Claimed `town-ai-vehicle-despawn-current-stable-refresh-2026-06-22` after [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety) and queue/status rows still cited stable `origin/master cf2a6d6a` as current DR-45 evidence.
- Source scope: docs checkout Chernarus/Vanilla still initializes `wfbe_active_vehicles` at `server_town_ai.sqf:30`, appends at `:161,:179`, deletes tracked vehicles at `:214` with only `!(isPlayer leader group _x)`, and clears at `:219`. Current stable `origin/master@0139a346` line-drifts to initialize `:41`, append `:238,:257`, delete `:309` and clear `:315` in both maintained roots. Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f`, historical `a96fdda2` and `origin/feat/aicom-fleet-improvements@cc5090bed4ad` remain unsafe with their own line drift.
- B69 note: active `origin/claude/b69@0a1ccb4d` has a Chernarus candidate crew guard at `server_town_ai.sqf:325`, plus player-unit guard at `:312`, but maintained Vanilla still deletes tracked vehicles with only the leader-player guard at `:319`. Treat B69 as branch evidence, not DR-45 closure.
- Result: in progress; no gameplay source changes planned.

## 2026-06-22T11:03:03+02:00 - Codex - Town AI vehicle despawn current-stable refresh complete

- Result: refreshed [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety#current-branch-matrix), Feature Status, Source Fix queue, Current Source Snapshot, Miksuu upstream intel and hardening rows so DR-45 now routes through current stable `origin/master@0139a346` instead of stale `cf2a6d6a` / `89ae9dad` evidence.
- Finding: current stable still deletes tracked `wfbe_active_vehicles` at `server_town_ai.sqf:309` without a player `crew` check in both maintained roots. Miksuu `b8389e748243`, `perf/quick-wins@0076040f`, historical `a96fdda2` and live `origin/feat/aicom-fleet-improvements@cc5090bed4ad` remain unsafe; B69 `origin/claude/b69@0a1ccb4d` is Chernarus candidate evidence only because maintained Vanilla remains old-shape.
## 2026-06-22T11:03:45+02:00 - Codex - Construction SmallSite logic current-stable refresh

- Claimed `construction-smallsite-logic-current-stable-refresh-2026-06-22` after [Source fix queue](Source-Fix-Propagation-Queue) and Feature Status still cited old stable `origin/master cf2a6d6a` evidence for the SmallSite/MediumSite `wfbe_structures_logic` asymmetry.
- Source scope: docs `3406ffa0`, current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f`, historical release `a96fdda2` and active B69 `origin/claude/b69@0a1ccb4d`; current origin exposes no `release/*`, `feat/*construction*`, `feat/*coin*` or `feat/*small*` heads on 2026-06-22.
- Finding: every checked maintained root still has SmallSite add/add at `Construction_SmallSite.sqf:70,99` and MediumSite add/remove at `Construction_MediumSite.sqf:70,114`; no checked branch rescues the one-line cleanup debt.
- Result: refreshed [Construction logic list cleanup](Construction-Logic-List-Cleanup#current-branch-matrix), [Construction and CoIn](Construction-And-CoIn-Systems-Atlas#smallsite--mediumsite), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T11:02:25+02:00 - Codex - Dead-code TaskSystem/map-blink current-stable refresh

- Claimed `dead-code-task-mapblink-current-stable-refresh-2026-06-22` after [Dead/stale code](Dead-Code-And-Stale-Code-Register), [Feature status](Feature-Status-Register) and [Abandoned feature revival](Abandoned-Feature-Revival-Review) still flattened old TaskSystem and old map-blink residue across stale stable/release wording.
- Source scope: docs checkout `docs/developer-wiki-index@3406ffa0`, current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins@0076040f`, historical `a96fdda2`, and no current origin `release/*`, `feat/*task*`, `feat/*blink*`, `feature/*task*` or `feature/*blink*` heads on 2026-06-22.
- Finding: docs/Miksuu/perf keep the old town `TaskSystem` comments plus `Client_TaskSystem.sqf`; current stable keeps only TaskSystem comment residue at `Client/Init/Init_Client.sqf:94,819` and `TownCaptured.sqf:36,88`, while `Client_TaskSystem.sqf` is absent. Current stable separately sends commander Objective Ping via `GUI_Menu_Command.sqf:336,344` and registers `SetTask` at `Common/Init/Init_PublicVariables.sqf:40`. Docs/Miksuu/perf also keep the old plural map-blink/AddUnitToTrack and server map-blink comments, but current stable and historical `a96fdda2` have already removed those old comments while preserving live singular `Client_BlinkMapIcon`.
- Result: refreshed [Dead/stale code](Dead-Code-And-Stale-Code-Register), [Feature status](Feature-Status-Register), [Abandoned feature revival](Abandoned-Feature-Revival-Review), dashboard, pruning ledger and coordination records. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T11:08:51+02:00 - Codex - Vehicle cargo loop-bounds current/Miksuu refresh

- Claimed `vehicle-cargo-loop-bounds-current-miksuu-refresh-2026-06-22` after [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), Feature Status and the Source Fix queue still flattened current stable, old Miksuu and historical branch evidence.
- Source scope, corrected later by direct Miksuu fetch: docs branch `docs/developer-wiki-index@b2544207`, current stable `origin/master@0139a346`, current Miksuu `master@b8389e74`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, historical EASA QoL commit `a66d4691`, and current origin head inventory showing no live `release/*` or `feat/buymenu-easa-qol` heads; the earlier `d9506078` Miksuu label was wrong and belongs to `origin/claude/*` GUER branch evidence.
- Finding: docs branch and historical EASA QoL still carry inclusive cargo loops in both maintained roots at `Common_EquipVehicle.sqf:27,33,39` and `Common_EquipBackpack.sqf:35,41`; current stable now uses corrected `count(_items)-1` bounds in both maintained roots, while direct current Miksuu `master@b8389e74` remains old-shape. Perf remains Chernarus-only for this fix.
- Result: refreshed [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows; the later correction keeps current stable fixed while direct current Miksuu, docs/EASA and perf-Vanilla old-shape targets remain patch-ready. No gameplay source changed.
- Validation: JSON/JSONL parse passed in wiki and docs mirror; `docs/validate-wiki.ps1` passed with known legacy JSONL envelope warnings; Latest Batch has five rows; touched-file SHA parity and top-level normalized wiki/docs parity passed; `git diff --check` passed in both worktrees with line-ending warnings only.

## 2026-06-22T11:22:03+02:00 - Codex - B69 finalpieces current-head refresh

- Claimed `b69-finalpieces-current-head-refresh-2026-06-22` after `origin/claude/b69-finalpieces` advanced to `80d3267c` and no `b69-finalpieces` / `finalpieces` wiki mention was found.
- Initial source scope: `origin/claude/b69-finalpieces@80d3267c` is a descendant of `origin/claude/b69@0a1ccb4d`; `git diff --stat origin/claude/b69..origin/claude/b69-finalpieces` reports 8 Chernarus AI commander/client files changed with +242 / -13 and no immediate maintained Vanilla path in that diff.
- Result: in progress; no gameplay source changes planned.

## 2026-06-22T11:27:50+02:00 - Codex - B69 finalpieces current-head refresh complete

- Verified `origin/claude/b69-finalpieces@80d3267c1b2b` as a descendant of `origin/claude/b69@0a1ccb4d05c5`; `0a1ccb4d..80d3267c` is 8 Chernarus AI commander/client files / +242 / -13 with no maintained Vanilla diff.
- PR route: GitHub PR #47 is open as `claude/b69-finalpieces` -> `claude/b69`, updated 2026-06-22T09:20:42Z. `gh pr list --head claude/b69 --state all` still returned no direct PR for `claude/b69`.
- Findings: finalpieces adds Chernarus town-punch multipliers, default armed-hull troop transport filtering and stranded survivor merge-before-cull. HC depleted-team merge/top-up remains default-off draft scaffolding because `AI_Commander.sqf:232-238` calls `WFBE_SE_FNC_AI_Com_HCTopUp` only if defined and `Init_Server.sqf:58-66` does not compile `AI_Commander_HCTopUp.DRAFT.sqf`.
- Result: refreshed the AI commander audit, B69 roadmap/sketch note, Feature Status, PR cleanup lab, dashboard, pruning ledger and machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T11:48:21+02:00 - Codex - Salvage payout current-head refresh

- Claimed `salvage-payout-current-head-refresh-2026-06-22` after salvage payout/loop rows still carried 2026-06-21 current-head wording.
- Source scope: docs branch `docs/developer-wiki-index@fb8d4ebc`, current stable `origin/master@0139a346`, current Miksuu `master@b8389e748243` verified by direct `git ls-remote` on 2026-06-22, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, no current origin `release/*` or `feat/*salvage*` heads, and historical Miksuu salvage heads `EngineerSalvageAbility@99bfaeb8` / `SalvageRuTranslationFix@291c6cb4`.
- Finding: all checked maintained roots still keep lowercase `ChangePlayerfunds` in both manual engineer and salvage-truck payout paths while client init compiles `ChangePlayerFunds`; all checked roots keep `updatesalvage.sqf:10` as `while {!gameOver || !(alive _vehicle)}` plus client-local wreck deletion/reward.
- Result: refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix), Feature Status, Source Fix queue, dashboard, pruning ledger and salvage machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T12:02:19+02:00 - Codex - Miksuu current-head `d9506078` correction

- Claimed `miksuu-current-head-d950-correction-2026-06-22` after several current-facing rows treated local `d9506078` as current Miksuu.
- Source scope: direct `git ls-remote https://github.com/miksuu/a2waspwarfare.git refs/heads/master` verified current Miksuu as `b8389e748243` on 2026-06-22. Local `d9506078` is contained by `origin/claude/a2a3-execute-nullguard`, `origin/claude/guer-build-coolunits` and `origin/claude/guer-build-vbied`, not current Miksuu upstream.
- Findings: current Miksuu `b8389e748243` is old-shape for the checked rows: inclusive vehicle/backpack cargo loops in both maintained roots, auto-wall false default/no SmallSite/MediumSite exclusions, no live maintained-root `WFBE_C_AI_MAX` reader, `WFBE_C_UNITS_CLEAN_TIMEOUT` comment-only cleanup split and ancestor-name-only LoadoutManager root discovery. Current stable `origin/master@0139a346` remains separate source-present/fixed evidence where documented.
- Result: refreshed cargo-loop, gear/loadout, construction/CoIn, mission-parameter, dead/stale, Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows. Historical Worklog/event entries that mentioned `d9506078` are superseded by this entry rather than rewritten. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T11:53:18+02:00 - Codex - MASH marker current-stable branch-scope refresh

- Claimed `mash-marker-current-stable-branch-scope-refresh-2026-06-22` after the MASH marker relay row still used older stable/release wording while current stable `origin/master@0139a346` and B69-family heads now show the maintained MASH deploy module path removed.
- Initial source scope: docs checkout `HEAD@db3015f1`, current stable `origin/master@0139a346`, current Miksuu fetched from `https://github.com/miksuu/a2waspwarfare.git` at `b8389e748243`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, `origin/claude/b69` and `origin/claude/b69-finalpieces`.
- Initial finding: docs/perf/Miksuu-shaped maintained roots keep local MASH deploy plus commented client receiver and server marker relay; current stable, historical release and B69-family maintained roots carry `Skill_Apply.sqf:43` MASH-deploy-removed wording, with residual config/string MASH/FARP entries still present.
- Result: refreshed Respawn lifecycle, Feature Status, Abandoned Feature Revival, Dead/stale code, Public Variable Channel Index, Support Specials, adjacent module/UI/hardening routes and machine rows so old-shape MASH deploy/relay evidence is no longer flattened with current stable/B69 deploy-path removal. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T12:18:09+02:00 - Codex - Service/EASA affordability current-stable refresh

- Claimed `service-easa-affordability-current-stable-refresh-2026-06-22` after the service affordability owner page, Feature Status, Source Fix queue and hardening rows still mixed older `89ae9dad` / release wording with current stable `origin/master@0139a346`.
- Source scope: docs checkout `db3015f18ea3`, current stable `origin/master@0139a346`, current Miksuu upstream `master@b8389e74` from the direct Miksuu correction lane, `origin/perf/quick-wins@0076040f`, historical release `a96fdda2`, historical EASA QoL `a66d4691`, local checkpoint `d9506078` and B69 finalpieces `origin/claude/b69-finalpieces@80d3267c`.
- Findings: docs checkout and current Miksuu keep old direct service rearm/refuel debits and strict EASA `_funds > price`; current stable, local `d9506078` and historical release partially guard service rearm/refuel but still leave repair/heal and broader action-time context/funds authority open; B69 finalpieces has Chernarus-only exact-funds EASA candidate evidence while maintained Vanilla remains strict `>`.
- Result: refreshed [Service menu affordability guards](Service-Menu-Affordability-Guards), [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T12:32:37+02:00 - Codex - B69 PR47 merged head refresh

- Claimed `b69-pr47-merged-head-refresh-2026-06-22` after `git fetch origin` advanced `origin/claude/b69` from `0a1ccb4d05c5` to merge commit `0094647d7b64`.
- Initial source scope: PR #47 is now merged as `claude/b69-finalpieces` -> `claude/b69` with merge commit `0094647d7b641bb79202e77e7f480d6d39aadcdb` and `mergedAt` / `updatedAt` `2026-06-22T10:23:16Z`; `origin/claude/b69^1` is `0a1ccb4d05c5`, `origin/claude/b69^2` is `80d3267c1b2b`, and `origin/claude/b69-finalpieces` is an ancestor of the new B69 head.
- Initial finding: the merge delta `0a1ccb4d05c5..0094647d7b64` is the previously documented finalpieces set, 8 Chernarus AI commander/client files / +242 / -13 with no maintained Vanilla diff. The branch is now B69-head evidence, not a still-open stacked PR; no gameplay source changes planned.
- Result: refreshed the AI commander audit, B69 roadmap/sketch note, Feature Status, PR cleanup lab, dashboard, pruning ledger and machine rows so PR #47 is recorded as merged into `claude/b69` while B69 remains Chernarus-only, smoke-pending and not master/stable evidence. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T12:46:28+02:00 - Codex - Empty supply-truck timeout current-stable refresh

- Claimed `empty-supply-truck-timeout-current-stable-refresh-2026-06-22` after [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas), Feature Status and Source Fix queue still cited older `cf2a6d6a` stable evidence and live-release wording for the 24-hour empty supply-truck cleanup timeout.
- Source scope: docs head `b4e10b5f`, current stable `origin/master@0139a346`, direct current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f`, B69 `origin/claude/b69@0094647d` and B69 finalpieces `origin/claude/b69-finalpieces@80d3267c`. Current origin exposed no `release/*`, `feat/*cleanup*`, `feat/*supply*`, `feature/*cleanup*` or `feature/*supply*` heads; historical `a96fdda2` is available in this source checkout and matches the 24-hour policy, but remains historical-only evidence rather than current release proof.
- Finding: every checked maintained root still drains `WF_Logic` `emptyVehicles` through `emptyvehiclescollector.sqf:9-19,30` and `WFBE_SE_FNC_HandleEmptyVehicle`; docs/Miksuu/perf use `Server_HandleEmptyVehicle.sqf:22-23,27,30,33`, while current stable and B69-family refs line-drift to `:30-31,35,38,41`. Both shapes still set supply-truck `_delay = 86400`.
- Result: refreshed the owner matrix, Feature Status, Source Fix queue, dashboard and pruning ledger so future work stays focused on the keep-and-label versus shorter/parameterized logistics decision, not stale stable/release anchors. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T12:55:05+02:00 - Codex - Supply scan current-stable refresh

- Claimed `supply-scan-current-stable-refresh-2026-06-22` after supply scan owner/status rows still mixed older `89ae9dad`, `cf2a6d6a` and live-release wording with current stable `origin/master@0139a346`.
- Source scope: docs branch `origin/docs/developer-wiki-index@15563691`, current stable `origin/master@0139a346`, direct current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2`, local release-line commit `7ff18c49`, and no current origin `release/*` or supply feature heads.
- Findings: docs/source keeps the truck-only typed command-center scan at `supplyMissionStarted.sqf:25,28,44`; current stable carries the heli-aware typed scan at `:7,55,61,83`; current Miksuu and perf still broad-enumerate/post-filter at `:25,28,44`; historical release-line commits carry the heli-aware typed shape but are not live release heads.
- Result: refreshed [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [Supply mission architecture](Supply-Mission-Architecture), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Current source snapshot](Current-Source-Status-Snapshot), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T13:05:42+02:00 - Codex - Gear template profile current-head refresh

- Claimed `gear-template-profile-current-head-refresh-2026-06-22` after the gear profile/template rows still used a 2026-06-21 docs-head anchor while current docs head is `72b5f0de98f9`.
- Initial source scope: docs head `72b5f0de98f9`, current stable `origin/master@0139a3468609`, current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f8a5e`, historical release `a96fdda28087` and historical EASA QoL `a66d46912e2a`.
- Initial finding: docs head, current Miksuu, perf, historical release and EASA QoL still keep undefined `_u_upgrade` save filtering at `Client_UI_Gear_SaveTemplateProfile.sqf:33,52,75` plus the six-field import guard/index-6 read at `Init_ProfileGear.sqf:17,25` in both maintained roots. Current stable fixes only the save-filter comparison at `Client_UI_Gear_SaveTemplateProfile.sqf:34,57,82`; it still keeps the six-field import guard. No gameplay source changes planned.
- Result: refreshed [Gear template profile filter](Gear-Template-Profile-Filter), [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so the branch split uses current docs head `72b5f0de98f9` while preserving the current-stable save-filter/import-guard split. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T13:09:06+02:00 - Codex - Supply mission economy/PR follow-up

- Claimed `supply-mission-economy-pr-current-stable-followup-2026-06-22` after the concurrent `supply-scan-current-stable-refresh-2026-06-22` lane refreshed the canonical scan/architecture matrix but the economy overview and PR #1 page still carried older stable/release wording.
- Source scope: docs/source `15563691`, current stable `origin/master@0139a346`, direct current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f`, and PR #1 metadata (`feat/supply-helicopter` closed/unmerged, no live origin `release/*`, supply or heli feature heads on 2026-06-22).
- Findings: current stable is the live supply-heli/cash-run baseline in both maintained roots, while PR #1 is historical branch-review evidence and docs/source, current Miksuu and perf remain truck-only. Economy copy needed to stop presenting stale stable/release rows as current branch truth.
- Result: refreshed [Current PR #1 supply helicopters](Current-Work-Supply-Helicopters-PR1) and [Economy, towns and supply](Economy-Towns-And-Supply) to route current truth through the new supply architecture matrix. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T13:19:10+02:00 - Codex - B69 PR48 / PR49 branch-head refresh

- Claimed `b69-pr48-b71-harvest-head-refresh-2026-06-22` after `git fetch origin` showed `origin/claude/b69` advanced from documented merge head `0094647d7b64` to merge commit `4dcc10b143a0fc4d94e55f5506217d208994d4ff`.
- Initial source scope: PR [#48](https://github.com/rayswaynl/a2waspwarfare/pull/48) is merged as `claude/b71-pr-harvest` -> `claude/b69`, merge commit `4dcc10b143a0fc4d94e55f5506217d208994d4ff`, mergedAt / updatedAt `2026-06-22T11:06:12Z`; first parent is `0094647d7b64` and second parent is `9cad74c4b6d3`.
- Initial finding: `0094647d7b64..4dcc10b143a0` is 6 current Chernarus mission files / +40 / -13 with no maintained Vanilla diff. The harvested changes cover PR #40 town-marker/map-gate and terrain-grid residuals, faction vehicle tint side-resolution with tint default-off, and a 50-iteration water-reject cap in `Common_GetRandomPosition.sqf`. `gh pr list --head claude/b69 --state all` still returns no direct `claude/b69` master-target PR, so this is B69 branch evidence only. No gameplay source changes planned.
- Follow-up source scope: a final `git fetch origin --prune` before push advanced `origin/claude/b69` again to PR [#49](https://github.com/rayswaynl/a2waspwarfare/pull/49), merged as `claude/b72-tints-on` -> `claude/b69` at `39eed5c02d8ba9c5a27b7a4173607526edc0677e` on 2026-06-22T11:47:23Z; first parent is `4dcc10b143a0` and second parent is `7e1026ea`.
- Follow-up finding: `4dcc10b143a0..39eed5c0` is one current Chernarus constants file / +1 / -1 with no maintained Vanilla diff. It flips `WFBE_C_VEHICLE_TINTS` from nil-guard default `0` to `1` at `Common/Init/Init_CommonConstants.sqf:795`; the adjacent comment still carries the older default-off / in-engine cosmetic-check caveat, so this is B69/B72 A/B branch evidence only.
- Result: refreshed the AI commander audit, B69 roadmap/sketch note, Feature Status, PR cleanup lab, dashboard, pruning ledger and machine rows so PR #49 is recorded as the current `claude/b69` head while B69 remains Chernarus-only, smoke-pending and not master/stable evidence. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T14:02:46+02:00 - Codex - Side-supply B69 current-head refresh

- Claimed `side-supply-b69-current-head-refresh-2026-06-22` after the dashboard still named side-supply clamp as a next lane and the side-supply matrix did not include current B69 evidence.
- Source scope: docs branch `4db90f1c`, current stable `origin/master@0139a346`, current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f`, B69 `origin/claude/b69@39eed5c0`, historical release commit `a96fdda2`, and no live origin `release/*` heads.
- Findings: docs/source is source-unchanged from `7047da5d9` / `f52ccee8` for checked side-supply and reason paths; docs/current stable/current Miksuu/historical release still keep `_currentSupply - _amount` and payload-side trust in both maintained roots. Perf fixes only the Chernarus arithmetic floor. B69 fixes Chernarus server arithmetic at `Server_ChangeSideSupply.sqf:12,36,60` and adds Chernarus `wfbe_supply_temp_resistance` at `:25-45`, but maintained Vanilla remains old-shape and side/channel/requester validation plus reason parsing remain open.
- Result: refreshed [Economy authority first cut](Economy-Authority-First-Cut), [Economy, towns and supply](Economy-Towns-And-Supply), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T14:18:00+02:00 - Codex - Resistance supply scaffold B69 branch refresh

- Claimed `resistance-supply-scaffold-b69-branch-refresh-2026-06-22` after [Resistance supply scaffold](Resistance-Supply-Scaffold) contradicted itself on whether source Chernarus had `WFBE_L_GUE` owner logic, and after the prior B69 side-supply lane exposed a Chernarus-only resistance temp-channel candidate.
- Source scope: docs branch `e46a7330`, current stable `origin/master@0139a346`, current Miksuu `master@b8389e748243` verified by direct `git ls-remote`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2` and B69 `origin/claude/b69@39eed5c0`.
- Findings: docs/Miksuu/perf/historical refs have the `Init_Common.sqf:280` present-side loop but no checked maintained-root `WFBE_L_GUE` mission owner logic and no `wfbe_supply_temp_resistance` handler; their `Common_GetSideSupply.sqf:36-44` resistance branch still hits the blocking request/wait path. Current stable defines `WFBE_L_GUE` in Chernarus `mission.sqm:4928,4931` and Vanilla `:4198,4201`, and changes resistance reads to a funds-only non-blocking `0` default at `Common_GetSideSupply.sqf:36-40`, but still registers only west/east temp handlers. B69 adds `wfbe_supply_temp_resistance` only in Chernarus at `Server_ChangeSideSupply.sqf:25-45`; B69 Vanilla remains west/east only.
- Result: refreshed [Resistance supply scaffold](Resistance-Supply-Scaffold), cross-linked the economy and source-fix routes, updated dashboard/pruning/coordination records and kept the broader side-supply clamp/authority queue unchanged. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T14:29:13+02:00 - Codex - Resistance side-supply Feature Status follow-up

- Claimed `resistance-side-supply-feature-status-followup-2026-06-22` after [Feature status](Feature-Status-Register) still carried the old one-line "server handlers exist only for west/east" wording even though the scaffold page now has a branch matrix for current stable and B69.
- Source scope: docs `HEAD@56370c44` source-unchanged from `4db90f1c` for checked mission paths, current stable `origin/master@0139a346`, current Miksuu `master@b8389e748243` verified by direct `git ls-remote`, `origin/perf/quick-wins@0076040f`, historical release `a96fdda2` and B69 `origin/claude/b69@39eed5c0`.
- Findings: docs/current Miksuu/perf/historical publish generic `wfbe_supply_temp_<side>` at `Common_ChangeSideSupply.sqf:28,30` but have no checked maintained-root `WFBE_L_GUE` owner logic, no resistance temp handler and blocking resistance reads at `Common_GetSideSupply.sqf:40-43`. Current stable has `WFBE_L_GUE` owner logic at Chernarus `mission.sqm:4928,4931` and Vanilla `:4198,4201` plus funds-only `0` reads at `Common_GetSideSupply.sqf:36-40`, but only west/east temp handlers. B69 adds Chernarus `wfbe_supply_temp_resistance` at `Server_ChangeSideSupply.sqf:25-45`; B69 Vanilla remains west/east only.
- Result: refreshed the stale Feature Status row and `side-supply-clamp-first` machine row to route details through [Resistance supply scaffold](Resistance-Supply-Scaffold#current-branch-matrix) and [Economy authority](Economy-Authority-First-Cut#side-supply-branch-matrix). No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T14:48:39+02:00 - Codex - Hosted FPS current-stable/dev-branch route

- Claimed `hosted-fps-current-stable-dev-branch-route-2026-06-22` after hosted-FPS route pages still said `origin/dev/july-update-hosted-server-fps-loop-fix` existed and several rows carried stale stable `cf2a6d6a` / docs `db7667c9` line anchors.
- Source scope: docs HEAD `d0161083035b` is source-unchanged from `a27086cd` for checked hosted-FPS paths; current stable `origin/master@0139a3468609`; current Miksuu `master@b8389e748243`; `origin/perf/quick-wins@0076040f`; historical release commit `a96fdda28087`; no current `origin/dev/july-update-hosted-server-fps-loop-fix` or `release/*` head was found on 2026-06-22.
- Findings: docs/source Chernarus and maintained Vanilla still use the two guarded publisher shape (`serverFpsGUI.sqf:1`, `monitorServerFPS.sqf:1`, `Init_Server.sqf:578,595`). Current stable uses the single guarded `SERVER_FPS_GUI` publisher (`serverFpsGUI.sqf:4`, publish at `:9-10`), starts it from `Init_Server.sqf:769`, documents monitor removal at `:815-817`, and has no maintained-root monitor file. Historical `a96fdda2` matches the single-publisher shape with older anchors `:579` and `:595-597`; Miksuu/perf remain old-loop-shaped.
- Result: refreshed hosted-FPS owner/status/runtime/roadmap/testing pages plus hardening, release-readiness, feature-status, machine-index and agent-context records so future work creates/restores the July target branch first and smokes the chosen publisher shape. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T15:01:41+02:00 - Codex - Patrols v2 HC topology current-stable refresh

- Claimed `headless-patrols-v2-topology-current-stable-refresh-2026-06-22` after [Headless client scaling and topology](Headless-Client-Scaling-And-Topology) still said patrols were structurally server-pinned and cited stale current `cf2a6d6a` Patrols v2 HC anchors.
- Source scope: docs HEAD `ff5b95dabb06`, current stable `origin/master@0139a3468609`, direct current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f`, historical release-line commit `a96fdda28087`, and historical stable `cf2a6d6a4f96`. Current origin exposes no live `release/*` heads on 2026-06-22.
- Findings: current stable carries the same Patrols v2 files/handlers in Chernarus and maintained Vanilla: both start `server_side_patrols.sqf` from `Init_Server.sqf:690`, dispatch a live HC or local runner at `server_side_patrols.sqf:64-69`, receive `delegate-sidepatrol` at `Client/PVFunctions/HandleSpecial.sqf:50`, keep runner locality at `Common_RunSidePatrol.sqf:5-8`, and report slot/marker events through `Common_RunSidePatrol.sqf:54-56,82-84,245-247,264-266`, `Server_HandleSpecial.sqf:345-372` and `Client/FSM/updatepatrolmarkers.sqf:3,19`. Docs HEAD, current Miksuu, perf and `a96fdda2` lack Patrols v2 files in checked maintained roots; `cf2a6d6a` is historical stable evidence only.
- Static-defence follow-up: the same topology page also kept a stale west/east side-gate claim. Current stable calls the spawn path with the active town side (`server_town.sqf:290`; `server_town_ai.sqf:262`) and the HC delegate branch has no west/east/resistance side gate at `Server_OperateTownDefensesUnits.sqf:55-67`; DR-42 report-back/accounting and all-sides smoke remain open.
- Multi-HC follow-up: current stable town delegation is not the old blind random selector; `Server_DelegateAITownHeadless.sqf:22-56` hoists the least-loaded scan and round-robins groups from that seed. Remaining Mode 2 debt is FPS gating, per-HC group-death tracking, robust fallback and vehicle hand-back.
- Result: refreshed the topology page, dashboard, pruning ledger and machine records so Patrols v2 is described as current-stable partial HC support, old refs are treated as branch-scoped, server-pinned categories stay limited to purchases/support/AI respawn/supply trucks plus old-branch patrol systems, and multi-HC wording matches current least-loaded/round-robin source. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T15:29:46+02:00 - Codex - AI/HC runtime current-stable line-anchor refresh

- Claimed `ai-hc-runtime-current-stable-line-anchor-refresh-2026-06-22` after [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [AI/headless/performance](AI-Headless-And-Performance) and [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook) still mixed docs-source / stale `cf2a6d6a` line refs with current stable HC registration, static-defense and Patrols v2 evidence.
- Source scope: docs HEAD `4b6f5ca9` is source-unchanged from `ca028bff`, `d30d2346` and `ff5b95dabb06` for checked AI/HC paths; current stable `origin/master@0139a3468609` has identical Chernarus and maintained Vanilla HC/runtime files for checked paths; direct Miksuu master is `b8389e748243`; `origin/perf/quick-wins@0076040f` and historical release-line `a96fdda2` remain branch-scoped; current origin exposes no live `release/*` heads.
- Findings: current stable HC boot has reseat/deadspawn/reannounce plus idempotent `connected-hc` registration (`Init_HC.sqf:94-129`; `Server_HandleSpecial.sqf:406-431`); town HC delegation is least-loaded plus round-robin and reports groups/vehicles back (`server_town_ai.sqf:242-248`; `Server_DelegateAITownHeadless.sqf:22-56`; `Client_DelegateTownAI.sqf:29-44`; `Server_HandleSpecial.sqf:86-115`); static-defense HC delegation uses the active town side without a side gate but still has no update-back/work record (`Server_OperateTownDefensesUnits.sqf:55-67`; `Client_DelegateAIStaticDefence.sqf:39`); Patrols v2 current-stable refs use the same HC/local dispatch anchors as the topology lane.
- Result: refreshed the three AI/HC pages so stale docs-source/historical refs are branch-scoped, current-stable line anchors are explicit, the old "resistance-only static defenses" wording is replaced with active-side/no-side-gate wording, and future work focuses on DR-21/DR-42 work records, callback/failback and Arma smoke instead of side-gate patches. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T15:51:38+02:00 - Codex - B69 Takistan AICOM port current-head refresh

- Claimed `b69-takistan-aicom-port-current-head-refresh-2026-06-22` after `origin/claude/b69` advanced beyond the documented `39eed5c0` head and `origin/claude/tk-aicom-port` appeared.
- Source scope: `origin/claude/b69@b8530477ce4f8cc66c60a5d310a85d25c9cbc27c`, `origin/claude/tk-aicom-port@3b1106a1123e877e95d7abe11b817179b5761c50`, base `39eed5c0b389dd57c1a81ff68af60374f1f29d10`, B68 head `b8a1505f8a89881f487a03262f066c8b33eca94d`, current stable `origin/master@0139a34686099889093e77e3f3a5cadbb607a0b7`, and PR [#50](https://github.com/rayswaynl/a2waspwarfare/pull/50) metadata from `gh pr view`.
- Findings: PR #50 merged `claude/tk-aicom-port` into `claude/b69` on 2026-06-22T13:33:48Z; `39eed5c0..b8530477` is 22 maintained Vanilla/Takistan files / +2499 / -147, and `b8a1505f..b8530477` is 44 files / +3198 / -238 across `B69-IMPLEMENTATION-PLAN.md`, current Chernarus and maintained Vanilla/Takistan. `git diff --name-status origin/claude/tk-aicom-port..origin/claude/b69` is empty, so the merge commit tree matches the port branch. `gh pr list --head claude/b69 --state all` still returns no direct B69 PR.
- Source anchors: Takistan B69 branch now has AICOM constants at `Common/Init/Init_CommonConstants.sqf:630-652,691-700`, supervisor compile/spawn/watchdog at `Server/Init/Init_Server.sqf:58-67,1015-1057`, GUER air-defense launch/worker at `Init_Server.sqf:789-795` plus `Server/Server_GuerAirDef.sqf:37-58,72-76,243-252`, client marker/PV support at `Client/Init/Init_Client.sqf:494-496` and `Client/PVFunctions/HandleSpecial.sqf:52-67`, and nil-guarded HC top-up scaffolding at `AI_Commander.sqf:228-238`; `Init_Server.sqf:58-67` still does not compile `WFBE_SE_FNC_AI_Com_HCTopUp`.
- Result: refreshed [Feature status](Feature-Status-Register), [AI commander autonomy audit](AI-Commander-Autonomy-Audit#b69-roadmap-and-sketch-route), [B69 roadmap](AI-Commander-B69-Improvement-Roadmap#current-branch-status), [B69 implementation sketches](AI-Commander-B69-Implementation-Sketches), [PR cleanup lab](PR-Cleanup-And-Integration-Lab), dashboard, pruning ledger and coordination records. The old current-B69 "no maintained Vanilla propagation" wording is now corrected to "branch-propagated to maintained Vanilla/Takistan, still not master/stable or Arma-smoked proof." No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T16:08:52+02:00 - Codex - July FPV branch-route current-head refresh

- Claimed `july-fpv-branch-route-current-head-refresh-2026-06-22` after July route pages and machine records still treated `dev/july-takistan-airfield-fpv-drone` as the current branch for the Takistan captured-airfield FPV drone lane.
- Source scope: fresh 2026-06-22 remote checks found `origin/dev/july-2026-update@e3f530ed5bb6c80da9d4b184086b493d946baf23`, `origin/feat/drone-saturation-strike@8ca4be9096e5665aa77d336a59099500fab59bd4` and `origin/feat/recon-uav@563418eaafc99b7ed696de087848bfe573f73109`, but no current `origin/dev/july-takistan-airfield-fpv-drone` head. PR [#21](https://github.com/rayswaynl/a2waspwarfare/pull/21) is a closed unmerged draft from `dev/july-2026-update` to `release/2026-06-feature-bundle`, head `e3f530ed`, base `1701586d`.
- Findings: `origin/dev/july-2026-update:docs/july-2026-update.md` is a roadmap scaffold that names the Takistan captured-airfield FPV drone as the flagship, links to [Takistan airfield FPV drone design](Takistan-Airfield-FPV-Drone-Design), keeps owner decisions open and states planning/no gameplay code yet. `feat/drone-saturation-strike` and `feat/recon-uav` are separate branch-only drone/UAV features, not this captured-airfield FPV implementation branch.
- Result: refreshed [Progress dashboard](Progress-Dashboard#july-update-to-do), [Takistan airfield FPV drone design](Takistan-Airfield-FPV-Drone-Design), [Hardening roadmap](Hardening-Implementation-Roadmap#july-update-candidate-route), [Testing workflow](Testing-Debugging-And-Release-Workflow#july-update-candidate-smoke-route), the Coordination Board caveat, `agent-machine-index.json` and `agent-release-readiness.json` so future owners create or restore an implementation branch before code work. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T16:17:23+02:00 - Codex - B69 B73 troop-truck current-head refresh

- Claimed `b69-b73-troop-truck-current-head-refresh-2026-06-22` after `origin/claude/b69` advanced from PR #50 merge `b8530477` to PR #51 merge `8d465fce`.
- Source scope: `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`, `origin/claude/ch-truck-fix@70a1c8086b373f5394d1a805c2980dc078e47faf`, PR [#51](https://github.com/rayswaynl/a2waspwarfare/pull/51) metadata, base `b8530477ce4f8cc66c60a5d310a85d25c9cbc27c` and current stable `origin/master@0139a34686099889093e77e3f3a5cadbb607a0b7`.
- Findings: PR #51 merged `claude/ch-truck-fix` into `claude/b69` on 2026-06-22T14:03:51Z; `b8530477..8d465fce` is one Chernarus AI commander file / +5 / -1 with no maintained Vanilla/Takistan diff, and the full `b8a1505f..8d465fce` B69 diff is 44 files / +3203 / -239. Chernarus `AI_Commander_Teams.sqf:414-418` gates the B66 pure-infantry troop-truck prepend on `WFBE_C_AICOM_ARMED_TRANSPORT_ONLY <= 0`, preventing unarmed empty trucks when `Common_RunCommanderTeam` refuses them under armed-transport-only mode.
- Result: refreshed [Feature status](Feature-Status-Register), [AI commander autonomy audit](AI-Commander-Autonomy-Audit#b69-roadmap-and-sketch-route), [B69 roadmap](AI-Commander-B69-Improvement-Roadmap#current-branch-status), [B69 implementation sketches](AI-Commander-B69-Implementation-Sketches), [PR cleanup lab](PR-Cleanup-And-Integration-Lab), dashboard, pruning ledger and coordination records. PR #50 remains the maintained Vanilla/Takistan propagation proof; PR #51 is Chernarus-only until propagated and smoked. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T16:40:21+02:00 - Codex - WASP marker wait current-stable propagation refresh

- Claimed `wasp-marker-wait-current-stable-propagation-refresh-2026-06-22` after the WASP marker wait owner/status rows contradicted themselves and still said current stable needed the one-line display-54 throttle.
- Source scope: docs/source `HEAD@46840f048bd4`, current stable `origin/master@0139a34686099889093e77e3f3a5cadbb607a0b7`, current B69 `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`, current Miksuu upstream `master@b8389e7482438edd00f420c5bb795ac0a642971f`, `origin/perf/quick-wins@0076040f8a5e`, Chernarus fix commit `4805c778876daee85af8b2a93a133e03f6b165b0`, maintained Vanilla propagation commit `9b49883cb936269c8fae202e524f789ac0849490`, and a 2026-06-22 no-`release/*` remote check.
- Findings: docs/source Chernarus and maintained Vanilla still load `WASP\global_marking_monitor.sqf` at `Init_Client.sqf:267` and keep the unslept display-54 loop at `global_marking_monitor.sqf:57,62,64,68-69`, with display-12 already throttled at `:80`. Current stable launches at `Init_Client.sqf:309` and has `sleep 0.1` at `global_marking_monitor.sqf:64` before `findDisplay 54` in both maintained roots; current B69 matches that helper shape with launch line drift to `Init_Client.sqf:397`. Current Miksuu and perf remain old-shape in both maintained roots.
- Result: refreshed [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup), [Performance opportunity sweep](Performance-Opportunity-Sweep), [WASP overlay](WASP-Overlay), [Codebase coverage ledger](Codebase-Coverage-Ledger), [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Current source snapshot](Current-Source-Status-Snapshot), dashboard, pruning ledger and machine rows. Stable/B69 should not reopen the one-line throttle; old-shape targets need the throttle or an intentional `waitUntil` refactor, and all targets still need marker-dialog smoke. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T17:01:15+02:00 - Codex - Side-supply current B69 head refresh

- Claimed `side-supply-current-b69-head-refresh-2026-06-22` after side-supply/resistance-supply rows still used `origin/claude/b69@39eed5c0` as current B69 evidence even though PR #50/#51 advanced B69 to `8d465fce`.
- Source scope: current B69 `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`, prior side-supply proof commit `39eed5c0`, current stable `origin/master@0139a3468609`, current Miksuu `master@b8389e7482438edd00f420c5bb795ac0a642971f`, `origin/perf/quick-wins@0076040f8a5e` and no current `release/*` heads.
- Findings: `git diff --name-status 39eed5c0..origin/claude/b69` is empty for checked side-supply paths. Current B69 still has the Chernarus candidate shape: `Server_ChangeSideSupply.sqf:12,36,60` floors west/resistance/east negatives to `0`, `:25` registers `wfbe_supply_temp_resistance`, and Chernarus `Common_ChangeSideSupply.sqf:20-22` removes dead local clamp arithmetic. B69 maintained Vanilla remains old-shape at `Common_ChangeSideSupply.sqf:25` and `Server_ChangeSideSupply.sqf:12,36`. Current stable and Miksuu remain old-shape in both maintained roots; perf fixes only Chernarus arithmetic.
- Result: refreshed [Economy authority first cut](Economy-Authority-First-Cut), [Resistance supply scaffold](Resistance-Supply-Scaffold), [Economy, towns and supply](Economy-Towns-And-Supply), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `39eed5c0` is provenance and `8d465fce` is the current B69 branch head. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T17:15:28+02:00 - Codex - Town AI vehicle despawn current B69 head refresh

- Claimed `town-ai-vehicle-despawn-current-b69-head-refresh-2026-06-22` after the town-AI player-safety row still used `origin/claude/b69@0a1ccb4d` as current B69 evidence even though later B69 PR merges advanced the branch to `8d465fce`.
- Source scope: docs/source `HEAD@948db4ab`, current stable `origin/master@0139a3468609`, current Miksuu `master@b8389e7482438edd00f420c5bb795ac0a642971f`, `origin/perf/quick-wins@0076040f8a5e`, historical release `a96fdda28087`, `origin/feat/aicom-fleet-improvements@cc5090bed4ad`, prior B69 proof `0a1ccb4d` and current B69 `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`.
- Findings: `git diff --name-status 0a1ccb4d..origin/claude/b69` is empty for checked Chernarus/Vanilla `server_town_ai.sqf` paths. Current B69 Chernarus still keeps the candidate crew scan at `server_town_ai.sqf:325`, but B69 maintained Vanilla remains unsafe at `:319`. Docs/source, current stable, Miksuu, perf, historical release and aicom-fleet refs still delete tracked town-AI vehicles with only `!(isPlayer leader group _x)` in both maintained roots. No checked current ref contains `Server_CleanupExpiredTownDefenseAssets.sqf`.
- Result: refreshed [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `0a1ccb4d` is provenance and `8d465fce` is the current B69 branch head. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T17:23:06+02:00 - Codex - Construction SmallSite logic current B69 head refresh

- Claimed `construction-smallsite-logic-current-b69-head-refresh-2026-06-22` after construction SmallSite logic-list rows still used `origin/claude/b69@0a1ccb4d` as current B69 evidence even though later B69 PR merges advanced the branch to `8d465fce`.
- Source scope: docs/source `HEAD@6b8eba5e` is unchanged from `3406ffa0` for checked construction paths; current stable `origin/master@0139a3468609`, current Miksuu `master@b8389e7482438edd00f420c5bb795ac0a642971f`, `origin/perf/quick-wins@0076040f8a5e`, historical release `a96fdda28087`, prior B69 proof `0a1ccb4d` and current B69 `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`.
- Findings: `git diff --name-status 0a1ccb4d..origin/claude/b69` is empty for checked Chernarus/Vanilla `Construction_SmallSite.sqf` and `Construction_MediumSite.sqf` paths. All checked refs keep SmallSite add/add at `Construction_SmallSite.sqf:70,99` while MediumSite removes at `Construction_MediumSite.sqf:70,114` in both maintained roots. Fresh remote checks found no current `release/*`, `feat/*construction*`, `feat/*coin*` or `feat/*small*` head.
- Result: refreshed [Construction logic list cleanup](Construction-Logic-List-Cleanup), [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `0a1ccb4d` is provenance and `8d465fce` is the current B69 branch head. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T17:36:19+02:00 - Codex - Camp-count helper current B69 head refresh

- Claimed `camp-count-helper-current-b69-head-refresh-2026-06-22` after camp-count helper rows still used `origin/claude/b69@0a1ccb4d` as current B69 evidence even though later B69 PR merges advanced the branch to `8d465fce`.
- Source scope: docs/source `HEAD@91d1ccf2a04d` is unchanged from `ade4d356` for checked Chernarus/Vanilla helper/caller paths; current B69 `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf` is unchanged from `0a1ccb4d` for the same paths; current stable is `origin/master@0139a3468609`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087`; current origin exposes no `release/*`, `feat/*camp*` or `feat/*town*` heads.
- Findings: all checked refs keep `Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16` returning `1` for zero-camp towns in both maintained roots. The same helper semantics still feed capture mode 2/capture-rate math, `Common_GetRespawnThreeway.sqf:7` through `Client_GetRespawnAvailable.sqf`, and depot infantry buy gates. Current docs/source consumers are `server_town.sqf:179-195`, `Client_GetRespawnAvailable.sqf:69` and `GUI_Menu_BuyUnits.sqf:111-112`; current B69 line drift is `server_town.sqf:188-204`, `Client_GetRespawnAvailable.sqf:92` and `GUI_Menu_BuyUnits.sqf:120-121`.
- Adjacent atlas check: `git diff --name-status 0a1ccb4d..origin/claude/b69` is also empty for checked B69 camp flag and `repair-camp` paths, so the camp-flag matrix can name current B69 `8d465fce` while preserving `0a1ccb4d` as provenance.
- Result: refreshed [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `0a1ccb4d` is provenance and `8d465fce` is the current B69 branch head. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T17:54:53+02:00 - Codex - PVF sender-auth current B69 head refresh

- Claimed `pvf-sender-auth-current-b69-head-refresh-2026-06-22` after DR-55/PVF rows still used `origin/claude/b69@0a1ccb4d` as current B69 evidence even though later B69 PR merges advanced the branch to `8d465fce`.
- Source scope: docs/source `HEAD@4d4610f1e429` is unchanged from `ade4d356` for checked Chernarus/Vanilla PVF init/dispatcher paths; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087`; current origin exposes no `release/*`, `feat/*pvf*`, `feat/*network*`, `feat/*auth*` or `feat/*public*` heads.
- Findings: docs/source, Miksuu and perf keep value-only PVEHs plus old `Call Compile` dispatchers; current stable and current B69 use `missionNamespace`/`CODE` dispatch at `Server_HandlePVF.sqf:14-15` and `Client_HandlePVF.sqf:32-33` but still pass only `(_this select 1)` from `Init_PublicVariables.sqf:56,61`. The B69 `0a1ccb4d..8d465fce` checked PVF-path delta changes only `Client/PVFunctions/HandleSpecial.sqf` in both maintained roots, adding default-off `aicom-team-merge` at `:57` with `WFBE_C_AICOM_HC_MERGE_ENABLE` gate at `:59`; it does not change server sender authentication.
- Result: refreshed Feature Status, Server Authority, PVF dispatch, Networking, Public Variable Channel Index, Source Fix queue, dashboard, pruning ledger and machine rows so `0a1ccb4d` is provenance and `8d465fce` is the current B69 branch head. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T18:06:36+02:00 - Codex - HQ score current B69 head refresh

- Claimed `hq-score-current-b69-head-refresh-2026-06-22` after DR-50/HQ-kill score rows were current-stable focused and did not yet name current B69 `origin/claude/b69@8d465fce`.
- Source scope: docs/source `HEAD@97e4cdd04e15`, current stable `origin/master@0139a3468609`, current B69 `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`, current Miksuu `b8389e7482438edd00f420c5bb795ac0a642971f`, `origin/perf/quick-wins@0076040f8a5e` and historical `a96fdda28087`.
- Findings: all checked maintained-root refs still keep `_points = 30000 / 100 * WFBE_C_BUILDINGS_SCORE_COEF` at `Server_OnHQKilled.sqf:23`, award generic HQ building score before the teamkill guard, then award `_score = 900` again for non-teamkills. Current stable awards at `:52/:54` and `:86`; current B69 line drift is `:64/:66`, non-teamkill guard `:106`, `_score = 900` at `:109` and second award `:112`; B69 base-fall smoke/sting code at `:57/:103` is spectacle/notification work, not a scoring fix.
- Result: refreshed [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas#hq-kill-score-and-bounty-branch-matrix), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so DR-50 is current-stable/B69-unpatched with current B69 line refs. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T18:25:27+02:00 - Codex - Upgrade-sync current B69 head refresh

- Claimed `upgrade-sync-current-b69-head-refresh-2026-06-22` after RequestSpecial `upgrade-sync` rows were current-stable focused and did not yet name current B69 `origin/claude/b69@8d465fce`.
- Source scope: docs/source `HEAD@bc21f5207650`, line-anchor checkpoint `ff8dd884`, current stable `origin/master@0139a3468609`, current B69 `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`, prior B69 proof `0a1ccb4d`, current Miksuu `b8389e7482438edd00f420c5bb795ac0a642971f`, `origin/perf/quick-wins@0076040f8a5e`, historical release `a96fdda28087` and historical upgrade-queue `b061c905`.
- Findings: docs/source is unchanged from `ff8dd884` for checked Chernarus/Vanilla `Server_HandleSpecial.sqf`, `GUI_UpgradeMenu.sqf` and `Server_ProcessUpgrade.sqf` paths. Current stable and current B69 both keep `_args = _this` at `Server_HandleSpecial.sqf:3`, the `upgrade-sync` case at `:67`, side from `_args select 1` at `:69`, id/level from `_this select 2/3` at `:70-71`, and sync setVariable at `:73`; both call from `GUI_UpgradeMenu.sqf:292` and use `Server_ProcessUpgrade.sqf:32,35,41` for the sync variable lifecycle. `git diff --name-status 0a1ccb4d..origin/claude/b69` is empty for checked upgrade-sync paths. Miksuu/perf caller line remains `:241`, historical release `:254`, historical upgrade-queue `:268`; no current release/upgrade/special/queue heads were exposed.
- Result: refreshed [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix), [Upgrades and research](Upgrades-And-Research-Atlas#current-branch-scope), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so B69 is current-head evidence, not a rescue. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T18:34:48+02:00 - Codex - Empty supply-truck current B69 head refresh

- Claimed `empty-supply-truck-current-b69-head-refresh-2026-06-22` after empty supply-truck cleanup rows still used B69 `0094647d` and finalpieces `80d3267c` as current branch evidence even though later B69 merges advanced `origin/claude/b69` to `8d465fce`.
- Source scope: docs/source `HEAD@a3bbcd484eb5` is unchanged from `b4e10b5f` for checked Chernarus/Vanilla `emptyvehiclescollector.sqf` and `Server_HandleEmptyVehicle.sqf` paths; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087336880f052ed716ffa3d46e53f24`.
- Findings: docs/source, current stable, current B69, Miksuu, perf and historical `a96fdda2` all drain `WF_Logic` `emptyVehicles` through `emptyvehiclescollector.sqf:9,12,15-17,19` in both maintained roots and set supply-truck `_delay = 86400`. Docs/Miksuu/perf/historical line shape is `Server_HandleEmptyVehicle.sqf:21-23,29-30,33`; stable/B69 line drift is `:29-31,37-38,41` after the nil/null guard. B69 checked path deltas `0094647d..origin/claude/b69` and `80d3267c..origin/claude/b69` are empty, and current origin exposes no `release/*`, cleanup or supply rescue heads.
- Result: refreshed [Marker cleanup/restoration](Marker-Cleanup-Restoration-Systems-Atlas#empty-supply-truck-branch-matrix), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `8d465fce` is current B69 proof while `0094647d` and `80d3267c` remain provenance. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T18:53:11+02:00 - Codex - Service/EASA affordability current B69 head refresh

- Claimed `service-affordability-current-b69-head-refresh-2026-06-22` after service/EASA rows still used B69 finalpieces `80d3267c` as current branch evidence even though later B69 merges advanced `origin/claude/b69` to `8d465fce`.
- Source scope: docs/source `HEAD@8906ee89690c` is unchanged from `9b3fc38e` and `8b71e2a1` for checked Chernarus/Vanilla `GUI_Menu_Service.sqf` and `GUI_Menu_EASA.sqf` paths; current B69 is `origin/claude/b69@8d465fcede7f`; current stable is `origin/master@0139a3468609`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087`; historical EASA QoL evidence is `a66d4691`.
- Findings: `git diff --name-status 80d3267c..origin/claude/b69` and `0094647d..origin/claude/b69` are empty for checked service/EASA paths. Current B69 service menu behavior matches current stable in both maintained roots: rearm/refuel guard `_funds >= _price` at `GUI_Menu_Service.sqf:484` and `:507`, while repair/heal still debit on positive price at `:496-497` and `:519-520`. Current B69 Chernarus keeps exact-funds EASA `_funds >= price` at `GUI_Menu_EASA.sqf:118`, but maintained Vanilla remains strict `_funds > price` at `:118`.
- Result: refreshed [Service menu affordability guards](Service-Menu-Affordability-Guards), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `80d3267c` is provenance and `8d465fce` is current B69 head evidence. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T19:09:20+02:00 - Codex - MASH marker current B69 head refresh

- Claimed `mash-marker-current-b69-head-refresh-2026-06-22` after MASH marker/deploy rows still used B69-family refs `0a1ccb4d` and `80d3267c` as current-facing B69 proof.
- Source scope: docs/source `HEAD@2b5139219faa` is unchanged from `db3015f18ea3` for checked maintained-root MASH deploy, marker relay, init and respawn-availability paths; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087`.
- Findings: docs/source, Miksuu and perf keep the old local MASH deploy plus orphaned marker relay shape in both maintained roots. Current stable, historical `a96fdda2` and current B69 expose only `Skill_Apply.sqf:43` MASH-deploy-removed wording in checked maintained roots and no maintained-root `Client/Module/MASH`, `Server/Module/MASH` or `Skill_Officer.sqf` paths. The B69 diffs `0a1ccb4d..8d465fce` and `80d3267c..8d465fce` touch `Init_Client.sqf` in both maintained roots but contain no MASH-related hunks.
- Result: refreshed [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Public variable channel index](Public-Variable-Channel-Index), Feature Status, Dead/stale code, dashboard, pruning ledger and machine rows so current B69 is `8d465fce` while `0a1ccb4d` and `80d3267c` remain provenance. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T19:26:12+02:00 - Codex - SEND_MESSAGE direct compile current B69 head refresh

- Claimed `send-message-direct-compile-current-b69-head-refresh-2026-06-22` after the direct `SEND_MESSAGE` compile rows still lacked current B69 `origin/claude/b69@8d465fce` evidence.
- Source scope: docs/source `HEAD@40c477be7e0a` is unchanged from `16247fc8fb5f` for checked Chernarus/Vanilla `SEND_MESSAGE` paths; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087`.
- Findings: every checked maintained root still registers direct `SEND_MESSAGE` at `Client/FSM/updateclient.sqf:12`, compiles receiver-side multi-language message text at `Client_onEventHandler_SEND_MESSAGE.sqf:27`, and repeats helper-side `call compile` before `missionNamespace setVariable` / `publicVariable` at `Common_SendMessage.sqf:26,37-38`. B69 checked path deltas `0a1ccb4d..origin/claude/b69` and `b8530477..origin/claude/b69` are empty, so B69 does not rescue this direct channel.
- Result: refreshed [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix), [Networking and public variables](Networking-And-Public-Variables), [Hardening implementation roadmap](Hardening-Implementation-Roadmap), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `8d465fce` is current B69 evidence while old `16247fc8f`, `0a1ccb4d` and `b8530477` remain provenance. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T19:42:26+02:00 - Codex - Commander reassignment current B69 head refresh

- Claimed `commander-reassignment-current-b69-head-refresh-2026-06-22` after commander reassignment rows named current stable helper-unpacking proof but did not yet name current B69 `origin/claude/b69@8d465fce` or current docs/source `HEAD@337ed166`.
- Source scope: docs/source `HEAD@337ed16633e7` is unchanged from `b44aaaf8` for checked Chernarus/Vanilla `GUI_Commander_VoteMenu.sqf`, `RequestNewCommander.sqf`, `Server_AssignNewCommander.sqf`, vote worker and preview paths; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087`; historical AI-commander evidence is `c20ce153`.
- Findings: current stable/current B69 Chernarus and maintained Vanilla fix the DR-15 helper unpacking at `Server_AssignNewCommander.sqf:4-5`, while docs/source still uses `_side = _this` at `:3` in both maintained roots. B69 reassignment path deltas `0a1ccb4d..origin/claude/b69` and `b8530477..origin/claude/b69` are empty. B69 also matches current stable for the checked vote worker/preview paths: `Server_VoteForCommander.sqf:43` uses `_highest >= _aiVotes`, while `GUI_VoteMenu.sqf:88` still previews AI/no commander on row 0 or no strict majority.
- Remaining risks: `RequestNewCommander.sqf:14` and helper `:10` both send `new-commander-assigned`, `GUI_Commander_VoteMenu.sqf:33` still resolves by visible leader name despite row values at `:9,:13,:63`, requester authority is separate, and current stable/B69 full modded Napf/Eden/Lingor forks still use `_side = _this` at `Modded_Missions/*/Server/Functions/Server_AssignNewCommander.sqf:3`.
- Result: refreshed [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows so `8d465fce` is current B69 proof while old B69 and docs-source refs remain provenance. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T20:13:50+02:00 - Codex - Attack-wave authority current B69 head refresh

- Claimed `attack-wave-authority-current-b69-head-refresh-2026-06-22` after the attack-wave direct-PV authority rows still had 2026-06-13/current-stable-focused proof and lacked current B69 `origin/claude/b69@8d465fce` evidence.
- Source scope: docs/source `HEAD@1c1ea55970dc` is unchanged from `f3e157f2` for checked Chernarus/Vanilla `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `AttackWave.sqf`, `updateclient.sqf`, buy-menu price paths and constants. Current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7fc20a7fcb97bd7d02e5211de8d1bf`; current Miksuu is `b8389e7482438edd00f420c5bb795ac0a642971f`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical refs are `a96fdda2`, `c20ce153` and `994150da`.
- Findings: docs/source keeps the action gate at `updateclient.sqf:240`, request send at `Common_AttackWaveActivate.sqf:6,8`, payload trust and detail publish at `Server_AttackWave.sqf:5-6,15,23,27,36,38`, detail trust/debit at `AttackWave.sqf:19,23-25,40`, and constants at `Init_CommonConstants.sqf:166,197-199`. Current stable and current B69 keep the same request/detail trust in both maintained roots; B69 constants drift is unrelated, and B69 checked path deltas `0a1ccb4d..8d465fce` / `b8530477..8d465fce` are empty for attack-wave request/detail/client-price paths. A late fetch exposed adjacent B74 `origin/claude/b74-aicom-spend@b23f557fc912`; its B69 delta touches only Chernarus `Common/Init/Init_CommonConstants.sqf` among checked attack-wave paths, with constants at `:528,572-574`, and maintained Vanilla constants remain `:349,393-395`. Current origin exposes no `release/*`, `feat/ai-commander` or attack-wave feature heads.
- Result: refreshed [Attack-wave authority](Attack-Wave-Authority-Playbook), Feature Status, Source Fix queue, Public Variable Channel Index, Server Authority Migration Map, dashboard, pruning ledger and machine rows so current B69 is named as unpatched evidence, not a rescue. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T20:35:04+02:00 - Codex - Salvage W10 branch-status refresh

- Claimed `salvage-w10-branch-status-refresh-2026-06-22` after a fresh fetch exposed live `origin/claude/salvage-w10-manfilter@2e0242b3`, while the current salvage row still said there were no current salvage heads.
- Source scope: docs/source `HEAD@98eb960775df` is unchanged from `fb8d4ebc` for checked Chernarus/Vanilla manual/truck salvage files; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7f`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557fc912`; current Miksuu is `b8389e748243`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda2`.
- Findings: docs/source, current stable, current B69, adjacent B74, current Miksuu, perf and historical `a96fdda2` still keep lowercase `ChangePlayerfunds`, the `updatesalvage.sqf:10` OR-loop and client-local delete/reward in both maintained roots. Current B69/B74 line drift is `updatesalvage.sqf:51`, `Init_Client.sqf:97,135`, Chernarus `Client_BuildUnit.sqf:388` and maintained Vanilla `Client_BuildUnit.sqf:343`. `git diff --name-status origin/claude/b69..origin/claude/b74-aicom-spend` is empty for checked manual/truck salvage and W10 wildcard paths.
- Branch note: `origin/claude/salvage-w10-manfilter@2e0242b3` has merge-base `8fac20df` with current stable/B69 and is branch evidence, not direct current-stable propagation. The commit changes only `Server/Functions/AI_Commander_Wildcard.sqf` in both maintained roots, adding `!(_wk isKindOf "Man")` to the inert W10 lucky-salvage apply filter at `:794`; the same branch still keeps the manual/truck payout mismatch and client-local authority shape.
- Result: refreshed [Construction and CoIn salvage](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix), Feature Status, Source Fix queue, [AI commander treasury accessors](AI-Commander-Treasury-Fund-Accessors), dashboard, pruning ledger and machine rows so future readers separate the W10 corpse-filter branch from the still-open manual/truck payout/authority lane. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T20:53:27+02:00 - Codex - Vote/help/router current B69 head refresh

- Claimed `vote-help-router-current-b69-head-refresh-2026-06-22` after the Client UI vote/help/main-menu matrix still used older docs/stable anchors and did not name current B69 `origin/claude/b69@8d465fce` or adjacent B74 `origin/claude/b74-aicom-spend@b23f557f`.
- Source scope: docs/source `HEAD@087152f5` is unchanged from `68bd4dc5` for checked Chernarus/Vanilla vote/help/router paths; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7f`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557fc912`; current Miksuu is `b8389e748243`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda2`.
- Findings: all checked maintained-root refs still keep inclusive `WFBE_Client_Teams_Count` vote loops (`GUI_VoteMenu.sqf:29,49,61`; `GUI_Commander_VoteMenu.sqf:58`), the row-color write to `[_i+1,0]` at `GUI_VoteMenu.sqf:80,82`, the `dialog_HelpPanel` / `cti_dialog_ui_onlinehelpmenu` help lifecycle mismatch, and handler-only GPS zoom `MenuAction` `17/18` routes. Stable/B69/B74 move visible action `19` to GPS enablement at `Rsc/Dialogs.hpp:1244,1252` and `GUI_Menu.sqf:241`; B69/B74 additionally refresh `WFBE_Client_Teams_Count` from reconciled teams at `Init_Client.sqf:534`, but still store a count, not a max index.
- Branch note: `git diff --name-status origin/claude/b69..origin/claude/b74-aicom-spend` is empty for checked vote/help/router UI paths. Fresh branch scan exposes UI theme heads `origin/feat/wf-menu-ops-console` and `origin/feat/wf-menu-ux-phase1`, but no current `release/*` or vote/help rescue head.
- Result: refreshed [Client UI vote/help/main-menu matrix](Client-UI-Systems-Atlas#vote-help-and-main-menu-branch-matrix), Feature Status, Source Fix queue, dashboard, pruning ledger and machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T21:19:13+02:00 - Codex - Commander ARTY current B69 marker refresh

- Claimed `commander-arty-current-b69-marker-refresh-2026-06-22` after commander-built ARTY rows still mixed older docs/stable/release anchors and could make current stable look missing despite the marker path.
- Source scope: docs/source `HEAD@f5bcaf91` is unchanged from `4bd37b98` for checked Chernarus/Vanilla commander ARTY construction/discovery paths; current stable is `origin/master@0139a346`; current B69 is `origin/claude/b69@8d465fce`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557f`; current Miksuu is `b8389e748243`; perf is `origin/perf/quick-wins@0076040f`; historical release evidence is `a96fdda2` / `7ff18c49`.
- Findings: docs/source keeps the commander-team gunner handoff at `Construction_StationaryDefense.sqf:91-94` and group-player Tactical discovery at `Common_GetTeamArtillery.sqf:10-30`. Current stable/B69/B74 keep marker-based commander ARTY discovery at `Construction_StationaryDefense.sqf:166-168` plus `Common_GetTeamArtillery.sqf:46,56`; B69/B74 line drift moves `RequestFireMission` to `GUI_Menu_Tactical.sqf:559`. Historical release evidence keeps the marker variables at `Construction_StationaryDefense.sqf:133-135`. Miksuu/perf expose Tactical fire mission calls but no checked handoff or marker rescue.
- Result: refreshed [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas#current-branch-scope), Feature Status, Source Fix queue, Testing workflow, Current Source Status Snapshot and machine rows so docs/source, current stable/B69/B74 and historical release evidence are separate implementation shapes. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.
## 2026-06-22T21:43:41+02:00 - Codex - Paratrooper marker current B69/B74 refresh

- Claimed `paratrooper-marker-current-b69-b74-refresh-2026-06-22` after the paratrooper marker page contradicted itself about current master and still treated `7ff18c49` as a live release head.
- Source scope: docs/source `HEAD@7e88d609` registers `HandleParatrooperMarkerCreation` at `Common/Init/Init_PublicVariables.sqf:39` in both maintained roots, sends it from `Support_Paratroopers.sqf:117` and records `paratrooper_marker_spawn` in `HandleParatrooperMarkerCreation.sqf:45`. Current stable is `origin/master@0139a346`; current B69 is `origin/claude/b69@8d465fce`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557f`; current Miksuu is `b8389e748243`; perf is `origin/perf/quick-wins@0076040f`; historical release-line evidence is `a96fdda2` / `7ff18c49`.
- Findings: current stable/B69/B74 register the handler at `Init_PublicVariables.sqf:38` in both maintained roots, and checked diffs across `origin/master..origin/claude/b69` and `origin/claude/b69..origin/claude/b74-aicom-spend` are empty for the paratrooper sender/handler/registration paths. Historical `a96fdda2`/`7ff18c49` registers at `:34` but current origin exposes no live `release/*` head. Current Miksuu keeps sender/handler files but no checked maintained-root registration hit; perf registers Chernarus only at `:40`.
- Result: refreshed [Paratrooper marker revival](Paratrooper-Marker-Revival), Feature Status, Source Fix queue, Current Source Status Snapshot, Testing workflow, dashboard, pruning ledger and machine rows so docs/source, current stable/B69/B74, historical release-line, Miksuu and perf states are separate. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T22:10:00+02:00 - Codex - Client Skill_Init current B69/B74/client-fps refresh

- Claimed `client-skill-init-current-b69-b74-refresh-2026-06-22` after client skill-init rows still mixed older stable `cf2a6d6a` and "current release" wording.
- Source scope: docs/source `HEAD@b2738971` keeps one `Skill_Init.sqf` call at `Client/Init/Init_Client.sqf:547` and apply at `:571` in Chernarus and maintained Vanilla. Current stable is `origin/master@0139a346`; current B69 is `origin/claude/b69@8d465fce`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557f`; live client-fps is `origin/feat/client-fps@709258e7`; current Miksuu is `b8389e748243`; perf is `origin/perf/quick-wins@0076040f`; historical release-line evidence is `a96fdda2` / `7ff18c49`; historical feat-ai evidence is `c20ce153`.
- Findings: current stable carries one-call/apply at `Init_Client.sqf:624,647`; B69/B74 carry `:805,828`; live client-fps keeps one-call/apply with Chernarus `:613,636` and Vanilla `:583,606`. Historical release-line commits carry the shape, but current origin exposes no live `release/*` head. Current Miksuu, perf and historical feat-ai still duplicate `Skill_Init` before apply in both maintained roots.
- Result: refreshed [Client skill init idempotency](Client-Skill-Init-Idempotency), Feature Status, Source Fix queue, Current Source Status Snapshot, Testing workflow, dashboard, pruning ledger and machine rows so current stable/B69/B74/client-fps, historical release-line and old-shape refs are separate. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T22:11:49+02:00 - Codex - Server Init duplicate binds current B69/B74 refresh

- Claimed `server-init-duplicate-binds-current-b69-b74-refresh-2026-06-22` after the server-init owner page and Feature Status still used old docs/stable/release anchors (`a0a86da2`, `cf2a6d6a`, live `release/*` wording).
- Source scope: docs/source `HEAD@d830379768` and current Miksuu `b8389e748243` keep duplicate live `LogGameEnd`, `PlayerObjectsList` and `AwardScorePlayer` binds at `Init_Server.sqf:64,89`, `:69,91` and `:83,93` in Chernarus and maintained Vanilla. Current stable is `origin/master@0139a346`; current B69 is `origin/claude/b69@8d465fce`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557f`; perf is `origin/perf/quick-wins@0076040f`; historical release-line evidence is `a96fdda2`.
- Findings: current stable has one live bind per checked function at `Init_Server.sqf:81,86,99` in both maintained roots. Current B69/B74 have one live bind at `:83,88,101`, and the B69-to-B74 checked init diff is empty. Perf fixes Chernarus at `:64,:69,:83` with an explanatory comment around `:88`, but maintained Vanilla remains old-shape. Historical `a96fdda2` has one-live-bind evidence at `:65,:70,:83`, but current origin exposes no live `release/*` head.
- Result: refreshed [Server init bind cleanup](Server-Init-Bind-Cleanup), Feature Status, Hardening roadmap, dashboard, pruning ledger and machine rows so docs/source/Miksuu/perf-Vanilla old-shape targets are separate from current stable/B69/B74 one-live-bind targets. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T22:31:00+02:00 - Codex - Objective Ping current B69/B74 refresh

- Claimed `objective-ping-current-b69-b74-refresh-2026-06-22` after commander task rows still mixed older stable/release wording and could imply current stable was old-shape.
- Source scope: docs/source `HEAD@86ab85b9d0b1`; current stable `origin/master@0139a3468609`; current B69 `origin/claude/b69@8d465fcede7f`; adjacent B74 `origin/claude/b74-aicom-spend@b23f557fc912`; live objective-named `origin/feat/naval-hvt-objectives@2e1c59317186`; current Miksuu `b8389e748243`; perf `origin/perf/quick-wins@0076040f8a5e`; historical `a96fdda28087`; historical feat-ai `c20ce1534be0`.
- Findings: docs/source, Miksuu, perf and historical feat-ai build commander task data but keep `SetTask` sends commented at `GUI_Menu_Command.sqf:335,337,343` while registering `SetTask` at `Common/Init/Init_PublicVariables.sqf:33`. Current stable, B69, B74 and naval-HVT send targeted Objective Ping at `GUI_Menu_Command.sqf:336,344` and register `SetTask` at `Init_PublicVariables.sqf:40` in both maintained roots. Historical `a96fdda2` has live sends and `:36` registration, but current origin exposes no live `release/*` head.
- Branch note: `origin/feat/naval-hvt-objectives` matches current stable for the checked command-menu, `SetTask` helper and registration paths; it is objective-named but not a separate commander-task rescue. Old town `TaskSystem` remains separate commented/residue and is not revived by Objective Ping.
- Result: refreshed Feature Status, Client UI systems, Commander/HQ lifecycle, Networking and public variables, Player UI workflow, PVF send-helper contract, Abandoned feature revival and the commander task machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T22:46:01+02:00 - Codex - Resource income current stable/B69/B74 refresh

- Claimed `resource-income-current-b69-b74-refresh-2026-06-22` after resource-income rows still lacked current B69/B74 proof and kept older docs-branch/current-head anchors.
- Source scope: docs/source `HEAD@c8ec223ab2ba`; current stable `origin/master@0139a3468609`; current B69 `origin/claude/b69@8d465fcede7f`; adjacent B74 `origin/claude/b74-aicom-spend@b23f557fc912`; current Miksuu `b8389e748243`; perf `origin/perf/quick-wins@0076040f8a5e`; historical release `a96fdda28087`.
- Findings: docs/source, Miksuu, perf and historical `a96fdda2` keep the old `updateresources.sqf:31` cap guard over side supply (`:49`), team paychecks (`:63`) and AI commander funds (`:67`), with system-4 server multiplier at `:42-43` while `Client_GetIncome.sqf:24-28` omits the display multiplier. Current stable keeps side supply/team paychecks gated at `:45,:63,:77` but has AI commander over-cap income/stipend fallback outside the gate at `:102-109`; system-4 multiplier is `:56-57`.
- Branch note: B69 and B74 are identical for checked resource-income files. Both gate side supply/team paychecks at `updateresources.sqf:58,:76,:90` and add fallback at `:115-121`; Chernarus also uses `WFBE_C_AI_COMMANDER_HYBRID_REFILL` in commander-cash checks (`:94-103,:115`) plus `WFBE_C_ECONOMY_SUPPLY_INCOME_MULT` on side supply at `:76`, while maintained Vanilla keeps raw `_supply` and non-hybrid checks. System-4 multiplier is `:69-70`; client display still omits it.
- Result: refreshed Economy-Towns-And-Supply, Economy-Authority-First-Cut, Feature Status, Source Fix queue, Resource-Income-Tick-Distribution-Engine, dashboard, pruning ledger and resource-income machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T23:01:10+02:00 - Codex - WASP marker wait current B74/client-fps refresh

- Claimed `wasp-marker-wait-current-b74-clientfps-refresh-2026-06-22` after the WASP marker route still named only current stable/B69 as source-present throttled and did not include adjacent B74 or the live client-fps branch.
- Source scope: docs/source `HEAD@46840f048bd4`; current stable `origin/master@0139a3468609`; current B69 `origin/claude/b69@8d465fcede7f`; adjacent B74 `origin/claude/b74-aicom-spend@b23f557fc912`; live client-fps `origin/feat/client-fps@709258e7e6f8`; current Miksuu `b8389e748243`; perf `origin/perf/quick-wins@0076040f8a5e`; historical release-line evidence `a96fdda28087`.
- Findings: docs/source still launches `WASP\global_marking_monitor.sqf` from `Init_Client.sqf:267` in both maintained roots and keeps the unslept display-54 wait at `global_marking_monitor.sqf:57,62,64,68-69,80`. Current stable launches at `Init_Client.sqf:309`; B69/B74 launch at `:397`; client-fps launches at Chernarus `:308` and maintained Vanilla `:287`. Stable/B69/B74/client-fps all carry `sleep 0.1` at `global_marking_monitor.sqf:64` plus the display-12 wait at `:81` in both maintained roots.
- Branch note: current Miksuu and perf remain old-shape in both maintained roots, and the remote branch scan exposed no live `release/*` head. Older release evidence is historical until a release ref is restored or rechecked.
- Result: refreshed WASP marker wait cleanup, performance sweep, WASP overlay, current source snapshot, Feature Status cross-link, Source Fix queue, dashboard, pruning ledger and WASP marker machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.

## 2026-06-22T23:22:00+02:00 - Codex - PVF dispatcher current B74 refresh

- Claimed `pvf-dispatch-current-b74-refresh-2026-06-22` after PVF dispatcher and sender-auth rows named current stable/B69 but did not include adjacent B74 `origin/claude/b74-aicom-spend@b23f557f`.
- Source scope: docs/source `HEAD@a0721301d4f5` remains old-shape for checked Chernarus/Vanilla PVF init/dispatcher paths; current stable is `origin/master@0139a3468609`; current B69 is `origin/claude/b69@8d465fcede7f`; adjacent B74 is `origin/claude/b74-aicom-spend@b23f557fc912`; current Miksuu is `b8389e748243`; perf is `origin/perf/quick-wins@0076040f8a5e`; historical release evidence is `a96fdda28087`.
- Findings: current stable/B69/B74 use `missionNamespace getVariable _script` plus `typeName == "CODE"` guards at `Server_HandlePVF.sqf:14-15` and `Client_HandlePVF.sqf:32-33` in both maintained roots. They still forward only value tuples at `Init_PublicVariables.sqf:56,61`, and no `WFBE_CL_PVF_ALLOWED`, `WFBE_SE_PVF_ALLOWED`, `PVF_ALLOWED`, allowlist or rejected-unregistered warning symbol was found in checked dispatcher/init files. The checked B69..B74 generic PVF dispatcher/init delta is empty.
- Branch note: docs/source, current Miksuu, perf and historical `a96fdda2` still use dispatch-time `Call Compile` in both maintained roots. Current origin exposes no live `release/*`, PVF, network, auth or public feature head. DR-55 authenticated requester context and direct publicVariable channels remain separate from dispatcher lookup/allowlist work.
- Result: refreshed PVF dispatch implementation, Networking and public variables, Public variable channel index, Server authority migration map, Hardening roadmap, Feature Status, Source Fix queue, dashboard, pruning ledger and PVF machine rows. No gameplay source changed.
- Validation: final validation is recorded in the matching `complete` event.
