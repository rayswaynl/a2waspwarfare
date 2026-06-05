# Dead Code And Stale Code Register

This page is the cleanup map for code that appears dead, stale, unreachable, orphaned, or misleading in `rayswaynl/a2waspwarfare`.

It is not a delete list. It separates safe comment cleanup from risky broken features and revive candidates so future agents do not accidentally remove useful archaeology or branch-ready systems.

Machine-readable findings live in `docs/analysis/dead-code-findings.jsonl`. The repeatable source scan lives in `docs/analysis/dead-code-reference-scan.ps1`, with the latest raw scan output in `docs/analysis/dead-code-reference-scan.json`.

Integration/tooling evidence is captured by `docs/analysis/dead-code-integration-scan.ps1`, with the latest output in `docs/analysis/dead-code-integration-scan.json`.

Direct public-variable channel evidence is captured by `docs/analysis/dead-code-pv-channel-scan.ps1`, with the latest output in `docs/analysis/dead-code-pv-channel-scan.json`.

UI/Rsc/dialog evidence is captured by `docs/analysis/dead-code-ui-rsc-scan.ps1`, with the latest output in `docs/analysis/dead-code-ui-rsc-scan.json`.

Mission parameter/config evidence is captured by `docs/analysis/dead-code-parameter-scan.ps1`, with the latest output in `docs/analysis/dead-code-parameter-scan.json`.

SQF reachability evidence is captured by `docs/analysis/dead-code-sqf-reachability-scan.ps1`, with the latest output in `docs/analysis/dead-code-sqf-reachability-scan.json`.

## Scan Snapshot

Latest local scan:

| Item | Value |
| --- | --- |
| Roots scanned | `Missions`, `Missions_Vanilla`, `Modded_Missions` |
| Text files scanned | 2765 |
| Quoted source references found | 3546 |
| Missing quoted references reported | 658 |
| Real conflict-marker files found | 18 |
| Generated artifacts | `docs/analysis/dead-code-reference-scan.json`, `docs/analysis/dead-code-findings.jsonl` |

Latest integration/tooling scan:

| Item | Value |
| --- | --- |
| Tracked integration build artifacts | 0 tracked `bin`/`obj`/binary build outputs found under `Tools`, `DiscordBot`, `Extension`, `BattlEyeFilter` |
| Ignored build output dirs present locally | `Tools\LoadoutManager\bin`, `Tools\LoadoutManager\obj`, `DiscordBot\bin`, `DiscordBot\obj`, `Extension\obj` |
| Tracked BattlEye files | `BattlEyeFilter/READ ME FIRST - Using BattlEye filter to auto kick.docx`, `BattlEyeFilter/publicvariable.txt` |
| Repo server/filter config footprint | `BattlEyeFilter/publicvariable.txt` only |
| Serializer hits | DiscordBot active `TypeNameHandling.All`, DiscordBot dormant `.Auto` helper, Extension active `.None`, Extension commented `.Auto` scaffold |
| Tooling drift hits | Commented modded generation call, modded packaging omission, DiscordBot/LoadoutManager terrain metadata drift |

Latest direct public-variable channel scan:

| Item | Value |
| --- | --- |
| Roots scanned | `Missions`, `Missions_Vanilla`, `Modded_Missions` |
| Text files scanned | 2761 |
| Direct PV sender/receiver records | 229 total, 190 active, 39 comment-only |
| Active direct channels | 36 |
| Active sender-only channels | 13, many are state broadcasts or external-filter channels |
| Active receiver-only channels | 3 before source interpretation: `ICBM_launched`, `wfbe_supply_temp_east`, `wfbe_supply_temp_west` |
| Comment-only channels | 6 legacy direct `WFBE_*` names |
| Generated artifact | `docs/analysis/dead-code-pv-channel-scan.json` |

Latest UI/Rsc/dialog scan:

| Item | Value |
| --- | --- |
| Roots scanned | `Missions`, `Missions_Vanilla`, `Modded_Missions` |
| Text files scanned | 2761 |
| UI/reference records | 7447 total, 7364 active, 83 comment-only |
| Dialog classes / literal calls | 10 `RscMenu_*` classes, 17 literal `createDialog` calls |
| Handler script references | 20 active `onLoad` / `onUnload` script references |
| Missing handler scripts | 1: `Client\GUI\GUI_Menu_Upgrade.sqf` |
| Dialog classes without literal calls | 1: `RscMenu_Upgrade` |
| Active IDC uses without mission declarations | 10 scan leads; 3 are mission economy menu IDCs and 7 are engine/BIS/map display IDs |
| Duplicate IDDs | 2 active collision groups: `23000`, `10200` |
| Generated artifact | `docs/analysis/dead-code-ui-rsc-scan.json` |

Latest mission parameter/config scan:

| Item | Value |
| --- | --- |
| Roots scanned | `Missions`, `Missions_Vanilla`, `Modded_Missions` |
| Text files scanned | 2763 |
| Active parameter classes | 89 |
| Parameter/reference records | 3299 total, 3225 active, 74 comment-only |
| Active parameters with no runtime references | 5 scan leads: `WFBE_C_AI_MAX`, `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, `WFBE_C_MODULE_BIS_HC`, `WFBE_C_MODULE_WFBE_IRS`, `WFBE_C_UNITS_CLEAN_TIMEOUT` |
| Active parameters with no runtime read-like references | 9 scan leads; dynamic `format` reads make the four economy-start rows false positives |
| Active parameters with runtime set-like overrides | 12 |
| Generated artifact | `docs/analysis/dead-code-parameter-scan.json` |

Latest SQF reachability scan:

| Item | Value |
| --- | --- |
| Roots scanned | `Missions`, `Missions_Vanilla`, `Modded_Missions` |
| Text files scanned | 2767 |
| SQF files catalogued | 2705 |
| Quoted SQF path references | 4358 total, 4121 active, 237 comment-only |
| Active quoted SQF references resolved | 3476 |
| Raw unreferenced SQF leads | 453 |
| Biggest raw lead buckets | 170 function-library files, 164 config-data files, 46 module scripts, 23 server scripts |
| Generated artifact | `docs/analysis/dead-code-sqf-reachability-scan.json` |

Scanner caveats:

- The scanner intentionally finds leads, not final truth.
- `ca\...` references are Arma/OA addon paths, not repo-local missing files.
- `version.sqf` is a generated workflow dependency, not dead code.
- Commented-out references are usually cleanup/documentation candidates, not runtime failures.
- Includes inside subfolders can be relative to the including file, while the first scanner pass resolves quoted paths from the mission root.
- Modded missions are out of the current LoadoutManager release pack path, so modded breakage is real source debt but not necessarily current release breakage.
- A direct PV channel with no `addPublicVariableEventHandler` is not automatically dead. Some channels are state variables read via `missionNamespace getVariable`, some are BattlEye/filter hooks, and some sender names are dynamic `format` expressions that need source interpretation.
- UI IDC scans cannot distinguish engine display controls from mission resource controls by themselves. Treat `101`, `116` and `112410`-`112414` as source-check leads, not broken mission `Rsc` controls.
- Parameter scans cannot prove dynamic formatted variable reads on exact names. The economy start parameters look readless in exact-name scans, but `Server/Init/Init_Server.sqf` and player-connect code read them through `Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side]` and `Format ["WFBE_C_ECONOMY_SUPPLY_START_%1", _side]`.
- SQF reachability scans cannot prove dynamic `addAction`, `missionNamespace getVariable`, `Format` or generated path usage. Treat `Client/Module/Skill/Skill_*.sqf`, `Server/Construction/Construction_*Site.sqf`, config arrays and mission entrypoints as source-check leads, not dead files.
- Baseline and modded source can legitimately differ. Example: source Chernarus/Vanilla IRS warning helpers are unreferenced after inline warning logic was added, while the conflict-marked Napf IRS file still contains old helper calls.

## Classification Rules

| Classification | Meaning | Default action |
| --- | --- | --- |
| `retired-commented-reference` | A disabled/commented call points at a missing or old file. | Remove or rewrite comments only after a final source search. |
| `broken-stale-ui-class` | A visible config/dialog path points at missing code or stale controls. | Source-check callers, then patch or retire. |
| `orphaned-partial-feature` | Some feature wiring exists, but sender/receiver/registration is incomplete. | Do not delete until owner decides retire vs revive. |
| `latent-revive-candidate` | Compiled or implemented but no current caller is proven. | Preserve or explicitly retire after branch review. |
| `broken-modded-source-reference` | Broken in old/generated/modded mission roots. | Fix only when modded maps re-enter release scope. |
| `generated-file-contract-risk` | Looks missing in source but is produced by tooling. | Document and validate workflow, do not delete. |
| `stale-or-malformed-resource-config` | Resource/config code appears malformed or outdated. | Runtime/config smoke before editing. |
| `comment-only-legacy-direct-pv` | Old direct publicVariable channel names survive only in comments after migration to PVF/helper calls. | Remove or annotate comments after branch-aware search. |
| `duplicate-compatibility-channel` | Two channels publish similar state, but one may still serve stale/modded consumers. | Consolidate only after compatibility policy is decided. |
| `receiver-only-legacy-event-handler` | A live event handler waits on a channel with no active sender found in maintained source. | Treat as stale wiring until runtime/branch smoke proves otherwise. |
| `duplicate-misleading-ui-resource-id` | Two distinct reachable dialogs/titles share an IDD value. | Do not delete; assign unique IDs only during a tested UI cleanup. |
| `comment-only-stale-idc-reference` | A missing or old IDC appears only inside comments. | Clean comments or document as retired UI; do not add controls unless reviving the feature. |
| `visible-parameter-no-runtime-consumer` | A lobby/in-game parameter is imported and defaulted, but no current runtime consumer is found. | Hide/remove, wire, or document as historical after owner review. |
| `visible-parameter-comment-only-consumer` | A lobby/in-game parameter has only commented or bypassed runtime consumption. | Decide intended policy before wiring or removing. |
| `comment-only-sqf-entrypoint` | A script exists and is only reached from commented compile/exec/addAction references. | Usually owner decision: remove stale wiring, revive deliberately, or leave as documented archaeology. |
| `baseline-unreferenced-modded-live-split` | A helper is unreachable in maintained source/Vanilla but still appears in stale or modded sources. | Do not delete globally until modded branch policy is chosen. |
| `dynamic-path-false-positive` | A static path scan cannot see runtime path construction or arrays of script paths. | Add guardrails and source-check the dynamic owner before classifying. |
| `tooling-owned-dormant-hook` | Runtime hook is disabled, but an external tool still owns or rewrites the file. | Do not delete until tooling contract is redesigned. |

## Current Findings

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `old-map-blink-loop-missing-files` | Retired commented reference | `Client/Init/Init_Client.sqf:138`, `:140`, `:782` reference missing plural blink/add-track files; `:139` compiles the live singular `Client_BlinkMapIcon.sqf`. | Safe comment cleanup only. Keep the singular blink helper. |
| `server-map-blinking-units-commented-missing` | Retired commented reference | `Server/Init/Init_Server.sqf:593` comments an exec for missing `Server_MapBlinkingUnits.sqf`. | Treat as retired unless marker authority is redesigned. |
| `stale-rscmenu-upgrade-missing-onload` | Broken stale UI class | `Rsc/Dialogs.hpp:2425`, `:2428` keep `RscMenu_Upgrade` with missing `Client/GUI/GUI_Menu_Upgrade.sqf`; the UI/Rsc scan confirms this is the only `RscMenu_*` class without literal `createDialog` calls and the handler target is missing across source, Vanilla and modded copies. | Search branch callers, then remove/alias to the maintained `WFBE_UpgradeMenu` / `GUI_UpgradeMenu.sqf` path. |
| `mash-marker-relay-orphaned` | Orphaned partial feature | Server compiles `MASHMarker.sqf`; client receiver compile is commented at `Client/Init/Init_Client.sqf:132`; sender/receiver PV channels do not form a maintained Chernarus loop. | Decide retire vs revive. MASH tents are not dead. |
| `latent-aibuyunit-server-buy-worker` | Latent revive candidate | `Server/Init/Init_Server.sqf:10` compiles `AIBuyUnit`, but stable source search finds no caller; `Server_BuyUnit.sqf` is an AI/team worker. | Do not delete casually. Needed if AI commander production is revived. |
| `modded-mission-conflict-markers` | Broken modded mission sources | 18 files under `Modded_Missions` contain real `<<<<<<<`, `=======`, `>>>>>>>` markers. | Resolve before any modded release. Do not blindly delete sections. |
| `unitcaching-commented-absent-scaffold` | Retired commented reference | `description.ext:37` comments `scripts\unitCaching\description.ext`; the folder is absent. | Safe comment cleanup or keep as abandoned optimization note. |
| `common-handlebombs-commented-missing` | Retired commented reference | `Common/Init/Init_Common.sqf:11` comments missing `Common_HandleBombs.sqf`. | Safe comment cleanup; live IRS/missile systems are separate. |
| `legacy-config-defenses-commented-missing` | Retired commented reference | Defense files call live `Config_Defenses_Towns.sqf` and retain commented old `Config_Defenses.sqf` calls. | Safe comment cleanup after branch search. |
| `wasp-commented-action-scaffolds` | Retired commented reference, narrow scope | `WASP/Init_Client.sqf:7`, `:12`, `:21` point at missing old action/key scripts; adjacent WASP action helpers still have uses. | Clean only commented missing hooks unless a full WASP action inventory proves more. |
| `bis-hc-parameter-orphan` | Orphan-looking config | `Rsc/Parameters.hpp:381` exposes `WFBE_C_MODULE_BIS_HC`; HC delegation uses `WFBE_C_AI_DELEGATION`. | Hide/remove or wire a real BIS High Command feature; do not label it as headless-client enablement. |
| `ai-max-visible-parameter-no-runtime-consumer` | Visible parameter with no runtime consumer | `Rsc/Parameters.hpp:56-60` exposes `WFBE_C_AI_MAX`; `Init_CommonConstants.sqf:92` defaults it; the parameter scan and fixed-string search find no active runtime consumer. Player follower caps use `WFBE_C_PLAYERS_AI_MAX` instead. | Do not use this for player cap answers. Wire it to real AI-team sizing, hide/remove it, or label it historical. |
| `units-clean-timeout-visible-parameter-comment-only-consumer` | Visible parameter with comment-only consumer | `Rsc/Parameters.hpp:242-246` exposes `WFBE_C_UNITS_CLEAN_TIMEOUT`; constants default it at `Init_CommonConstants.sqf:348`; active trash cleanup reads `WFBE_C_UNITS_BODIES_TIMEOUT` at `Common_TrashObject.sqf:19` and only mentions `WFBE_C_UNITS_CLEAN_TIMEOUT` in a commented old split line at `:20`; empty vehicles use `WFBE_C_UNITS_EMPTY_TIMEOUT` in `Server_HandleEmptyVehicle.sqf:12`. | Decide whether the lobby row should drive body timeout, revive the old man/non-man split, or be removed/renamed. Keep empty vehicle cleanup separate. |
| `economy-menu-missing-control-writes` | Stale UI control writes | `GUI_Menu_Economy.sqf:7-8` writes IDC `23004/23005/23006`; audited `RscMenu_Economy` declares `23002/23003` then `23008+`; the UI/Rsc scan reports all three as active undeclared mission IDC uses across source, Vanilla and modded copies. | Complete menu intent review, then restore intended controls or remove stale writes. |
| `modded-missing-camp-helper-files` | Broken modded source reference | Modded `Init_Common.sqf` files compile `Common_GetTotalCamps*.sqf`; scan reports missing helpers in modded roots. | Restore from current source or regenerate modded missions before release. |
| `generated-version-sqf-clean-checkout-risk` | Generated-file contract risk | Mission entrypoints include `version.sqf`; LoadoutManager generates/excludes it. | Keep includes; validate generation workflow on clean checkout. |
| `rsc-clickabletext-soundpush-malformed` | Stale or malformed resource config | `Rsc/Ressources.hpp:556` has `soundPush[] = {, 0.2, 1};` in source and modded copies. | Replace with valid value only after config/dialog smoke. |
| `modded-packaging-disabled-by-tooling` | Deferred release scope | `Tools/LoadoutManager/ZipManager.cs:16` packages `Missions` and `Missions_Vanilla`; `SqfFileGenerator.cs:133` says add modded maps later. | Keep disabled until conflict/missing-reference checks pass, or archive old modded roots. |

## SQF Reachability Findings

These are source-interpreted findings from the SQF reachability scan. The scan only proves that no literal active quoted path reached a file; every row below was checked against the relevant init, module or dynamic-dispatch owner before being promoted.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `sqf-ai-supply-truck-worker-comment-only` | Comment-only SQF entrypoint with latent breakage | `Server/Init/Init_Server.sqf:36` comments the `UpdateSupplyTruck` compile, while the gated call at `:383` can still spawn it when supply system `0` and AI commanders are enabled; `AI_UpdateSupplyTruck.sqf:17` then tries missing `Server\FSM\supplytruck.fsm`. | Keep documented as config-gated latent breakage. Do not simply uncomment; either guard/remove the gated spawn or redesign AI logistics. |
| `groupsmonitor-commented-debug-loop` | Comment-only SQF entrypoint | `Server/FSM/groupsMonitor.sqf:1-14` logs `allGroups` counts every 30 seconds, but the only source start point found is commented at `Server/Init/Init_Server.sqf:567`. | Safe to leave dormant. If revived, make it an explicit debug parameter/tooling feature to avoid production log spam. |
| `common-modify-airvehicle-tooling-owned-dormant-hook` | Tooling-owned dormant hook | `Common/Functions/Common_CreateVehicle.sqf:22` comments the aircraft post-create call; `Common_ModifyAirVehicle.sqf` still contains `//LoadoutManagerInsertChanges` and generated aircraft rearmor cases. | Do not delete as dead runtime code until LoadoutManager's generated-aircraft contract is redesigned or retired. |
| `common-handle-at-reload-comment-only` | Comment-only SQF entrypoint | `Common/Init/Init_Common.sqf:10` comments `HandleATReloadVehicle`; the existing helper manipulates TOW magazine/reload timing but no active compile/caller is found. | Treat with the existing AT/bomb hook family as archive/revive work. Do not call current ordnance guardrails dependent on it. |
| `irs-warning-helpers-baseline-unreferenced` | Baseline unreferenced / modded-live split | Source Chernarus and Vanilla `IRS_Init.sqf` compile `CreateSmoke`, `DeploySmoke`, `HandleMissile` and `OnIncomingMissile` only; `IRS_ShowWarning.sqf` and `IRS_PlayWarningSound.sqf` have no maintained-source caller. Napf's conflict-marked IRS file still contains old calls to both helpers. | Do not delete globally until modded mission policy is settled. For source/Vanilla, treat the inline `inboundMissileGround` logic in `IRS_OnIncomingMissile.sqf` as the current path. |
| `reaktiv-init-unreachable` | Orphaned module script | `Common/Module/Reaktiv/Reaktiv_Init.sqf:5` compiles the HandleDamage helper, but `Init_Common.sqf:319-323` initializes ICBM, IRS and CIPHER without any Reaktiv init call. | Already routed to module docs as dead/unreachable. Preserve only if an owner wants ERA armor revived and smoke-tested. |
| `client-task-system-comment-only` | Disabled partial UX path | `Client/Init/Init_Client.sqf:75` comments the `TaskSystem` compile and `:744` comments old town-complete task spawning, while `Client_TaskSystem.sqf` and `SetTask` receiver/UI residue still exist. | Owner decision: hide/remove task UI residue or revive with server-backed/JIP-safe task flow. |

