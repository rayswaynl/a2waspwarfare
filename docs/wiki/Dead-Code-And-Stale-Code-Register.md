# Dead Code And Stale Code Register

This page is the cleanup map for code that appears dead, stale, unreachable, orphaned, or misleading in `rayswaynl/a2waspwarfare`.

It is not a delete list. It separates safe comment cleanup from risky broken features and revive candidates so future agents do not accidentally remove useful archaeology or branch-ready systems.

Core promoted machine-readable findings live in `docs/analysis/dead-code-findings.jsonl`. Scan-specific JSON files below are authoritative for newer raw scan sections, including asset/bootstrap and mission-copy evidence that may not be duplicated into the JSONL ledger.

Integration/tooling evidence is captured by `docs/analysis/dead-code-integration-scan.ps1`, with the latest output in `docs/analysis/dead-code-integration-scan.json`.

Direct public-variable channel evidence is captured by `docs/analysis/dead-code-pv-channel-scan.ps1`, with the latest output in `docs/analysis/dead-code-pv-channel-scan.json`.

UI/Rsc/dialog evidence is captured by `docs/analysis/dead-code-ui-rsc-scan.ps1`, with the latest output in `docs/analysis/dead-code-ui-rsc-scan.json`.

Mission parameter/config evidence is captured by `docs/analysis/dead-code-parameter-scan.ps1`, with the latest output in `docs/analysis/dead-code-parameter-scan.json`.

SQF reachability evidence is captured by `docs/analysis/dead-code-sqf-reachability-scan.ps1`, with the latest output in `docs/analysis/dead-code-sqf-reachability-scan.json`.

Mission-copy divergence evidence is captured by `docs/analysis/dead-code-mission-copy-divergence-scan.ps1`, with the latest output in `docs/analysis/dead-code-mission-copy-divergence-scan.json`.

Arma 2 OA compatibility / Arma 3-style API evidence is captured by `docs/analysis/dead-code-oa-compatibility-scan.ps1`, with the latest output in `docs/analysis/dead-code-oa-compatibility-scan.json`.

