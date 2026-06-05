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
| `old-map-blink-loop-missing-files` | Retired commented reference | `Client/Init/Init_Client.sqf:138`, `:140`, `:782` reference missing plural blink/add-track files; `:139` compiles the live singular `Client_BlinkMapIcon.sqf`. | Safe comment cleanup only. Keep the singular blink helper. |
| `server-map-blinking-units-commented-missing` | Retired commented reference | `Server/Init/Init_Server.sqf:593` comments an exec for missing `Server_MapBlinkingUnits.sqf`. | Treat as retired unless marker authority is redesigned. |
| `stale-rscmenu-upgrade-missing-onload` | Broken stale UI class | `Rsc/Dialogs.hpp:2425`, `:2428` keep `RscMenu_Upgrade` with missing `Client/GUI/GUI_Menu_Upgrade.sqf`; the UI/Rsc scan confirms this is the only `RscMenu_*` class without literal `createDialog` calls and the handler target is missing across source, Vanilla and modded copies. Branch check: `origin/master`, `miksuu/master` and docs/source still carry the stale class in Chernarus and maintained Vanilla; `origin/release/2026-06-feature-bundle` removed Chernarus through `460c0312` but still leaves the Vanilla class. | Branch search is complete for the maintained heads. Code owner should either apply the release Chernarus deletion consistently to current source plus maintained Vanilla, or replace the old class with an explicit compatibility alias to `WFBE_UpgradeMenu`; do not recreate missing `GUI_Menu_Upgrade.sqf` or `wf_*.paa` art blindly. Canonical lane: [UI resource parity cleanup](UI-Resource-Parity-Cleanup). |
| `main-menu-gps-orphan-actions` | Dormant UI router cases | Source Chernarus and maintained Vanilla handle `MenuAction == 17/18` in `Client/GUI/GUI_Menu.sqf:202-208`; `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle` keep the same handler shape in Chernarus plus Vanilla. Fixed-string action searches found no `MenuAction = 17` or `MenuAction = 18` emitters in maintained roots; current `WF_Menu` controls expose actions `1-13`, `16` and `19`. | Docs-ready low-risk UI cleanup. Either remove/comment the dormant GPS zoom router cases across maintained roots, or reintroduce intentional controls and smoke GPS zoom without overlapping existing main-menu action ids. |
| `mash-marker-relay-orphaned` | Orphaned partial feature | Server compiles `MASHMarker.sqf`; client receiver compile is commented at `Client/Init/Init_Client.sqf:132`; sender/receiver PV channels do not form a maintained Chernarus loop. | Decide retire vs revive. MASH tents are not dead; local MASH respawn is source-supported. Canonical matrix: [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay). |
| `latent-aibuyunit-server-buy-worker` | Latent revive candidate | `Server/Init/Init_Server.sqf:10` compiles `AIBuyUnit`, but stable source search finds no caller; `Server_BuyUnit.sqf` is an AI/team worker. | Do not delete casually. Needed if AI commander production is revived. |
| `modded-mission-conflict-markers` | Broken modded mission sources | 18 files under `Modded_Missions` contain real `<<<<<<<`, `=======`, `>>>>>>>` markers; the mission-copy divergence scan groups them into 17 mission-relative paths, including Eden `Skill_Apply.sqf`, Lingor `Client_UpdateRHUD.sqf`, Napf `description.ext` and multiple root/config files. | Resolve before any modded release. Do not blindly delete sections. |
| `unitcaching-commented-absent-scaffold` | Retired commented reference | `description.ext:37` comments `scripts\unitCaching\description.ext`; the folder is absent. | Safe comment cleanup or keep as abandoned optimization note. |
| `common-handlebombs-commented-missing` | Retired commented reference | `Common/Init/Init_Common.sqf:11` comments missing `Common_HandleBombs.sqf`. | Safe comment cleanup; live IRS/missile systems are separate. |
| `legacy-config-defenses-commented-missing` | Retired commented reference | Defense files call live `Config_Defenses_Towns.sqf` and retain commented old `Config_Defenses.sqf` calls. | Safe comment cleanup after branch search. |
| `wasp-commented-action-scaffolds` | Retired commented reference, narrow scope | `WASP/Init_Client.sqf:7`, `:12`, `:21` point at missing old action/key scripts; adjacent WASP action helpers still have uses. | Clean only commented missing hooks unless a full WASP action inventory proves more. |
| `bis-hc-parameter-orphan` | Orphan-looking config | `Rsc/Parameters.hpp:381` exposes `WFBE_C_MODULE_BIS_HC`; HC delegation uses `WFBE_C_AI_DELEGATION`. | Hide/remove or wire a real BIS High Command feature; do not label it as headless-client enablement. |
| `ai-max-visible-parameter-no-runtime-consumer` | Visible parameter with no runtime consumer | `Rsc/Parameters.hpp:56-60` exposes `WFBE_C_AI_MAX`; `Init_CommonConstants.sqf:92` defaults it; branch check 2026-06-05 found no active runtime consumer in current source/Vanilla, `origin/master`, `miksuu/master` or release beyond parameter/default paths. Player follower caps use `WFBE_C_PLAYERS_AI_MAX` instead. | Do not use this for player cap answers. Wire it to real AI-team sizing, hide/remove it, or label it historical. Canonical route: [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#parameter-cache-flow). |
| `units-clean-timeout-visible-parameter-comment-only-consumer` | Visible parameter with comment-only consumer | `Rsc/Parameters.hpp:242-246` exposes `WFBE_C_UNITS_CLEAN_TIMEOUT`; constants default it at `Init_CommonConstants.sqf:348`; branch check 2026-06-05 found live trash cleanup reads `WFBE_C_UNITS_BODIES_TIMEOUT` at `Common_TrashObject.sqf:19` and only mentions `WFBE_C_UNITS_CLEAN_TIMEOUT` in a commented old split line at `:20`; empty vehicles use `WFBE_C_UNITS_EMPTY_TIMEOUT` in `Server_HandleEmptyVehicle.sqf:12,18` across checked maintained roots/branches. | Decide whether the lobby row should drive body timeout, revive the old man/non-man split, or be removed/renamed. Keep empty vehicle cleanup separate. Canonical route: [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#parameter-cache-flow). |
| `economy-menu-missing-control-writes` | Stale UI control writes | Current source/stable/upstream `GUI_Menu_Economy.sqf:7-8` writes IDC `23004/23005/23006`; audited `RscMenu_Economy` declares `23002/23003` then `23008+`. Branch check 2026-06-05: release Chernarus no longer has the stale writes and adds dashboard IDC `23020`, while release Vanilla still carries `23004/23005/23006`. Modded roots still mirror the old stale-write shape. | Docs-ready parity cleanup. Compare/import the Chernarus release shape or remove/update stale writes consistently across maintained roots; smoke Economy disabled state, income controls, sell mode and supply-truck respawn. Canonical lane: [UI resource parity cleanup](UI-Resource-Parity-Cleanup). |
| `modded-missing-camp-helper-files` | Broken modded source reference | Modded `Init_Common.sqf` files compile `Common_GetTotalCamps*.sqf`; scan reports missing helpers in modded roots. | Restore from current source or regenerate modded missions before release. |
| `generated-version-sqf-clean-checkout-risk` | Generated-file contract risk | Mission entrypoints include `version.sqf`; LoadoutManager generates/excludes it. | Keep includes; validate generation workflow on clean checkout. |
| `rsc-clickabletext-soundpush-malformed` | Stale or malformed resource config | `Rsc/Ressources.hpp:556` has `soundPush[] = {, 0.2, 1};` in source Chernarus, maintained Vanilla, stable/upstream, `perf/quick-wins`, release and UI theme branches; `Ressources.hpp:92` shows the valid empty-sound precedent `{"", 0.2, 1}`. | Use [Client UI systems](Client-UI-Systems-Atlas#clickable-text-soundpush-branch-matrix); replace with a valid value only after config/dialog smoke scope is named. |
| `modded-packaging-disabled-by-tooling` | Deferred release scope | `Tools/LoadoutManager/ZipManager.cs:16` packages `Missions` and `Missions_Vanilla`; `SqfFileGenerator.cs:133` says add modded maps later. | Keep disabled until conflict/missing-reference checks pass, or archive old modded roots. |

## Asset And Bootstrap Findings

These findings are source-interpreted from the asset/media/bootstrap scan. They supplement [Assets/config/localization/parameters](Assets-Config-Localization-And-Parameters-Atlas) and the modded mission map table in [Content structure and maps](Content-Structure-And-Maps).

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `asset-scan-repeatable-release-gate` | Asset/bootstrap release risk | The scan found 5860 path/reference records across 2774 mission-root text files, 3896 resolved references, 583 external addon references and 21 missing bootstrap files. All missing bootstrap files are in `Modded_Missions`, matching the existing packaging quarantine: several roots lack `description.ext`, `mission.sqm`, `initJIPCompatible.sqf` and/or generated `version.sqf`. | Use the scanner as a release gate before claiming any terrain root is pack/test-ready. Keep modded roots quarantined until generated or explicitly maintained. |
| `rscmenu-upgrade-icons-missing-assets` | Broken stale UI class | Source and maintained Vanilla `Rsc/Dialogs.hpp:2425-2428` point `RscMenu_Upgrade` at missing `Client\GUI\GUI_Menu_Upgrade.sqf`; the same stale block references missing `Client\Images\wf_*.paa` icons at `Dialogs.hpp:2634-2821`. Live upgrade flow uses `WFBE_UpgradeMenu` / `Client\GUI\GUI_UpgradeMenu.sqf`. Release branch Chernarus no longer has the old block, but release Vanilla still does. | Treat the old dialog as stale. Prefer removing/aliasing the old resource across maintained roots instead of recreating unused art blindly; if importing the release deletion, verify Vanilla parity through [UI resource parity cleanup](UI-Resource-Parity-Cleanup). |
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
| `icbm-launched-pveh-receiver-only` | Receiver-only legacy event handler | Source/Vanilla `Client/FSM/updateclient.sqf:20` registers `"ICBM_launched" addPublicVariableEventHandler`, and the same receiver-only shape is present in `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle`. No active assignment or `publicVariable "ICBM_launched"` sender was found. Current tactical nuke flow spawns `NukeIncoming`, sends `RequestSpecial` `"ICBM"` to the server, and broadcasts `HandleSpecial` `"icbm-display"` to clients. | Branch verification is done. Do not delete ICBM. Either retire the stale `ICBM_launched` handler/receiver docs or revive it deliberately with one sender and one documented notification path. |

Source-checked false positives from this pass:

- `wfbe_supply_temp_east` and `wfbe_supply_temp_west` look receiver-only to the literal scan, but `Common_ChangeSideSupply.sqf:28-30` creates/sends them through `format ["wfbe_supply_temp_%1", _side]`.
- `kickAFK` looks sender-only because it is handled by the BattlEye `publicvariable.txt` filter rather than an SQF PVEH.
- HQ alive, HQ marker info, anti-stack compensation, team-no-player tick counters and similar sender-only rows are state broadcasts unless a later source pass proves no reader.
- `WFBE_PVF_%1` is the dynamic PVF registration pattern from `Init_PublicVariables.sqf`, not a literal runtime channel.

## UI And Rsc Findings

These are source-interpreted findings from the dialog/resource scan. The raw scan intentionally records broad UI leads; this section separates real mission-resource debt from engine-owned display IDs and comment-only residue.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `ui-duplicate-idd-collisions` | Duplicate misleading UI resource ID | `RscMenu_EASA` and `RscMenu_Economy` both use `idd = 23000` (`Rsc/Dialogs.hpp:3209`, `:3211`, `:3287`, `:3289`) and both have live `createDialog` callers (`GUI_Menu_Service.sqf:244`, `GUI_Menu.sqf:172`). `RscOverlay` and `OptionsAvailable` both use `idd = 10200` (`Rsc/Titles.hpp:44`, `:46`, `:164`, `:165`) and both are used through `cutRsc` paths (`Init_Client.sqf:149`, `Client_UpdateRHUD.sqf:7`). Branch check 2026-06-05: source/stable/upstream keep both collisions in Chernarus and Vanilla; release Chernarus changes EASA to `24000` but release Vanilla still duplicates `23000`, and release titles still duplicate `10200`. No current source `findDisplay 23000/10200` caller was found. | Do not delete any of these as dead. Treat as docs-ready UI parity cleanup or formal waiver through [UI resource parity cleanup](UI-Resource-Parity-Cleanup) and [UI IDD collision repair](UI-IDD-Collision-Repair): assign unique IDDs only in a UI cleanup branch, avoid introducing hard-coded IDD lookup assumptions, then smoke EASA, Economy, RHUD/FPS HUD, action icons and endgame stats. |
| `parameters-display-commented-22005-idc` | Comment-only stale IDC reference | `GUI_Display_Parameters.sqf:12` actively writes parameter rows to `22003`; `:16-19` contains a block-commented uptime write to missing `22005`; `RscDisplay_Parameters` declares the dialog and live controls around `Rsc/Dialogs.hpp:3133`, `:3136`, `:3173`, `:3180`. Branch check 2026-06-05: current source, maintained Vanilla, modded copies, `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle` keep the same comment-only uptime block and no `RscDisplay_Parameters` control `22005`; release Chernarus moved line numbers only (`Dialogs.hpp:2784`, `:2787`, `:2831`, `:2920`). | Docs-ready safe comment cleanup. Do not add `22005` unless the old uptime row is intentionally revived; the live Parameters dialog should keep rendering rows through `22003` and button controls through the existing resource. |

Source-checked false positives from this pass:

- IDC `101` in `WASP/global_marking_monitor.sqf` is a map/display control lead, not a missing mission `Rsc` declaration.
- IDC `116` in `Client/FSM/updateavailableactions.fsm` is an external/current display control lead, not a mission resource declaration gap.
- IDCs `112410`-`112414` in `Client/Module/UAV/uav_interface.sqf` belong to the UAV interface/display path and should be checked as BIS/UI integration IDs, not deleted as dead controls.
- IDC `22005` is comment-only in the parameters display across current source, stable/upstream, release and maintained/generated copies; it is not an active runtime write.

## Parameter And Config Findings

These are source-interpreted findings from the parameter/config scan. `Init_Parameters.sqf` imports every lobby `class Params` name into `missionNamespace`, so initialization alone does not prove gameplay use.

| ID | Classification | Evidence | Action |
| --- | --- | --- | --- |
| `ai-max-visible-parameter-no-runtime-consumer` | Visible parameter with no runtime consumer | `WFBE_C_AI_MAX` is visible/defaulted, but branch check 2026-06-05 found no active maintained-root runtime consumer outside parameter/default files across current source/Vanilla, stable, Miksuu upstream and release. Current buy-menu/RHUD/Soldier behavior uses `WFBE_C_PLAYERS_AI_MAX` instead (`GUI_Menu_BuyUnits.sqf:37`, `Client_UpdateRHUD.sqf:312`, `Skill_Init.sqf:49`). | Do not use `WFBE_C_AI_MAX` in player-cap answers. Wire it to real AI-team sizing, hide/remove it, or mark it historical. Canonical route: [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs). |
| `units-clean-timeout-visible-parameter-comment-only-consumer` | Visible parameter with comment-only consumer | `WFBE_C_UNITS_CLEAN_TIMEOUT` is visible/defaulted, but branch check 2026-06-05 found live cleanup uses `WFBE_C_UNITS_BODIES_TIMEOUT` at `Common_TrashObject.sqf:19`; the `WFBE_C_UNITS_CLEAN_TIMEOUT` split remains only in the commented line at `:20`. Empty vehicles use `WFBE_C_UNITS_EMPTY_TIMEOUT` via `Server_HandleEmptyVehicle.sqf:12,18`. | Decide whether the lobby body-timeout row should drive body cleanup, revive the old man/non-man split, or be removed/renamed. Canonical route: [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs). |

Source-checked false positives from this pass:

- `WFBE_C_ECONOMY_FUNDS_START_EAST`, `WFBE_C_ECONOMY_FUNDS_START_WEST`, `WFBE_C_ECONOMY_SUPPLY_START_EAST` and `WFBE_C_ECONOMY_SUPPLY_START_WEST` look readless in exact-name scan output, but server init/player-connect code reads them dynamically with `Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side]` and `Format ["WFBE_C_ECONOMY_SUPPLY_START_%1", _side]`.
- `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, `WFBE_C_MODULE_BIS_HC`, `WFBE_C_MODULE_WFBE_IRS`, hidden upgrade clearance and forced volumetric weather were already documented in the parameter/config owner pages. The parameter scan now gives repeatable evidence for those existing rows.

## Priority Backlog

| Priority | Work | Why |
| --- | --- | --- |
| P0 | Resolve or archive modded mission conflict markers before re-enabling modded packaging. | Raw merge markers are hard breakage if those missions are shipped. |
| P0 | Pick a policy for modded mission drift before using modded roots as implementation evidence. | The divergence scan shows runtime/PVF/UI/server files have forked across old modded roots while tooling no longer regenerates or packages them. |
| P0 | Keep OA compatibility scans clean before accepting hardening patches. | A patch that introduces A3-only APIs into SQF or integration glue can silently produce non-runnable mission code. |
| P0 | Fix/remove stale `RscMenu_Upgrade` consistently across maintained roots. | Branch verification is done and centralized in [UI resource parity cleanup](UI-Resource-Parity-Cleanup): current source/stable/upstream keep the missing-handler class in Chernarus and Vanilla, while release Chernarus removed it and release Vanilla did not. The remaining work is a code-owner cleanup plus upgrade-menu smoke, not another broad discovery pass. |
| P1 | Decide MASH marker relay fate. | Branch verification is done and centralized in [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay): current source/Vanilla, stable, Miksuu upstream and release all keep the server relay plus commented receiver while maintained deploy paths do not send the trigger PV. Modded `eden`/`lingor` sender lines are drift, not proof the maintained relay works. |
| P1 | Keep `AIBuyUnit` latent until AI commander production is intentionally merged or retired. | It is dead-looking on stable but valuable for AI commander work. |
| P1 | Fix economy menu IDC `23004/23005/23006` parity. | Branch verification is done and centralized in [UI resource parity cleanup](UI-Resource-Parity-Cleanup): current source/stable/upstream keep stale disabled-state writes in Chernarus and Vanilla; release Chernarus removed/rewrote them around dashboard `23020`, but release Vanilla did not. The remaining work is a code-owner UI parity cleanup plus Economy smoke, not another broad audit. |
| P1 | Fix or formally waive duplicate UI IDDs `23000` and `10200`. | Branch verification is done and centralized in [UI resource parity cleanup](UI-Resource-Parity-Cleanup): current source/stable/upstream keep both collision groups, release Chernarus partially fixes the EASA/Economy dialog collision, release Vanilla does not, and release title resources still share `10200`. No current source `findDisplay 23000/10200` caller was found, so remaining work is a code-owner UI parity cleanup or explicit waiver plus smoke. |
| P1 | Decide the fate of visible dead/misleading parameters `WFBE_C_AI_MAX` and `WFBE_C_UNITS_CLEAN_TIMEOUT`. | Branch verification is done and centralized in [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs): current source/Vanilla, stable, Miksuu upstream and release keep `WFBE_C_AI_MAX` with no active maintained-root runtime reader and keep `WFBE_C_UNITS_CLEAN_TIMEOUT` as comment-only cleanup residue. Remaining work is a code-owner parameter policy/cleanup plus host-parameter and cleanup smoke, not another broad parameter audit. |
| P1 | Clean integration dead/stale helpers before expanding Discord/status tooling. | Dormant `.Auto` JSON helpers, stale `botconfig.json` ownership and arg-shape drift are easy to revive incorrectly. |
| P1 | Decide whether warning-marked CRV7PG loadouts are forbidden or intentionally quarantined. | A warning-named crash-risk class is referenced by WILDCAT data, so generator output may carry known-dangerous loadouts. |
| P1 | Decide whether the stale `ICBM_launched` PVEH should be retired or revived. | Branch verification is done: current source/Vanilla, stable/upstream and release all keep the receiver-only handler and no active sender was found. The current nuke path uses `NukeIncoming` and `HandleSpecial "icbm-display"`; remaining work is an owner decision plus ICBM smoke, not another broad PV audit. |
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
| MASH marker relay | Useful player-facing map state around mobile respawn, but currently orphaned in maintained source, stable, upstream and release. | Sender, server relay, client receiver, marker delete/JIP behavior and PV channel docs must be made coherent, or the stale relay should be retired/archived. Use the canonical MASH split in [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay). |
| `AIBuyUnit` / `Server_BuyUnit.sqf` | Likely needed by AI commander production branches. | AI production scheduler, funds/cap policy, queue cleanup and Client_BuildUnit drift review. |
| Old marker blinking loop | Could be useful if map marker ownership is redesigned. | Must not regress current singular `Client_BlinkMapIcon` behavior. |
| `ICBM_launched` PVEH | Could be revived as a clear client notification channel for tactical nukes, but it is receiver-only in maintained current/stable/upstream/release checks. | Must be reconciled with the current `NukeIncoming` / `RequestSpecial` / `HandleSpecial "icbm-display"` path and smoke-tested for friendly/enemy warnings, markers and damage. If retired, remove the handler and stale receiver comments together. |
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