Source-checked false positives from this pass:

- `Client/Module/Skill/Skill_Engineer.sqf`, `Skill_Salvage.sqf`, `Skill_Officer.sqf`, `Skill_LR.sqf`, `Skill_Sniper.sqf` and `Skill_SpecOps.sqf` are reached through dynamic `WFBE_SK_V_Root + '<Role>.sqf'` `addAction` paths in `Skill_Apply.sqf`. Do not classify them as dead from static path scans.
- `Server/Construction/Construction_HQSite.sqf`, `Construction_SmallSite.sqf` and `Construction_MediumSite.sqf` are selected through `WFBE_%1STRUCTURESCRIPTS` arrays and `RequestStructure.sqf`; they are live dynamic construction workers, not unreferenced files.
- `AI_AddMultiplayerRespawnEH.sqf` looks unreferenced to the raw scan, but `Init_Server.sqf` uses different AI respawn implementations by `WF_A2_Vanilla`; the non-vanilla advanced respawn path is already documented as a live branch.
- `Action_ToggleMHQLock.sqf` looks unreferenced as a quoted path in some roots, but it is part of the live MHQ lock action/PVF authority surface and is already cited by the server authority map. Treat scanner output here as an addAction/dynamic-UI limitation.

## Integration And Tooling Findings

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `discordbot-fileconfiguration-dormant-status-path` | Stale but referenced helper | `FileConfiguration.cs:9-55` can read `botconfig.json`, but `GameData.LoadFromFile()` uses `Preferences.Instance.DataSourcePath` directly at `GameData.cs:36`; only `FileConfiguration.LogsPath` is used by live logging. | Choose one data-path source. Wire the status reader through `FileConfiguration.DataSourcePath` or delete/demote the `botconfig.json` data-path helper while preserving logging. |
| `discordbot-json-helper-dormant-unsafe` | Latent dangerous helper | Startup/timer/command paths call `GameData.LoadFromFile()` (`ProgramRuntime.cs:15`, `GameStatusUpdater.cs:84`, `CommandHandler.cs:211`), while public `HandleGameDataCreationOrLoading()` remains and uses `TypeNameHandling.Auto` at `GameDataDeSerialization.cs:32`. | Delete/private it or force `TypeNameHandling.None`; fixture-test hostile `$type` JSON if kept. |
| `extension-commented-deserialize-scaffold` | Disabled dangerous scaffold | Active extension writer uses `TypeNameHandling.None`, but commented `DeSerializeDB` / `HandleDatabaseCreationOrLoading` block uses `.Auto` and old persistence names (`SerializationManager.cs:79-124`). | Delete the commented scaffold or replace with safe DTO-only loader before any persistence revival. |
| `extension-and-discordbot-gamedata-arg-shape-drift` | Misleading stale initializer/comments | `GlobalGameStats.sqf:22` sends five data fields after class selector; `GLOBALGAMESTATS.cs:5-11` still marks uptime/player count as TODO; Extension default array is length 2; DiscordBot default array is length 4 while player count checks index 4. | Define `database.json` once and align default arrays/comments plus short/normal/long fixture tests. |
| `discordbot-shared-loadoutmanager-write-api-stale` | Duplicated stale helper API | DiscordBot terrain `BaseTerrain.WriteToFile()` writes mission files, but static search found no bot caller; runtime only resolves terrain metadata for display (`GameData.cs:147-156`). | Split display metadata from generator APIs or clearly mark copied/shared historical code. |
| `discordbot-tasmania-metadata-stale` | Stale map metadata | DiscordBot has `TASMANIA2010`; current LoadoutManager `TerrainName` does not; upstream history records Tasmania removal after generated-map/version failures. | Confirm production cannot emit `TASMANIA2010`, then remove/archive DiscordBot metadata or keep it as legacy display-only fallback. |
| `battleye-afk-only-filter-footprint` | Misleading deployment-hardening footprint | Tracked BattlEye files are the README docx and `publicvariable.txt`; the filter contains only `5 "kickAFK"` and matches the AFK FSM broadcast. | Keep as AFK feature plumbing; do not claim broad public-server hardening without production `BEpath` evidence. |
| `loadoutmanager-dangerous-crv7pg-warning-used` | Misleading dangerous data, not dead | `WARNING_GAME_CRASH_DO_NOT_USE_IN_LOADOUTS_*` classes exist and `WILDCAT.cs:37` references one. | Do not delete as dead. Remove/replace the WILDCAT reference or make the generator fail on warning-marked loadouts, then smoke in Arma 2 OA. |