Asset, media and mission-bootstrap evidence is captured by `docs/analysis/dead-code-asset-reference-scan.ps1`, with the latest output in `docs/analysis/dead-code-asset-reference-scan.json`.

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
| Active parameters with no runtime references | 5 scan-baseline leads from the docs/source tree: `WFBE_C_AI_MAX`, `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, `WFBE_C_MODULE_BIS_HC`, `WFBE_C_MODULE_WFBE_IRS`, `WFBE_C_UNITS_CLEAN_TIMEOUT`. Current stable `origin/master@0139a346` rechecks close the two AI/cleanup rows for maintained roots; keep the scan output branch-scoped until regenerated. |
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

Latest mission-copy divergence scan:

| Item | Value |
| --- | --- |
| Mission roots scanned | 9: source Chernarus, Vanilla Takistan and 7 modded roots |
| Text files scanned | 2767 |
| Unique mission-relative paths | 690 |
| Identical copied paths | 548 |
| Diverged copied paths | 139 |
| Single-root-only paths | 3, all Vanilla-only artillery config files |
| Conflict-marker files / path groups | 18 files / 17 mission-relative path groups |
| Source Chernarus vs Vanilla Takistan | 687 paths compared: 670 identical, 17 diverged |
| Generated artifact | `docs/analysis/dead-code-mission-copy-divergence-scan.json` |

Latest Arma 2 OA compatibility scan:

| Item | Value |
| --- | --- |
| Roots scanned | `Missions`, `Missions_Vanilla`, `Modded_Missions`, `Tools`, `DiscordBot`, `Extension`, `BattlEyeFilter`, `docs/wiki` |
| Text files scanned | 3205 |
| Risk patterns checked | 22 |
| Code-risk implementation hits | 0 |
| Documentation/reference hits | 416, all routed through compatibility warning pages or machine mirrors |
| OA-safe inverse-trap hits | 1132: `diag_tickTime`, `uiSleep`, `setVehicleInit`, `processInitCommands` |
| Generated artifact | `docs/analysis/dead-code-oa-compatibility-scan.json` |

Latest asset/media/bootstrap scan:

| Item | Value |
| --- | --- |
| Mission roots scanned | 9: source Chernarus, Vanilla Takistan and 7 modded roots |
| Text files scanned | 2774 |
| Path/reference records | 5860 total, 5441 active |
| Resolved references | 3896 |
| External addon references | 583, including OA `\ca\...` assets/scripts |
| Active missing references | 890 total: 109 maintained-root leads and 781 modded-root leads |
| Missing bootstrap files | 21, all under `Modded_Missions` roots |
| Generated artifact | `docs/analysis/dead-code-asset-reference-scan.json` |

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
- Parameter `set-like override` counts are broad scan leads, not automatic bugs. Source-read each row's `runtimeReferences`: some hits are intentional forced-mode or solo-test assignments rather than stale lobby parameters.
- SQF reachability scans cannot prove dynamic `addAction`, `missionNamespace getVariable`, `Format` or generated path usage. Treat `Client/Module/Skill/Skill_*.sqf`, `Server/Construction/Construction_*Site.sqf`, config arrays and mission entrypoints as source-check leads, not dead files.
- Baseline and modded source can legitimately differ. Example: source Chernarus/Vanilla IRS warning helpers are unreferenced after inline warning logic was added, while the conflict-marked Napf IRS file still contains old helper calls.
- Mission-copy divergence does not automatically mean dead code. Source Chernarus vs Vanilla Takistan differences are often map/generated differences such as help text, database map id, Takistani resistance units, start vehicles, `mission.sqm`, artillery config and `version.sqf`.
- Modded-copy divergence is a release-readiness warning. Current tooling does not package or regenerate `Modded_Missions`, so drift there should be quarantined until the owner chooses a maintained-fork or regenerate-from-source policy.
- Arma 3-style term hits are not automatically defects. Docs intentionally contain warnings such as `remoteExec` / `CfgFunctions` / `parseSimpleArray`, while code intentionally uses OA-safe inverse-trap commands such as `diag_tickTime`, `uiSleep`, `setVehicleInit` and `processInitCommands`.
- Asset scans cannot infer surrounding `IS_chernarus_map_dependent` branches. Several apparent missing `Textures/*.paa` records are Chernarus/Takistan complementary assets guarded by map-profile checks, not guaranteed runtime failures.
- Quoted filename fragments can be part of dynamically built external addon paths. Example: nuke missile particle scripts are assembled from `\ca\air2\cruisemissile\data\scripts\...` in `Client/Module/Nuke/nukeincoming.sqf`, so `cruisemissileflare.sqf` and `exhaust1.sqf` are OA addon references rather than repo-local missing files.

## Classification Rules

This table defines common labels used by the register. The append-only `dead-code-findings.jsonl` ledger may contain narrower one-off labels; source-read those records before renaming, deleting or merging them.

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
| `modded-copy-quarantine` | Old modded mission copies differ from source/Vanilla and are outside the current packaging/regeneration path. | Do not ship or use as code truth until regenerated or explicitly maintained. |
| `source-generated-map-specific-divergence` | Source Chernarus and Vanilla Takistan differ only in map/terrain/generated data. | Keep documented as intentional; do not flatten these differences during cleanup. |
| `oa-compatibility-guardrail` | A pattern looks modern/A3-ish or docs contain A3 terminology, but source review proves no unsupported implementation path. | Keep warnings clear; do not convert them into implementation advice. |
| `oa-safe-inverse-trap-not-dead` | A command looks suspicious to A3-trained agents but is valid/load-bearing in Arma 2 OA. | Preserve unless an OA-compatible replacement is designed and smoked. |
| `asset-bootstrap-release-risk` | Mission-facing asset, media or bootstrap references are missing or generated outside Git. | Treat as release/test gate evidence; source-check map branches and addon paths before patching. |
| `map-conditional-asset-false-positive` | A static scan reports a local asset missing in one maintained root, but the surrounding code is guarded by the opposite terrain profile. | Do not patch blindly. Verify the branch can execute in the target generated mission. |

## Current Findings

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `old-map-blink-loop-missing-files` | Branch-split retired commented reference | Current docs checkout `3406ffa0` Chernarus and maintained Vanilla still keep the old plural blink/add-track comments at `Client/Init/Init_Client.sqf:138,140,782`, while `:139` compiles the live singular `Client_BlinkMapIcon.sqf`. Miksuu `b8389e74` keeps the old comments with line drift at `:140,142,796`; `origin/perf/quick-wins@0076040f` keeps docs-shaped lines. Current stable `origin/master@0139a346` and historical `a96fdda2` no longer carry the old plural/AddUnitToTrack comments in checked maintained roots; they preserve the live singular compile at stable `:163` and historical `:143`. | Safe comment cleanup only on old-shape targets. Keep the singular blink helper and do not claim marker blinking is wholly dead. |
| `server-map-blinking-units-commented-missing` | Branch-split retired commented reference | Current docs checkout `3406ffa0` and Miksuu `b8389e74` keep the commented missing `Server_MapBlinkingUnits.sqf` exec at `Server/Init/Init_Server.sqf:593` in both maintained roots; perf keeps it at Chernarus `:588` and Vanilla `:593`. Current stable `origin/master@0139a346` and historical `a96fdda2` have no checked maintained-root `Server_MapBlinkingUnits.sqf` file and no old commented exec. | Treat as retired unless marker authority is redesigned; no current-stable cleanup remains for this exact comment. |
| `stale-rscmenu-upgrade-missing-onload` | Broken stale UI class | Current docs/source `HEAD@0fdd5602` remains source-unchanged from `d4cfef80` for checked Chernarus/Vanilla upgrade dialog/controller paths and keeps `RscMenu_Upgrade` at `Rsc/Dialogs.hpp:2425` with `onLoad` pointing at missing `Client/GUI/GUI_Menu_Upgrade.sqf` at `:2428` in both maintained roots. The UI/Rsc scan confirms this is the only `RscMenu_*` class without literal `createDialog` calls and the handler target is missing across source, Vanilla and modded copies. Current Miksuu `b8389e748243` and perf `0076040f` keep the stale class at `Rsc/Dialogs.hpp:2435,:2438`; current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f`, historical release `a96fdda2` and historical upgrade-queue `b061c905` have no checked maintained-root `RscMenu_Upgrade` / `GUI_Menu_Upgrade.sqf` hits and keep only live `WFBE_UpgradeMenu` at `Rsc/Dialogs.hpp:4-7`. | Branch search is current for the checked maintained heads. Code owner should preserve/port the current stable/B69/B74/release deletion to old-shape docs/Miksuu/perf targets, or replace the old class with an explicit compatibility alias to `WFBE_UpgradeMenu`; do not recreate missing `GUI_Menu_Upgrade.sqf` or `wf_*.paa` art blindly. Canonical lane: [UI resource parity cleanup](UI-Resource-Parity-Cleanup). |
| `main-menu-gps-orphan-actions` | Dormant UI router cases | Source Chernarus and maintained Vanilla handle `MenuAction == 17/18` in `Client/GUI/GUI_Menu.sqf:202-208`; `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle` keep the same handler shape in Chernarus plus Vanilla. Fixed-string action searches found no `MenuAction = 17` or `MenuAction = 18` emitters in maintained roots; current `WF_Menu` controls expose actions `1-13`, `16` and `19`. | Docs-ready low-risk UI cleanup. Either remove/comment the dormant GPS zoom router cases across maintained roots, or reintroduce intentional controls and smoke GPS zoom without overlapping existing main-menu action ids. |
| `mash-marker-relay-orphaned` | Orphaned partial feature | Server compiles `MASHMarker.sqf`; client receiver compile is commented at `Client/Init/Init_Client.sqf:132`; sender/receiver PV channels do not form a maintained Chernarus loop. | Decide retire vs revive. MASH tents are not dead; local MASH respawn is source-supported. Canonical matrix: [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay). |
| `latent-aibuyunit-server-buy-worker` | Latent revive candidate | `Server/Init/Init_Server.sqf:10` compiles `AIBuyUnit`, but stable source search finds no caller; `Server_BuyUnit.sqf` is an AI/team worker. | Do not delete casually. Needed if AI commander production is revived. |
| `legacy-compiled-aliases-no-static-callers` | Latent revive / stale alias candidates | Current Chernarus and maintained Vanilla still compile old globals such as `AITownResitance`, `EquipLoadout`, `GetGroupFromConfig`, `GetSafePlace`, `GetUnitsBelowHeight`, `UseStationaryDefense`, `ReplaceArray`, `FireArtillery`, `GetSideUpgrades` and client `HandlePVF`; a 2026-06-06 whole-symbol scan found zero active static callers after excluding compile lines, comments and the helper file itself. | Keep the source-backed alias table in [Function and module index](Function-And-Module-Index#legacy-compiled-aliases-with-no-static-callers). Do not label shared helpers dead where newer `WFBE_*` names still call the same file. Dynamic/runtime use remains an uncertainty until an Arma smoke or namespace trace proves otherwise. |
| `modded-mission-conflict-markers` | Broken modded mission sources | 18 files under `Modded_Missions` contain real `<<<<<<<`, `=======`, `>>>>>>>` markers; the mission-copy divergence scan groups them into 17 mission-relative paths, including Eden `Skill_Apply.sqf`, Lingor `Client_UpdateRHUD.sqf`, Napf `description.ext` and multiple root/config files. | Resolve before any modded release. Do not blindly delete sections. |
| `unitcaching-commented-absent-scaffold` | Retired commented reference | `description.ext:37` comments `scripts\unitCaching\description.ext`; the folder is absent. | Safe comment cleanup or keep as abandoned optimization note. |
| `common-handlebombs-commented-missing` | Retired commented reference | `Common/Init/Init_Common.sqf:11` comments missing `Common_HandleBombs.sqf`. | Safe comment cleanup; live IRS/missile systems are separate. |
| `legacy-config-defenses-commented-missing` | Retired commented reference | Defense files call live `Config_Defenses_Towns.sqf` and retain commented old `Config_Defenses.sqf` calls. | Safe comment cleanup after branch search. |
| `wasp-commented-action-scaffolds` | Retired commented reference, narrow scope | `WASP/Init_Client.sqf:7`, `:12`, `:21` point at missing old action/key scripts; adjacent WASP action helpers still have uses. | Clean only commented missing hooks unless a full WASP action inventory proves more. |
| `bis-hc-parameter-orphan` | Orphan-looking config | `Rsc/Parameters.hpp:381` exposes `WFBE_C_MODULE_BIS_HC`; HC delegation uses `WFBE_C_AI_DELEGATION`. | Hide/remove or wire a real BIS High Command feature; do not label it as headless-client enablement. |
| `ai-max-visible-parameter-no-runtime-consumer` | Branch-split visible parameter | Docs branch `origin/docs/developer-wiki-index@ac932fbe`, current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f` and historical release `a96fdda2` still expose/default `WFBE_C_AI_MAX` without an active maintained-root runtime reader found. Current stable `origin/master@0139a346` reads it at `Server/AI/Commander/AI_Commander_Produce.sqf:89` in both maintained roots. Player follower caps still use `WFBE_C_PLAYERS_AI_MAX`; local `d9506078` is not current Miksuu upstream. | Do not use this for player cap answers. For old-shape refs, port the AI commander production reader or hide/label the row. For current stable, smoke AI commander production sizing before release-complete wording. Canonical route: [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#parameter-cache-flow). |
| `units-clean-timeout-visible-parameter-comment-only-consumer` | Branch-split visible cleanup parameter | Docs branch `origin/docs/developer-wiki-index@ac932fbe`, current Miksuu `master@b8389e748243`, `origin/perf/quick-wins@0076040f` and historical release `a96fdda2` keep `WFBE_C_UNITS_CLEAN_TIMEOUT` comment-only in the old split at `Common_TrashObject.sqf:20`. Current stable `origin/master@0139a346` uses it at `Common_TrashObject.sqf:21` for non-man wreck cleanup while bodies use `WFBE_C_UNITS_BODIES_TIMEOUT`; empty vehicles separately use `WFBE_C_UNITS_EMPTY_TIMEOUT`. | For old-shape refs, port the B35/current split or hide/rename the row. For current stable, do not call it no-op; smoke body, wreck and empty-vehicle cleanup separately. Canonical route: [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#parameter-cache-flow). |
| `economy-menu-missing-control-writes` | Stale UI control writes | Current-B74 refresh 2026-06-23: docs/source `HEAD@21f0d53b` is unchanged from `d2a3f995` / `b5219d47` for checked Economy controller/resource paths and still writes IDC `23004/23005/23006` at `GUI_Menu_Economy.sqf:7-8` in both maintained roots; audited docs/source `RscMenu_Economy` declares `23002/23003` then `23008+` without `23020`. Current Miksuu `b8389e748243` and perf `0076040f` keep that stale-write shape. Current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f` and historical `a96fdda2` remove the stale writes, use `DisplayCtrl 23020` at `GUI_Menu_Economy.sqf:25` and declare `23020` in both maintained roots. | Docs-ready parity cleanup for old-shape targets. Preserve/port the current stable/B69/B74/release `23020` shape or remove/update stale writes consistently across maintained roots; smoke Economy disabled state, income controls, sell mode and supply-truck respawn. Canonical lane: [UI resource parity cleanup](UI-Resource-Parity-Cleanup). |
| `modded-missing-camp-helper-files` | Broken modded source reference | Modded `Init_Common.sqf` files compile `Common_GetTotalCamps*.sqf`; scan reports missing helpers in modded roots. | Restore from current source or regenerate modded missions before release. |
| `generated-version-sqf-clean-checkout-risk` | Generated-file contract risk | Mission entrypoints include `version.sqf`; LoadoutManager generates/excludes it. | Keep includes; validate generation workflow on clean checkout. |
| `rsc-clickabletext-soundpush-malformed` | Branch-split malformed resource config | Current-B74 refresh 2026-06-23: docs/source `HEAD@0bb0f89f`, current Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f` and UI theme branches `0767c0b5` / `87d86257` still have `Rsc/Ressources.hpp:556` `soundPush[] = {, 0.2, 1};` in both maintained roots with 17 derived `RscClickableText` controls; historical release `a96fdda2` keeps the malformed value with 14 controls. Current stable `origin/master@0139a346`, B69 `8d465fce` and B74 `b23f557f` carry valid `{"", 0.2, 1}` at `:556` in both maintained roots, matching the valid `:92` precedent; stable blame is `1a5e0b40` for Chernarus and `9b49883c` for maintained Vanilla. | Use [Client UI systems](Client-UI-Systems-Atlas#clickable-text-soundpush-branch-matrix); do not reopen current stable/B69/B74. Replace old-shape branch values only after config/dialog smoke scope is named. |
| `modded-packaging-disabled-by-tooling` | Deferred release scope | `Tools/LoadoutManager/ZipManager.cs:16` packages `Missions` and `Missions_Vanilla`; `SqfFileGenerator.cs:133` says add modded maps later. | Keep disabled until conflict/missing-reference checks pass, or archive old modded roots. |

## Asset And Bootstrap Findings

These findings are source-interpreted from the asset/media/bootstrap scan. They supplement [Assets/config/localization/parameters](Assets-Config-Localization-And-Parameters-Atlas) and the modded mission map table in [Content structure and maps](Content-Structure-And-Maps).

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `asset-scan-repeatable-release-gate` | Asset/bootstrap release risk | The scan found 5860 path/reference records across 2774 mission-root text files, 3896 resolved references, 583 external addon references and 21 missing bootstrap files. All missing bootstrap files are in `Modded_Missions`, matching the existing packaging quarantine: several roots lack `description.ext`, `mission.sqm`, `initJIPCompatible.sqf` and/or generated `version.sqf`. | Use the scanner as a release gate before claiming any terrain root is pack/test-ready. Keep modded roots quarantined until generated or explicitly maintained. |
| `rscmenu-upgrade-icons-missing-assets` | Broken stale UI class | Docs/source Chernarus and maintained Vanilla `Rsc/Dialogs.hpp:2425-2428` point `RscMenu_Upgrade` at missing `Client\GUI\GUI_Menu_Upgrade.sqf`; the same stale block references missing `Client\Images\wf_*.paa` icons at `Dialogs.hpp:2634-2821`. Live upgrade flow uses `WFBE_UpgradeMenu` / `Client\GUI\GUI_UpgradeMenu.sqf`. Current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f`, historical release `a96fdda2` and historical upgrade-queue `b061c905` have no checked maintained-root stale-class hits; current Miksuu and perf still carry the stale block at `Dialogs.hpp:2435,:2438`. | Treat the old dialog as stale on old-shape targets. Prefer removing/aliasing the old resource across maintained roots instead of recreating unused art blindly; if importing current stable/release deletion, verify maintained Vanilla parity through [UI resource parity cleanup](UI-Resource-Parity-Cleanup). |
| `map-conditional-vehicle-texture-leads` | Map-conditional asset false positive | `Common_AddVehicleTexture.sqf` includes both Chernarus and non-Chernarus texture branches. Example: Chernarus `version.sqf:3` defines `IS_CHERNARUS_MAP_DEPENDENT`, while Vanilla Takistan comments it at `version.sqf:3`; `initJIPCompatible.sqf:111-113` converts that define into `IS_chernarus_map_dependent`. Static scan therefore reports opposite-root assets as missing even when the branch should not execute. The West LAV HQ texture calls in `Init_Server.sqf:322-327`, `Construction_HQSite.sqf:81-86` and `Server_MHQRepair.sqf:27-32` are also guarded behind `!(IS_chernarus_map_dependent)`. | Before adding or deleting texture files, smoke the target terrain profile and check whether the guarded branch can run there. Do not flatten Chernarus/Takistan asset sets solely to satisfy a static scan. |

Source-checked false positives and guardrails from this pass:

- `\ca\...` and dynamically concatenated OA addon paths are not repo-local missing files.
- `loadScreen.jpg` is live and present in maintained roots; do not remove it as unused.
- `version.sqf` is generated metadata and a release gate, not dead code, even though clean tracked checkouts may not contain it.
- Modded roots remain the dominant missing-bootstrap/missing-reference source and should not be used as implementation truth until regenerated or explicitly maintained.

## Mission Copy Divergence Findings

These are source-interpreted findings from the mission-copy divergence scan. The purpose is not to make every mission copy byte-identical; it is to show where a future cleanup or hardening patch must propagate and where old copies should be quarantined.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `source-vanilla-map-specific-divergence-guardrail` | Source/generated map-specific divergence | Source Chernarus and Vanilla Takistan compare 687 mission-relative paths: 670 are byte-identical and 17 diverge. Source checks show representative divergences are intentional map/generated data: help title says Chernarus vs Takistan (`GUI_Menu_Help.sqf:149`), database map id is `SET_MAP 1` vs `2` (`Init_Server.sqf:613`), `version.sqf` has player count/name flags (`:7-8`), `WASP/unsort/StartVeh.sqf:1,15-16` uses terrain-specific start vehicles, and the remaining single-root-only paths are Vanilla-only artillery configs referenced by Takistan root configs. | Do not flatten these differences during dead-code cleanup. Treat non-map logic files that diverge outside this small set as propagation-review candidates. |
| `modded-mission-copy-drift-quarantine` | Modded copy quarantine | The scan found 139 diverged mission-relative paths across 9 roots; high-fanout drift includes runtime/UI/PVF/FSM paths such as `Client\Client_EndGame.sqf`, `Client\Client_UpdateRHUD.sqf`, `Client/GUI/GUI_Menu_Command.sqf`, `Client/PVFunctions/HandleSpecial.sqf`, `Server/Init/Init_Server.sqf`, `Server/Functions/Server_HandleSpecial.sqf` and `Common/Functions/Common_OnUnitKilled.sqf`. `ZipManager.cs:16` packages only `Missions` and `Missions_Vanilla`, while `SqfFileGenerator.cs:131-133` comments modded writes with a TODO to add them back later. | Keep `Modded_Missions` out of code truth and release claims until an owner either regenerates them from hardened source or maintains them as explicit forks with separate audits. |

Source-checked false positives and guardrails from this pass:

- Vanilla-only `Common/Config/Core_Artillery/Artillery_TKA.sqf`, `Artillery_TKGUE.sqf` and `Artillery_US.sqf` are not automatically dead: Takistan root configs actively compile the OA/CO artillery config family.
- Source Chernarus vs Vanilla Takistan `mission.sqm` divergence is expected because editor objects, markers and playable slots are map-specific.
- `version.sqf` divergence is expected when generated correctly. Chernarus currently carries `WF_MAXPLAYERS 55` and `WF_MISSIONNAME "[55] Warfare V48 Chernarus"`; Vanilla Takistan carries `WF_MAXPLAYERS 61` and `WF_MISSIONNAME "[61] Warfare V48 Takistan"`.

## Arma 2 OA Compatibility Findings

These findings are source-interpreted from the OA compatibility scan. They help future cleanup agents avoid two opposite mistakes: importing Arma 3 APIs into OA code, or deleting OA-safe commands because Arma 3 removed or replaced them.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `oa-compatibility-no-a3-api-code-risk` | OA compatibility guardrail | The scan checked 22 risky patterns across 3199 text files in mission roots, tools, integrations, BattlEye and docs. It found **0** code-risk implementation hits for `remoteExec`, `BIS_fnc_MP`, `addMissionEventHandler`, `isRemoteExecuted`, `remoteExecutedOwner`, `parseSimpleArray`, `RVExtensionArgs`, `CfgFunctions`, `isEqualTo`, SQF `params`, `apply`, `pushBack`, `allPlayers`, A3 loadout APIs, `createSimpleObject` and `setGroupOwner` outside docs. | Keep the current OA-era publicVariable/PVEH/manual-init model unless a code owner proves OA support and smokes a migration. |
| `oa-safe-inverse-trap-commands-not-dead` | OA-safe inverse-trap, not dead | The scan found 1132 live inverse-trap hits: `diag_tickTime` in mission roots and LoadoutManager-generated SQF text, `uiSleep` in source/Vanilla server timing loops, and `setVehicleInit` / `processInitCommands` across source, Vanilla and modded mission roots. [Arma 2 OA command version reference](Arma-2-OA-Command-Version-Reference) classifies these as OA-safe/load-bearing. Representative source paths include `Client/Client_UpdateRHUD.sqf:187`, `Server/Module/supplyMission/supplyMissionTimerForTown.sqf:5`, `Client/Module/UAV/uav.sqf:30-31` and `Common/Functions/Common_CreateVehicle.sqf`/construction support paths. | Do not remove these as "A3-only" or "A3-banned" cleanup. Preserve until an OA-compatible replacement exists and runtime smoke proves parity. |

Source-checked false positives and guardrails from this pass:

- `paramsArray` / mission `class Params` are valid mission-parameter constructs here and are not the newer SQF `params` command.
- `Modded_Missions/[55-2hc]warfarev2_073v48co.eden` remains a terrain/folder name, not proof of Eden Editor workflow.
- Documentation hits for `remoteExec`, `parseSimpleArray`, `RVExtensionArgs`, `CfgFunctions`, `CBA`, `ACE` and related terms are warning/contrast text unless an agent turns them into implementation advice.

## SQF Reachability Findings

These are source-interpreted findings from the SQF reachability scan. The scan only proves that no literal active quoted path reached a file; every row below was checked against the relevant init, module or dynamic-dispatch owner before being promoted.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `sqf-ai-supply-truck-worker-comment-only` | Comment-only SQF worker; current stable safe-disables caller | Branch-split after the 2026-06-22 current-stable refresh: the docs checkout still comments the `UpdateSupplyTruck` compile at `Server/Init/Init_Server.sqf:36` but raw-spawns the worker at `:382-383` in Chernarus and maintained Vanilla; current stable `origin/master@0139a346` comments the compile at `:43`, initializes `wfbe_ai_supplytrucks`, and warning-disables legacy logistics at `:462-463` in both maintained roots. `AI_UpdateSupplyTruck.sqf:17` still points at missing `Server\FSM\supplytruck.fsm`; `git ls-tree` found no `supplytruck.fsm` in current stable, perf, historical `a96fdda2` or historical `c20ce153`. `origin/perf/quick-wins@0076040f` still raw-spawns the worker, historical `a96fdda2` safe-disables it, and historical `c20ce153` guards only Chernarus while maintained Vanilla remains raw. Current origin exposes no `release/*` or `feat/ai-commander` heads on 2026-06-22. | Keep documented as dormant/broken logistics code. Do not simply uncomment; preserve/port the current-stable safe-disable or redesign AI logistics with a real server-owned loop/FSM. |
| `groupsmonitor-commented-debug-loop` | Comment-only SQF entrypoint | `Server/FSM/groupsMonitor.sqf:1-14` logs `allGroups` counts every 30 seconds, but the only source start point found is commented at `Server/Init/Init_Server.sqf:567`. | Safe to leave dormant. If revived, make it an explicit debug parameter/tooling feature to avoid production log spam. |
| `common-modify-airvehicle-tooling-owned-dormant-hook` | Tooling-owned dormant hook | `Common/Functions/Common_CreateVehicle.sqf:22` comments the aircraft post-create call; `Common_ModifyAirVehicle.sqf` still contains `//LoadoutManagerInsertChanges` and generated aircraft rearmor cases. | Do not delete as dead runtime code until LoadoutManager's generated-aircraft contract is redesigned or retired. |
| `common-handle-at-reload-comment-only` | Comment-only SQF entrypoint | `Common/Init/Init_Common.sqf:10` comments `HandleATReloadVehicle`; the existing helper manipulates TOW magazine/reload timing but no active compile/caller is found. | Treat with the existing AT/bomb hook family as archive/revive work. Do not call current ordnance guardrails dependent on it. |
| `irs-warning-helpers-baseline-unreferenced` | Baseline unreferenced / modded-live split | Source Chernarus and Vanilla `IRS_Init.sqf` compile `CreateSmoke`, `DeploySmoke`, `HandleMissile` and `OnIncomingMissile` only; `IRS_ShowWarning.sqf` and `IRS_PlayWarningSound.sqf` have no maintained-source caller. Napf's conflict-marked IRS file still contains old calls to both helpers. | Do not delete globally until modded mission policy is settled. For source/Vanilla, treat the inline `inboundMissileGround` logic in `IRS_OnIncomingMissile.sqf` as the current path. |
| `reaktiv-init-unreachable` | Orphaned module script / branch-split maintained-root residue | Current docs/source Chernarus and maintained Vanilla still carry `Common/Module/Reaktiv/Reaktiv_Init.sqf:5` and `Reaktiv_OnHandleDamage.sqf:7`, but `Init_Common.sqf:319-323` initializes only ICBM, IRS and CIPHER. Branch check refreshed 2026-06-14: stable `origin/master` `cf2a6d6a` and release `a96fdda2` have no maintained-root `Common/Module/Reaktiv` hits; Miksuu `b8389e74` and `perf/quick-wins` `0076040f` still carry the unreachable maintained-root files with no init call; all checked refs still carry stale modded Napf/Eden/Lingor copies. | [Modules atlas](Modules-Atlas#reaktiv--reactive-era-armor-commonmodulereaktiv) owns the current branch matrix. Preserve only if an owner wants ERA armor revived and smoke-tested; otherwise stable/release provide maintained-root removal precedent, but modded cleanup still needs policy. |
| `ai-respawn-handlers-orphaned` | Orphaned/uncalled subsystem ([Deep-review findings](Deep-Review-Findings) DR-51) | Agent-team verified 2026-06-07: `Server/AI/AI_AddMultiplayerRespawnEH.sqf` (the only `addMPEventHandler` attach for `AIAdvancedRespawn`) has zero call sites; `AIAdvancedRespawn` (`Init_Server.sqf:12`) is therefore dead. `AISquadRespawn` (`Init_Server.sqf:11`) is gated by `WF_A2_Vanilla`, set `false` unconditionally at `initJIPCompatible.sqf:91` (`#define VANILLA` never exists), and has no `spawn AISquadRespawn` caller. Both server AI-respawn paths are compiled-but-uncalled. | Owner decision: wire `AI_AddMultiplayerRespawnEH` at AI group creation to restore leader respawn, or delete the dead path. Arma smoke (kill an AI leader, confirm respawn behavior) before any patch. |
| `ai-tlwphandler-sqs-dead` | Dead legacy SQS ([Deep-review findings](Deep-Review-Findings) DR-51 routing) | `Server/AI/AI_TLWPHandler.sqs` is a legacy SQS straggler-sync loop (teleports squad members >150 m behind the leader after 240 s) with **no call site anywhere** — grep for `AI_TLWPHandler` / `TLWPHandler` / `TLWP` returns only the file itself. | Safe cleanup candidate: delete, or integrate into the respawn/order flow if straggler-sync is wanted. |
| `client-task-system-comment-only` | Branch-split disabled legacy town-task UX path | Current docs checkout `3406ffa0`, Miksuu `b8389e74` and `origin/perf/quick-wins@0076040f` keep the old `TaskSystem` compile and town task spawns commented in both maintained roots (`Client/Init/Init_Client.sqf:75,744` on docs; `:75,758` on Miksuu/historical release; `:75,759` on perf; `TownCaptured.sqf:35,87` or line-drift `:36,88`) and keep `Client_TaskSystem.sqf` present. Current stable `origin/master@0139a346` still has comment residue at `Client/Init/Init_Client.sqf:94,819` and `TownCaptured.sqf:36,88`, but `Client_TaskSystem.sqf` is absent in both maintained roots. Historical `a96fdda2` keeps the helper file and old comments while separately carrying Objective Ping `SetTask` sends in `GUI_Menu_Command.sqf:336,344`. Current origin exposes no `release/*` or task/blink feature heads on 2026-06-22. | Owner decision: hide/remove the old town-task comments or rebuild it as a new JIP-safe task feature. Treat current-stable/historical Objective Ping as a separate commander UI path, not a revival of the old town TaskSystem. |

### Deep dead-code sweep — 2026-06-07 (megapass agent team, adversarially verified)

A whole-tree reachability sweep (Client + Common/Server/WASP lanes) surfaced these NEW unreachable items beyond the already-registered ones. All were confirmed by a second verifier (zero static call site; dynamic-dispatch paths — Skill `WFBE_SK_V_Root`, construction `STRUCTURESCRIPTS`, `WFBE_*_FNC_` names — were checked and excluded). Group by failure mode:

**Never compiled / never referenced (helper files with no loader):**

| File | Evidence |
| --- | --- |
| `Common/Functions/Common_HandleMissiles.sqf` | No `preprocessFile`/`execVM`/alias reference anywhere. |
| `Common/Functions/Common_GetClientTeam.sqf` | Never compiled; uses alias `GetNamespace` which is itself never compiled. |
| `Common/Functions/Common_GetNameSpace.sqf` | Never compiled; only token use is in the (dead) `Common_GetClientTeam.sqf` and a commented `Init_Client.sqf:559`. |
| `Common/Functions/Common_SetNamespace.sqf` | Never compiled; references the uncompiled `GetNamespace` alias. |
| `Client/Functions/Client_GetMarkerColoration.sqf` | `GetMarkerColoration` — zero references tree-wide; not compiled in `Init_Client.sqf`. |
| `Client/Functions/Client_SetAttackWaveDetails.sqf` | `SetAttackWaveDetails` — zero references; the live counterpart is `Client_SendSpawnedUnitsToLeaderWaypoint.sqf`. |
| `Client/Functions/Client_ getEnemiesPlayers.sqf`, `Client_getEastPlayers.sqf`, `Client_getWestPlayers.sqf`, `Client_getFriendliesPlayers.sqf` | A four-file cluster that only references each other; none is compiled/`execVM`'d from any reachable entrypoint. (Note the stray space in the first filename.) |

**Compiled-but-never-called globals (compile line exists, no call site):**

| Global / file | Evidence |
| --- | --- |
| `ReplaceArray` (`Client/Init/Init_Client.sqf:67` → `Client_ReplaceArray.sqf`) | Only the compile line; never called. (Pairs with the legacy-alias `ReplaceArray` already noted in the Function index.) |
| `WFBE_CO_FNC_GetClosestEnemyLocation` (`Common_GetClosestEnemyLocation.sqf`, `Init_Common.sqf:117`) | Compiled, zero call sites. |
| `WFBE_CO_FNC_GetUnitsPerSide` (`Common_GetUnitsPerSide.sqf`, `Init_Common.sqf:141`) | Compiled, zero call sites. |
| `Server/PVFunctions/LogGameEnd.sqf` | Old duplicate; never compiled where present. It exists in current docs head `a0a86da2` (source-unchanged from `2f2132f8` for this path), Miksuu `b8389e74` and perf `0076040f` maintained roots, but is absent from stable `origin/master` `cf2a6d6a` and release `a96fdda2` maintained roots. The live path is `Server/Functions/Server_LogGameEnd.sqf` (`WFBE_CO_FNC_LogGameEnd`, docs checkout `Init_Server.sqf:64,89`, called from `server_victory_threeway.sqf:41`). The PVFunctions copy also has a broken `profileNamespace` ref. |
| `Client/PVFunctions/SetTask.sqf` | PVEH `WFBE_PVF_SetTask` is registered (`Init_PublicVariables.sqf:33`) but every sender in `GUI_Menu_Command.sqf:335,337,343` is commented out → orphaned receiver (same dormant town-task family as `client-task-system-comment-only`). |
| `WFBE_SE_FNC_AI_Com_Upgrade` (`Server_AI_Com_Upgrade.sqf`, `Init_Server.sqf:48`) | ⚠️ Compiled, **zero callers**. Consistent with the dormant AI-commander FSM (see [Deep-review findings](Deep-Review-Findings) DR-14/DR-15 "AI commander FSM never starts"): the AI-commander **upgrade execution path is dormant**. This means the detailed [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) describes a function that is not currently invoked — preserve it as "what would happen if the AI-commander FSM ran," and verify whether AI commanders upgrade at all before any patch. |
| `WFBE_SE_FNC_AI_SetTownAttackPath` (+ `_PathIsSafe`, `_PosIsSafe`) (`Init_Server.sqf:45-47`) | ⚠️ Compiled, **zero callers** for the top-level function. Bears on audit rows AI7/AI17 (which analyzed it) — those describe dormant code; attack pathing on master appears to run through `Common_WaypointsAdd.sqf` instead. Verify dynamic dispatch + the AI-commander dormancy before treating AI7/AI17 as live runtime bugs. |

**Commented-out compile, file intact (revive-or-delete):**

| File | Evidence |
| --- | --- |
| `Common/Functions/Common_ModifyAirVehicle.sqf` | Only ref is the commented `Common_CreateVehicle.sqf:29` aircraft post-create hook (tooling-owned; already noted as `common-modify-airvehicle-tooling-owned-dormant-hook`). |
| `Common/Functions/Common_HandleATReloadVehicle.sqf` | Compile commented at `Init_Common.sqf:10`; alias appears nowhere else. |
| `WASP/actions/GearYouUnit.sqf` | Only ref is the commented `addAction` at `WASP/actions/AddActions.sqf:4`. |
| `WASP/actions/car_wheel_new.sqf` | Only ref is the commented `addAction` at `WASP/actions/AddActions.sqf:6` (this is the one-shot wheel-repair file from audit V7 — confirmed unreachable, so V7's runtime impact is moot on master). |

Action: the "never compiled" and "compiled-but-never-called" groups are safe cleanup candidates (delete the file + its dead compile line), except the two ⚠️ AI-commander entries, which need owner confirmation of AI-commander dormancy first. The "commented-compile" group is revive-or-delete owner decision. No gameplay source changed by this documentation pass.

**Module/asset follow-up sweep (2026-06-07, second megapass — verified):**

| Item | Evidence |
| --- | --- |
| `Client/Module/MASH/receiverMASHmarker.sqf` | On docs/Miksuu/perf-shaped roots, the compile is commented at `Client/Init/Init_Client.sqf:132` (`:134` on current Miksuu) and there is no other maintained reference, so the client-side `WFBE_SE_MASH_MARKER_SENT` receiver PVEH is never installed. This is the **client** end of the MASH map-marker chain (distinct from the orphaned **server** `WFBE_CL_MASH_MARKER_CREATED` PVEH); both ends are dead on old-shape targets, matching [Deep-review findings](Deep-Review-Findings) DR-34. Current stable/B69/B74-shaped maintained roots have removed the deploy/module path instead. Restore the compile only as part of a full marker revival, or delete/archive as intentionally removed. |
| `Server/Module/serverFPS/monitorServerFPS.sqf` | Launched live at `Init_Server.sqf:599` (execVM) but the variable it broadcasts, `WFBE_VAR_SERVER_FPS`, has **no reader** in this mission — the RHUD FPS display reads `SERVER_FPS_GUI` from the parallel `Server/GUI/serverFpsGUI.sqf` (`Client_UpdateRHUD.sqf:113`). The Module variant is a no-op duplicate burning a scheduled thread every 8 s; the commented `WFBE_CO_FNC_monitorServerFPS` slots at `Init_Server.sqf:69,94` confirm it was superseded. Safe to remove the `:599` execVM + the file. (Formalizes the Round-42 note.) |

Unverified leads from this pass (the asset/condense/doc-gap verifiers largely failed to return — treat as candidates, source-confirm before acting): a reported ~25 dead `STR_*` stringtable keys (old briefing placeholders / removed-subsystem strings / a corrupted key), the already-flagged `WFBE_C_MODULE_BIS_HC` dead parameter, and a duplicate-IDD collision (likely the known DR-17/DR-25a dialog dups). Codex/owner follow-up.

Source-checked false positives from this pass:

- `Client/Module/Skill/Skill_Engineer.sqf`, `Skill_Salvage.sqf`, `Skill_Officer.sqf`, `Skill_LR.sqf`, `Skill_Sniper.sqf` and `Skill_SpecOps.sqf` are reached through dynamic `WFBE_SK_V_Root + '<Role>.sqf'` `addAction` paths in `Skill_Apply.sqf`. Do not classify them as dead from static path scans.
- `Server/Construction/Construction_HQSite.sqf`, `Construction_SmallSite.sqf` and `Construction_MediumSite.sqf` are selected through `WFBE_%1STRUCTURESCRIPTS` arrays and `RequestStructure.sqf`; they are live dynamic construction workers, not unreferenced files.
- ~~`AI_AddMultiplayerRespawnEH.sqf` looks unreferenced to the raw scan, but the non-vanilla advanced respawn path is already documented as a live branch.~~ **CORRECTED 2026-06-07 ([Deep-review findings](Deep-Review-Findings) DR-51, agent-team verified):** this was a false reassurance — `AI_AddMultiplayerRespawnEH.sqf` genuinely has **no call site** (no `addMPEventHandler` / `AI_AddMultiplayerRespawnEH` reference anywhere), so `AIAdvancedRespawn` (`Init_Server.sqf:12`) never attaches and is dead; the vanilla `AISquadRespawn` (`:11`) is gated by `WF_A2_Vanilla`, which `initJIPCompatible.sqf:91` sets `false` unconditionally (only `#ifdef VANILLA` flips it, and `VANILLA` is never defined), so it never spawns either. Both server AI-respawn paths are compiled-but-uncalled — see the SQF Reachability row below.
- `Action_ToggleMHQLock.sqf` looks unreferenced as a quoted path in some roots, but it is part of the live MHQ lock action/PVF authority surface and is already cited by the server authority map. Treat scanner output here as an addAction/dynamic-UI limitation.

## Integration And Tooling Findings

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `discordbot-fileconfiguration-dormant-status-path` | Stale but referenced helper | `FileConfiguration.cs:9-55` can read `botconfig.json`, but `GameData.LoadFromFile()` uses `Preferences.Instance.DataSourcePath` directly at `GameData.cs:36`; only `FileConfiguration.LogsPath` is used by live logging. | Choose one data-path source. Wire the status reader through `FileConfiguration.DataSourcePath` or delete/demote the `botconfig.json` data-path helper while preserving logging. |
| `discordbot-json-helper-dormant-unsafe` | Latent dangerous helper | Startup/timer/command paths call `GameData.LoadFromFile()` (`ProgramRuntime.cs:15`, `GameStatusUpdater.cs:84`, `CommandHandler.cs:211`), while public `HandleGameDataCreationOrLoading()` remains and uses `TypeNameHandling.Auto` at `GameDataDeSerialization.cs:32`. | Delete/private it or force `TypeNameHandling.None`; fixture-test hostile `$type` JSON if kept. |
| `extension-commented-deserialize-scaffold` | Disabled dangerous scaffold | Active extension writer uses `TypeNameHandling.None`, but commented `DeSerializeDB` / `HandleDatabaseCreationOrLoading` block uses `.Auto` and old persistence names (`SerializationManager.cs:79-124`). | Delete the commented scaffold or replace with safe DTO-only loader before any persistence revival. |
| `extension-and-discordbot-gamedata-arg-shape-drift` | Contract/test debt, misleading stale initializer/comments | `GlobalGameStats.sqf:22` sends five data fields after class selector; `GLOBALGAMESTATS.cs:5-11` still labels uptime/player count as future fields; Extension default array is length 2; DiscordBot default array is length 4, while live display code guards player count at index 4 (`GameData.cs:80-82`, `:111-114`) and uptime at index 3 (`:181-189`). | Define `database.json` once and align default arrays/comments plus short/normal/long/corrupt fixture tests. Treat the failure mode as display/fallback degradation on short or incompatible payloads; keep `TypeNameHandling` as the separate first security hardening path. |
| `discordbot-shared-loadoutmanager-write-api-stale` | Duplicated stale helper API | DiscordBot terrain `BaseTerrain.WriteToFile()` and `InterfaceTerrain.WriteToFile()` expose mission-writing APIs (`SharedWithLoadoutManager/.../BaseTerrain.cs:9-32`, `InterfaceTerrain.cs:5-6`), but static search found no bot caller; runtime only resolves terrain metadata for display/player cap (`GameData.cs:76-92`, `:108-124`, `:147-156`). Actual mission write/propagation belongs to `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs` and `Tools/LoadoutManager/FileManagement/FileManager.cs`. | Split display metadata from generator APIs or clearly mark copied/shared historical code; do not treat DiscordBot as a mission writer without a new explicit caller. |
| `discordbot-tasmania-metadata-stale` | Stale map metadata | DiscordBot has `TASMANIA2010`; current LoadoutManager `TerrainName` does not; upstream history records Tasmania removal after generated-map/version failures. | Confirm production cannot emit `TASMANIA2010`, then remove/archive DiscordBot metadata or keep it as legacy display-only fallback. |
| `battleye-afk-only-filter-footprint` | Misleading deployment-hardening footprint | Tracked BattlEye files are the README docx and `publicvariable.txt`; the filter contains only `5 "kickAFK"` and matches the AFK FSM broadcast. | Keep as AFK feature plumbing; do not claim broad public-server hardening without production `BEpath` evidence. |
| `loadoutmanager-dangerous-crv7pg-warning-used` | Misleading dangerous data, not dead | `WARNING_GAME_CRASH_DO_NOT_USE_IN_LOADOUTS_*` classes exist and `WILDCAT.cs:37` references one. | Do not delete as dead. Remove/replace the WILDCAT reference or make the generator fail on warning-marked loadouts, then smoke in Arma 2 OA. |

## Direct Public-Variable Findings

These are source-interpreted findings from the direct sender/receiver scan. The raw scan is intentionally conservative: it only records literal `publicVariable* "NAME"` and `"NAME" addPublicVariableEventHandler` lines. Dynamic channel names and variable-state broadcasts require human review.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `direct-pv-comment-only-legacy-channels` | Comment-only legacy direct PV | The scan found six direct `WFBE_*` channels only in comments: `WFBE_ChangeScore`, `WFBE_LocalizeMessage`, `WFBE_RequestSpecial`, `WFBE_RequestStructure`, `WFBE_RequestTeamUpdate`, `WFBE_RequestVehicleLock`. Example source rows sit beside `HandleSPVF`, `WFBE_CO_FNC_SendToServer`, `WFBE_CO_FNC_SendToClients` or PVF registrations in `Common/Init/Init_PublicVariables.sqf`. | Safe comment cleanup or annotation after branch-aware search. Keep the PVF registrations and helper calls. |
| `server-fps-dual-channel-drift` | Duplicate compatibility channel | `Server/GUI/serverFpsGUI.sqf:7` publishes `SERVER_FPS_GUI`; `Server/Module/serverFPS/monitorServerFPS.sqf:6` publishes `WFBE_VAR_SERVER_FPS`; source/Vanilla RHUD reads `SERVER_FPS_GUI`; Lingor modded RHUD still has a `WFBE_VAR_SERVER_FPS` wait/read path. | Treat `SERVER_FPS_GUI` as source/Vanilla UI contract. Consolidate only after modded/stale consumers are migrated or archived. |
| `icbm-launched-pveh-receiver-only` | Receiver-only legacy event handler | 2026-06-21 refresh: docs-branch source checks at `11f535d9` and `4c01dfb`, stable `origin/master@0139a346`, Miksuu `upstream/master@b8389e74` and `origin/perf/quick-wins@0076040f` all keep Chernarus plus maintained Vanilla `Client/FSM/updateclient.sqf:20` registering `"ICBM_launched" addPublicVariableEventHandler`, with receiver comments in `Client/Module/Nuke/OnEventHandler_ICBM_Launch.sqf:5,8-9`. Literal sender search found no `publicVariable "ICBM_launched"`, `publicVariableServer "ICBM_launched"` or active `ICBM_launched` assignment in those checked roots. The live nuke route uses `Client/Module/Nuke/nukeincoming.sqf:23,27`, `HandleSpecial` `"icbm-display"` and `Server_HandleSpecial` `case "ICBM"`; line drift is docs/perf `HandleSpecial.sqf:22` / `Server_HandleSpecial.sqf:97`, stable `:60` / `:117`, upstream `:24` / `:117`. `git ls-remote --heads origin release/*` returned no current release heads on 2026-06-21, so older release-branch mentions remain historical until that ref is restored. | Branch verification is current for the named refs. Do not delete ICBM. Either retire the stale `ICBM_launched` handler plus receiver comments, or revive it deliberately with one sender and one documented notification path, then smoke friendly/enemy warnings, markers and damage against the current nuke route. |

Source-checked false positives from this pass:

- `wfbe_supply_temp_east` and `wfbe_supply_temp_west` look receiver-only to the literal scan, but `Common_ChangeSideSupply.sqf:28-30` creates/sends them through `format ["wfbe_supply_temp_%1", _side]`.
- `kickAFK` looks sender-only because it is handled by the BattlEye `publicvariable.txt` filter rather than an SQF PVEH.
- HQ alive, HQ marker info, anti-stack compensation, team-no-player tick counters and similar sender-only rows are state broadcasts unless a later source pass proves no reader.
- `WFBE_PVF_%1` is the dynamic PVF registration pattern from `Init_PublicVariables.sqf`, not a literal runtime channel.

## UI And Rsc Findings

These are source-interpreted findings from the dialog/resource scan. The raw scan intentionally records broad UI leads; this section separates real mission-resource debt from engine-owned display IDs and comment-only residue.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `ui-duplicate-idd-collisions` | Duplicate misleading UI resource ID | In docs checkout `edbd341e` (source-unchanged from `b5219d47` for checked Dialogs/Titles IDD paths), `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000` (`Rsc/Dialogs.hpp:3209`, `:3211`, `:3287`, `:3289`) and both have live `createDialog` callers (`GUI_Menu_Service.sqf:244`, `GUI_Menu.sqf:172`). Current stable `0139a346`, B69 `8d465fce`, B74 `b23f557f` and historical `a96fdda2` split those dialog IDs in both maintained roots; Miksuu `b8389e748243` and perf `0076040f` still duplicate them. `RscOverlay` and `OptionsAvailable` both use `idd = 10200` everywhere checked (`Rsc/Titles.hpp:44`, `:46`, docs/Miksuu/perf `:164`, `:165`; stable/B69/B74/release line-drift to `:168`, `:169`) and both are used through `cutRsc` paths (`Init_Client.sqf:149`, `Client_UpdateRHUD.sqf:7`). No checked maintained root has a `findDisplay 23000/24000/10200` caller. | Do not delete any of these as dead. Treat as docs-ready UI parity cleanup or formal waiver through [UI resource parity cleanup](UI-Resource-Parity-Cleanup) and [UI IDD collision repair](UI-IDD-Collision-Repair): preserve or port stable/B69/B74/release dialog IDD split where target branches still duplicate `23000`, avoid introducing hard-coded IDD lookup assumptions, then smoke EASA, Economy, RHUD/FPS HUD, action icons and endgame stats. |
| `parameters-display-commented-22005-idc` | Comment-only stale IDC reference | `GUI_Display_Parameters.sqf:12` actively writes parameter rows to `22003`; `:16-19` contains a block-commented uptime write to missing `22005`; `RscDisplay_Parameters` declares the dialog and live controls around `Rsc/Dialogs.hpp:3133`, `:3136`, `:3173`, `:3180`. Branch check 2026-06-05: current source, maintained Vanilla, modded copies, `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle` keep the same comment-only uptime block and no `RscDisplay_Parameters` control `22005`; release Chernarus moved line numbers only (`Dialogs.hpp:2784`, `:2787`, `:2831`, `:2920`). | Docs-ready safe comment cleanup. Do not add `22005` unless the old uptime row is intentionally revived; the live Parameters dialog should keep rendering rows through `22003` and button controls through the existing resource. |

Source-checked false positives from this pass:

- IDC `101` in `WASP/global_marking_monitor.sqf` is a map/display control lead, not a missing mission `Rsc` declaration.
- IDC `116` in `Client/FSM/updateavailableactions.fsm` is an external/current display control lead, not a mission resource declaration gap.
- IDCs `112410`-`112414` in `Client/Module/UAV/uav_interface.sqf` belong to the UAV interface/display path and should be checked as BIS/UI integration IDs, not deleted as dead controls.
- IDC `22005` is comment-only in the parameters display across current source, stable/upstream, release and maintained/generated copies; it is not an active runtime write.

## Parameter And Config Findings

These are source-interpreted findings from the parameter/config scan. `Init_Parameters.sqf` imports every lobby `class Params` name into `missionNamespace`, so initialization alone does not prove gameplay use.

The actionable visible-parameter rows are already in [Current Findings](#current-findings) and the [Priority Backlog](#priority-backlog): `ai-max-visible-parameter-no-runtime-consumer` and `units-clean-timeout-visible-parameter-comment-only-consumer`. They are branch-split after the 2026-06-22 refresh: docs/perf/historical release refs keep the old dead/comment-only shape, while current stable/Miksuu maintained roots have live readers. Keep those IDs single-sourced there and route policy decisions through [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#parameter-cache-flow).

Source-checked false positives from this pass:

- `WFBE_C_ECONOMY_FUNDS_START_EAST`, `WFBE_C_ECONOMY_FUNDS_START_WEST`, `WFBE_C_ECONOMY_SUPPLY_START_EAST` and `WFBE_C_ECONOMY_SUPPLY_START_WEST` look readless in exact-name scan output, but server init/player-connect code reads them dynamically with `Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side]` and `Format ["WFBE_C_ECONOMY_SUPPLY_START_%1", _side]`.
- `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, `WFBE_C_MODULE_BIS_HC`, `WFBE_C_MODULE_WFBE_IRS`, hidden upgrade clearance and forced volumetric weather were already documented in the parameter/config owner pages. The parameter scan now gives repeatable evidence for those existing rows.

## Priority Backlog

| Priority | Work | Why |
| --- | --- | --- |
| P0 | Resolve or archive modded mission conflict markers before re-enabling modded packaging. | Raw merge markers are hard breakage if those missions are shipped. |
| P0 | Pick a policy for modded mission drift before using modded roots as implementation evidence. | The divergence scan shows runtime/PVF/UI/server files have forked across old modded roots while tooling no longer regenerates or packages them. |
| P0 | Keep OA compatibility scans clean before accepting hardening patches. | A patch that introduces A3-only APIs into SQF or integration glue can silently produce non-runnable mission code. |
| P0 | Fix/remove stale `RscMenu_Upgrade` consistently across maintained roots. | Branch verification is done and centralized in [UI resource parity cleanup](UI-Resource-Parity-Cleanup): docs/Miksuu/perf keep the missing-handler class in both maintained roots, while current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f`, historical release `a96fdda2` and historical upgrade-queue `b061c905` remove it in both maintained roots. The remaining work is old-shape target cleanup plus upgrade-menu smoke, not another broad discovery pass. |
| P1 | Decide MASH marker relay fate. | Branch verification is centralized in [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay): docs/source `HEAD@443055cf` is unchanged from `2b5139219faa` / `db3015f18ea3` for checked MASH paths, and docs/source, Miksuu `b8389e748243` and perf `0076040f8a5e` keep the server relay plus commented receiver while maintained deploy paths do not send the trigger PV; current stable `0139a3468609`, current B69 `8d465fce`, adjacent B74 `b23f557f` and historical `a96fdda2` remove the maintained-root deploy/module path. Older B69 refs `0a1ccb4d05c5` and `80d3267c1b2b` are provenance; current-B69 diffs from both contain no MASH-related hunks, and the checked B69..B74 MASH delta is empty. Modded `eden`/`lingor` sender lines are drift, not proof the maintained relay works. |
| P1 | Keep `AIBuyUnit` latent until AI commander production is intentionally merged or retired. | It is dead-looking on stable but valuable for AI commander work. |
| P1 | Fix economy menu IDC `23004/23005/23006` parity. | Branch verification is done and centralized in [UI resource parity cleanup](UI-Resource-Parity-Cleanup): docs/source `HEAD@21f0d53b`, current Miksuu `b8389e748243` and perf `0076040f` keep stale disabled-state writes in both maintained roots, while current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f` and historical release `a96fdda2` rewrite the controller around dashboard `23020` in both maintained roots. The remaining work is old-shape target UI parity cleanup plus Economy smoke, not another broad audit. |
| P1 | Fix or formally waive duplicate UI IDDs `23000` and `10200`. | Branch verification is done and centralized in [UI resource parity cleanup](UI-Resource-Parity-Cleanup): docs/source `HEAD@edbd341e`, current Miksuu `b8389e748243` and perf `0076040f` still duplicate EASA/Economy `23000`; current stable `origin/master@0139a346`, B69 `8d465fce`, B74 `b23f557f` and historical `a96fdda2` split those dialog IDs in both maintained roots; and title resources still share `10200` everywhere checked. No checked maintained root has a `findDisplay 23000/24000/10200` caller, so remaining work is target-branch UI parity cleanup or explicit waiver plus smoke. |
| P1 | Keep visible AI/cleanup parameters branch-scoped. | Branch verification is centralized in [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs): docs/current-Miksuu/perf/historical release refs still keep `WFBE_C_AI_MAX` readless and `WFBE_C_UNITS_CLEAN_TIMEOUT` comment-only, while current stable `origin/master@0139a346` has maintained-root live readers for both. Remaining work is target-specific policy, port/hide decisions for old-shape refs, and host-parameter plus AI commander/body/wreck/empty-vehicle smoke, not another broad parameter audit. |
| P1 | Clean integration dead/stale helpers before expanding Discord/status tooling. | Dormant `.Auto` JSON helpers, stale `botconfig.json` ownership and arg-shape drift are easy to revive incorrectly. |
| P1 | Decide whether warning-marked CRV7PG loadouts are forbidden or intentionally quarantined. | A warning-named crash-risk class is referenced by WILDCAT data, so generator output may carry known-dangerous loadouts. |
| P1 | Decide whether the stale `ICBM_launched` PVEH should be retired or revived. | Branch verification is current for docs head `4c01dfb`, stable `origin/master@0139a346`, Miksuu `upstream/master@b8389e74` and `origin/perf/quick-wins@0076040f`: Chernarus plus maintained Vanilla keep the receiver-only handler and no active sender was found. The current nuke path uses `NukeIncoming`, `RequestSpecial "ICBM"` and `HandleSpecial "icbm-display"`. Current origin exposes no `release/*` heads on 2026-06-21, so old release-row wording is not current-ref proof. Remaining work is an owner decision plus ICBM smoke, not another broad PV audit. |
| P1 | Decide whether dormant SQF helper families are archive, revive or tooling-owned: `UpdateSupplyTruck`, `groupsMonitor`, `Common_ModifyAirVehicle`, `HandleATReloadVehicle`, IRS warning helpers, Reaktiv and TaskSystem. | They are source-backed stale code, but several have branch, tooling or modded context that makes blind deletion risky. |
| P1 | Use the asset/media/bootstrap scan before terrain release claims. | It now distinguishes maintained roots, modded roots, missing bootstrap files, addon paths and map-conditional false positives. |
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
| MASH marker relay | Useful player-facing map state around mobile respawn, but currently orphaned only on docs/Miksuu/perf-shaped maintained roots; current stable/current-B69/B74-shaped roots have removed the maintained deploy/module path. | Sender, server relay, client receiver, marker delete/JIP resend behavior and PV channel docs must be made coherent on old-shape targets, or the stale relay should be retired/archived. Use the canonical MASH split in [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay). |
| `AIBuyUnit` / `Server_BuyUnit.sqf` | Likely needed by AI commander production branches. | AI production scheduler, funds/cap policy, queue cleanup and Client_BuildUnit drift review. |
| Old marker blinking loop | Old docs/Miksuu/perf comments could be useful only if map marker ownership is redesigned; current stable and historical release already removed the old plural/server-map comment residue while keeping singular combat blinking. | Must not regress current singular `Client_BlinkMapIcon` behavior or confuse it with the retired plural loop. |
| `ICBM_launched` PVEH | Could be revived as a clear client notification channel for tactical nukes, but it is receiver-only in maintained current docs head `4c01dfb`, stable `origin/master@0139a346`, Miksuu `upstream/master@b8389e74` and `origin/perf/quick-wins@0076040f` checks. Current origin exposes no `release/*` heads on 2026-06-21. | Must be reconciled with the current `NukeIncoming` / `RequestSpecial "ICBM"` / `HandleSpecial "icbm-display"` path and smoke-tested for friendly/enemy warnings, markers and damage. If retired, remove the handler and stale receiver comments together. |
| AI supply-truck logistics | The script and config-gated spawn show an abandoned autonomous economy idea. | Needs a new server-owned logistics design; the old missing FSM cannot be restored by uncommenting one compile. |
| Reaktiv ERA armor | The module is self-contained enough to inspect and could add vehicle survivability tuning, but it is unreachable where present. Docs/source, Miksuu `b8389e74` and `perf/quick-wins` `0076040f` still carry maintained-root copies with no init call; stable `origin/master` `cf2a6d6a` and release `a96fdda2` remove maintained-root copies, while modded Napf/Eden/Lingor copies remain stale. | Must be wired in deliberately, checked against existing IRS/CM/inline rearmor handlers and smoke-tested for HandleDamage locality; otherwise archive/remove remaining maintained-root copies and handle stale modded copies under the modded mission policy. |
| TaskSystem / commander task assignment | Docs/Miksuu/perf keep old town TaskSystem helper files plus commented calls. Current stable `origin/master@0139a346` keeps only comment residue while the helper file is absent, and its commander Tasks tab sends Objective Ping in both maintained roots. Historical `a96fdda2` keeps the old helper plus the Objective Ping sends. | Keep the concepts separate: old town tasks need a fresh JIP-safe design or comment cleanup, while Objective Ping needs OA menu smoke, target/audience validation and spam controls before promotion. |
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

Run the mission-copy divergence scan:

```powershell
.\docs\analysis\dead-code-mission-copy-divergence-scan.ps1
```

Run the Arma 2 OA compatibility / Arma 3-style API scan. Use PowerShell 7 (`pwsh`); Windows PowerShell 5.1 lacks the `System.IO.Path.GetRelativePath` API used by this scanner.

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\docs\analysis\dead-code-oa-compatibility-scan.ps1
```

Run the asset/media/bootstrap scan:

```powershell
.\docs\analysis\dead-code-asset-reference-scan.ps1
```

Validate the machine-readable register:

```powershell
Get-Content .\docs\analysis\dead-code-findings.jsonl | ForEach-Object { $_ | ConvertFrom-Json | Out-Null }
Get-Content .\docs\analysis\dead-code-integration-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-pv-channel-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-ui-rsc-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-parameter-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-sqf-reachability-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-mission-copy-divergence-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-oa-compatibility-scan.json | ConvertFrom-Json | Out-Null
Get-Content .\docs\analysis\dead-code-asset-reference-scan.json | ConvertFrom-Json | Out-Null
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
rg -n "Warfare WASP-AWESOME EDITION|SET_MAP|WF_MAXPLAYERS|WF_MISSIONNAME|EAST_StartVeh|WEST_StartVeh" Missions Missions_Vanilla
rg -n "remoteExec|remoteExecCall|BIS_fnc_MP|addMissionEventHandler|isRemoteExecuted|remoteExecutedOwner|parseSimpleArray|RVExtensionArgs|CfgFunctions|isEqualTo|\bparams\s*\[|\bapply\s*\{|\bpushBack\b|\ballPlayers\b|getUnitLoadout|setUnitLoadout|createSimpleObject|setGroupOwner|groupOwner" Missions Missions_Vanilla Modded_Missions Tools DiscordBot Extension BattlEyeFilter
```

## Related Pages

- [Feature status](Feature-Status-Register)
- [Source fix propagation queue](Source-Fix-Propagation-Queue)
- [Content structure and maps](Content-Structure-And-Maps)
- [Tools and build workflow](Tools-And-Build-Workflow)
- [Client UI systems atlas](Client-UI-Systems-Atlas)
- [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas)
- [AI commander autonomy audit](AI-Commander-Autonomy-Audit)
- [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit)

## Continue Reading

Previous: [Wiki pruning and relevance ledger](Wiki-Pruning-And-Relevance-Ledger) | Next: [Source fix propagation queue](Source-Fix-Propagation-Queue)

Main map: [Home](Home) | Status: [Progress dashboard](Progress-Dashboard) | Core findings: `docs/analysis/dead-code-findings.jsonl` | Scan artifacts: `docs/analysis/dead-code-*.json`