## Direct Public-Variable Findings

These are source-interpreted findings from the direct sender/receiver scan. The raw scan is intentionally conservative: it only records literal `publicVariable* "NAME"` and `"NAME" addPublicVariableEventHandler` lines. Dynamic channel names and variable-state broadcasts require human review.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `direct-pv-comment-only-legacy-channels` | Comment-only legacy direct PV | The scan found six direct `WFBE_*` channels only in comments: `WFBE_ChangeScore`, `WFBE_LocalizeMessage`, `WFBE_RequestSpecial`, `WFBE_RequestStructure`, `WFBE_RequestTeamUpdate`, `WFBE_RequestVehicleLock`. Example source rows sit beside `HandleSPVF`, `WFBE_CO_FNC_SendToServer`, `WFBE_CO_FNC_SendToClients` or PVF registrations in `Common/Init/Init_PublicVariables.sqf`. | Safe comment cleanup or annotation after branch-aware search. Keep the PVF registrations and helper calls. |
| `server-fps-dual-channel-drift` | Duplicate compatibility channel | `Server/GUI/serverFpsGUI.sqf:7` publishes `SERVER_FPS_GUI`; `Server/Module/serverFPS/monitorServerFPS.sqf:6` publishes `WFBE_VAR_SERVER_FPS`; source/Vanilla RHUD reads `SERVER_FPS_GUI`; Lingor modded RHUD still has a `WFBE_VAR_SERVER_FPS` wait/read path. | Treat `SERVER_FPS_GUI` as source/Vanilla UI contract. Consolidate only after modded/stale consumers are migrated or archived. |
| `icbm-launched-pveh-receiver-only` | Receiver-only legacy event handler | Source/Vanilla `Client/FSM/updateclient.sqf:20` registers `"ICBM_launched" addPublicVariableEventHandler`, but no active sender was found. Current tactical nuke flow spawns `NukeIncoming`, sends `RequestSpecial` `"ICBM"` to the server, and broadcasts `HandleSpecial` `"icbm-display"` to clients. | Do not delete ICBM. Either retire the stale `ICBM_launched` handler/receiver docs or revive it deliberately with one sender and one documented notification path. |

Source-checked false positives from this pass:

- `wfbe_supply_temp_east` and `wfbe_supply_temp_west` look receiver-only to the literal scan, but `Common_ChangeSideSupply.sqf:28-30` creates/sends them through `format ["wfbe_supply_temp_%1", _side]`.
- `kickAFK` looks sender-only because it is handled by the BattlEye `publicvariable.txt` filter rather than an SQF PVEH.
- HQ alive, HQ marker info, anti-stack compensation, team-no-player tick counters and similar sender-only rows are state broadcasts unless a later source pass proves no reader.
- `WFBE_PVF_%1` is the dynamic PVF registration pattern from `Init_PublicVariables.sqf`, not a literal runtime channel.

## UI And Rsc Findings

These are source-interpreted findings from the dialog/resource scan. The raw scan intentionally records broad UI leads; this section separates real mission-resource debt from engine-owned display IDs and comment-only residue.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `ui-duplicate-idd-collisions` | Duplicate misleading UI resource ID | `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000` (`Rsc/Dialogs.hpp:3209`, `:3211`, `:3287`, `:3289`) and both have live `createDialog` callers (`GUI_Menu_Service.sqf:244`, `GUI_Menu.sqf:172`). `RscOverlay` and `OptionsAvailable` both use `idd = 10200` (`Rsc/Titles.hpp:44`, `:46`, `:164`, `:165`) and both are used through `cutRsc` paths (`Init_Client.sqf:149`, `Client_UpdateRHUD.sqf:7`). | Do not delete any of these as dead. Assign unique IDDs only in a UI cleanup branch, then smoke EASA, economy, RHUD and action icons. |
| `parameters-display-commented-22005-idc` | Comment-only stale IDC reference | `GUI_Display_Parameters.sqf:12` actively writes parameter rows to `22003`; `:16-19` contains a block-commented uptime write to missing `22005`; `RscDisplay_Parameters` declares the dialog and live controls around `Rsc/Dialogs.hpp:3133`, `:3136`, `:3173`, `:3180`. | Safe comment cleanup or annotation. Do not add `22005` unless the old uptime row is intentionally revived. |

Source-checked false positives from this pass:

- IDC `101` in `WASP/global_marking_monitor.sqf` is a map/display control lead, not a missing mission `Rsc` declaration.
- IDC `116` in `Client/FSM/updateavailableactions.fsm` is an external/current display control lead, not a mission resource declaration gap.
- IDCs `112410`-`112414` in `Client/Module/UAV/uav_interface.sqf` belong to the UAV interface/display path and should be checked as BIS/UI integration IDs, not deleted as dead controls.
- IDC `22005` is comment-only in the parameters display and is not an active runtime write.

## Parameter And Config Findings

These are source-interpreted findings from the parameter/config scan. `Init_Parameters.sqf` imports every lobby `class Params` name into `missionNamespace`, so initialization alone does not prove gameplay use.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `ai-max-visible-parameter-no-runtime-consumer` | Visible parameter with no runtime consumer | `WFBE_C_AI_MAX` is visible in `Rsc/Parameters.hpp:56-60` and defaulted at `Init_CommonConstants.sqf:92`, but the parameter scan and fixed-string source search find no active runtime consumer outside parameter/default files. Current buy-menu and Soldier role cap behavior use `WFBE_C_PLAYERS_AI_MAX` instead (`GUI_Menu_BuyUnits.sqf:37`, `Skill_Init.sqf:49`). | Do not use `WFBE_C_AI_MAX` in player-cap or role-balance answers. Wire it to real AI-team sizing, hide/remove it, or mark it historical. |
| `units-clean-timeout-visible-parameter-comment-only-consumer` | Visible parameter with comment-only consumer | `WFBE_C_UNITS_CLEAN_TIMEOUT` is visible in `Rsc/Parameters.hpp:242-246` and defaulted at `Init_CommonConstants.sqf:348`, but `Common_TrashObject.sqf:19` actively reads `WFBE_C_UNITS_BODIES_TIMEOUT`; the old `WFBE_C_UNITS_CLEAN_TIMEOUT` split remains only in a commented line at `:20`. Empty vehicles use `WFBE_C_UNITS_EMPTY_TIMEOUT` via `Server_HandleEmptyVehicle.sqf:12`. | Decide whether the lobby body-timeout row should drive body cleanup, revive the old man/non-man split, or be removed/renamed. |

Source-checked false positives from this pass:

- `WFBE_C_ECONOMY_FUNDS_START_EAST`, `WFBE_C_ECONOMY_FUNDS_START_WEST`, `WFBE_C_ECONOMY_SUPPLY_START_EAST` and `WFBE_C_ECONOMY_SUPPLY_START_WEST` look readless in exact-name scan output, but server init/player-connect code reads them dynamically with `Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side]` and `Format ["WFBE_C_ECONOMY_SUPPLY_START_%1", _side]`.
- `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, `WFBE_C_MODULE_BIS_HC`, `WFBE_C_MODULE_WFBE_IRS`, hidden upgrade clearance and forced volumetric weather were already documented in the parameter/config owner pages. The parameter scan now gives repeatable evidence for those existing rows.

## Priority Backlog

| Priority | Work | Why |
| --- | --- | --- |
| P0 | Resolve or archive modded mission conflict markers before re-enabling modded packaging. | Raw merge markers are hard breakage if those missions are shipped. |
| P0 | Verify and fix/remove stale `RscMenu_Upgrade`. | A dialog `onLoad` points at a missing file, so any live caller can break player UI. |
| P1 | Decide MASH marker relay fate. | It has real PV wiring residue and could be useful, but it is currently half registered. |
| P1 | Keep `AIBuyUnit` latent until AI commander production is intentionally merged or retired. | It is dead-looking on stable but valuable for AI commander work. |
| P1 | Audit economy menu IDC `23004/23005/23006`. | Stale UI writes can hide broken commander economy controls. |
| P1 | Fix or formally waive duplicate UI IDDs `23000` and `10200`. | They are not dead, but they make future dialog/title ownership work brittle. |
| P1 | Decide the fate of visible dead/misleading parameters `WFBE_C_AI_MAX` and `WFBE_C_UNITS_CLEAN_TIMEOUT`. | They affect host/in-game parameter truth and can mislead balance/cleanup tuning. |
| P1 | Clean integration dead/stale helpers before expanding Discord/status tooling. | Dormant `.Auto` JSON helpers, stale `botconfig.json` ownership and arg-shape drift are easy to revive incorrectly. |
| P1 | Decide whether warning-marked CRV7PG loadouts are forbidden or intentionally quarantined. | A warning-named crash-risk class is referenced by WILDCAT data, so generator output may carry known-dangerous loadouts. |
| P1 | Decide whether the stale `ICBM_launched` PVEH should be retired or revived. | The current nuke path uses `NukeIncoming` and `HandleSpecial "icbm-display"`; a receiver-only event handler misleads future networking work. |
| P1 | Decide whether dormant SQF helper families are archive, revive or tooling-owned: `UpdateSupplyTruck`, `groupsMonitor`, `Common_ModifyAirVehicle`, `HandleATReloadVehicle`, IRS warning helpers, Reaktiv and TaskSystem. | They are source-backed stale code, but several have branch, tooling or modded context that makes blind deletion risky. |
| P2 | Remove or rationalize safe commented missing references: unitCaching, old blink loop, old bomb handler, old defense helper, WASP commented hooks. | Low-risk bloat cleanup once branch searches are complete. |
| P2 | Remove or annotate old direct `WFBE_*` publicVariable comment blocks after branch search. | They are migration residue and make the current PVF/helper network model harder to read. |
| P2 | Document generated `version.sqf` in every build/release handoff. | Prevent agents from misclassifying a required generated file as missing dead code. |
| P2 | Fix `RscClickableText.soundPush` after config smoke. | Likely malformed config, but resource classes have wide UI blast radius. |
| P2 | Split DiscordBot display terrain metadata from old LoadoutManager write APIs. | The bot should not carry mission file-writing API surface unless that is intentionally shared and tested. |

## Safe Cleanup Candidates

These are candidates for a future source patch because they are commented and point at absent files:

- `Client_BlinkMapIcons.sqf`, `Client_AddUnitToTrack.sqf` old comments.
- `Server_MapBlinkingUnits.sqf` old comment.
- `scripts\unitCaching\description.ext` commented include.
- `Common_HandleBombs.sqf` commented compile.
- `Common\Config\Config_Defenses.sqf` commented calls.
- `WASP\actions\OnArmor\timer.sqf`, `WASP\KeyDown.sqf`, `WASP\actions\SitsOnArmor\init.sqf` commented hooks.
- Commented legacy direct-PV names: `WFBE_RequestVehicleLock`, `WFBE_RequestSpecial`, `WFBE_RequestStructure`, `WFBE_RequestTeamUpdate`, `WFBE_ChangeScore`, `WFBE_LocalizeMessage`.
- Comment-only SQF hooks after owner review: `groupsMonitor.sqf`, `HandleATReloadVehicle`, and stale TaskSystem start comments.

Before changing source, run a branch-aware search against the target branch and verify generated mission propagation rules. Do not edit `Missions_Vanilla` directly for gameplay unless the build workflow requires it; source-of-truth rules still apply.

## Revive Candidates

| Candidate | Why preserve it | Revival gate |
| --- | --- | --- |
| MASH marker relay | Useful player-facing map state around mobile respawn. | Sender, server relay, client receiver, marker delete/JIP behavior and PV channel docs must be made coherent. |
| `AIBuyUnit` / `Server_BuyUnit.sqf` | Likely needed by AI commander production branches. | AI production scheduler, funds/cap policy, queue cleanup and Client_BuildUnit drift review. |
| Old marker blinking loop | Could be useful if map marker ownership is redesigned. | Must not regress current singular `Client_BlinkMapIcon` behavior. |
| `ICBM_launched` PVEH | Could be revived as a clear client notification channel for tactical nukes. | Must be reconciled with the current `NukeIncoming` / `RequestSpecial` / `HandleSpecial "icbm-display"` path and smoke-tested for friendly/enemy warnings, markers and damage. |
| AI supply-truck logistics | The script and config-gated spawn show an abandoned autonomous economy idea. | Needs a new server-owned logistics design; the old missing FSM cannot be restored by uncommenting one compile. |
| Reaktiv ERA armor | The module is self-contained enough to inspect and could add vehicle survivability tuning. | Must be wired in deliberately, checked against existing IRS/CM/inline rearmor handlers and smoke-tested for HandleDamage locality. |
| TaskSystem / commander task assignment | UI, receiver and old task helper residue show a recoverable commander UX idea. | Needs server authority, JIP behavior, spam controls and UI clarity before revival. |
| Modded maps | Community value, but currently conflict-marked and outside release packaging. | Conflict-free source, missing helper restoration, LoadoutManager policy and editor/dedicated smoke. |

## How To Rerun

From the repo root:

```powershell
.\docs\analysis\dead-code-reference-scan.ps1
```

Run the integration/tooling scan:

```powershell
.\docs\analysis\dead-code-integration-scan.ps1
```

Run the direct public-variable channel scan:

```powershell
.\docs\analysis\dead-code-pv-channel-scan.ps1
```

Run the UI/Rsc/dialog scan:

```powershell
.\docs\analysis\dead-code-ui-rsc-scan.ps1
```

Run the mission parameter/config scan:

```powershell
.\docs\analysis\dead-code-parameter-scan.ps1
```

Run the SQF reachability scan:

```powershell
.\docs\analysis\dead-code-sqf-reachability-scan.ps1
```

Validate the machine-readable register:

```powershell
Get-Content .\docs\analysis\dead-code-findings.jsonl | ForEach-Object { $_ | ConvertFrom-Json | Out-Null }
Get-Content .\docs\analysis\dead-code-integration-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-pv-channel-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-ui-rsc-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-parameter-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-sqf-reachability-scan.json | ConvertFrom-Json | Out-Null
```

Useful manual follow-up scans:

```powershell
rg -n "RscMenu_Upgrade|GUI_Menu_Upgrade|AIBuyUnit|Server_MapBlinkingUnits|Client_BlinkMapIcons|Client_AddUnitToTrack" Missions Missions_Vanilla Modded_Missions
rg -n "^\s*(<{7,}|={7,}|>{7,})" Modded_Missions
rg -n "WFBE_C_MODULE_BIS_HC|WFBE_C_AI_DELEGATION|23004|23005|23006" Missions Missions_Vanilla Modded_Missions
rg -n "WFBE_C_AI_MAX|WFBE_C_UNITS_CLEAN_TIMEOUT|WFBE_C_UNITS_BODIES_TIMEOUT|WFBE_C_PLAYERS_AI_MAX" Missions Missions_Vanilla Modded_Missions
rg -n "RscMenu_EASA|RscMenu_Economy|RscOverlay|OptionsAvailable|idd\s*=\s*23000|idd\s*=\s*10200" Missions Missions_Vanilla Modded_Missions
rg -n "ICBM_launched|WFBE_RequestVehicleLock|WFBE_RequestSpecial|WFBE_RequestTeamUpdate|WFBE_ChangeScore|WFBE_LocalizeMessage|WFBE_RequestStructure" Missions Missions_Vanilla Modded_Missions
rg -n "AI_UpdateSupplyTruck|UpdateSupplyTruck|groupsMonitor|Common_ModifyAirVehicle|Common_HandleATReloadVehicle|IRS_ShowWarning|IRS_PlayWarningSound|Reaktiv_Init|Client_TaskSystem" Missions Missions_Vanilla Modded_Missions
```

## Related Pages

- [Feature status](Feature-Status-Register)
- [Source fix propagation queue](Source-Fix-Propagation-Queue)
- [Content structure and maps](Content-Structure-And-Maps)
- [Tools and build workflow](Tools-And-Build-Workflow)
- [Client UI systems atlas](Client-UI-Systems-Atlas)
- [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas)
- [AI commander autonomy audit](AI-Commander-Autonomy-Audit)

## Continue Reading

Previous: [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) | Next: [Source fix propagation queue](Source-Fix-Propagation-Queue)

Main map: [Home](Home) | Status: [Progress dashboard](Progress-Dashboard) | Agent file: `docs/analysis/dead-code-findings.jsonl`
