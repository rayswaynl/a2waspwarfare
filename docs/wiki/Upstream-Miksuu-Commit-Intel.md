# Upstream Miksuu Commit Intel

This page indexes source-backed upstream history from `Miksuu/a2waspwarfare` for documentation and future implementation planning. It is intentionally evidence-first: use it to find proven developer intent, then re-check current source before patching.

Research snapshot: upstream `master` at `8bcc42b1` (2026-06-02), GitHub PRs #1-#12, branch list from GitHub, and local fetched upstream refs.

## PR Ledger

| PR | State | Merge / head evidence | Developer-intent clue | Lesson |
| --- | --- | --- | --- | --- |
| #1 `Merge separated codebases` | Closed unmerged | head `MergeWithMiksuu`; body calls it a huge merge between separated codebases. | Large merge shape was not accepted. | Avoid wholesale branch imports; split current-source patches. |
| #2 `Merge separated codebases (with correct folder structure)` | Closed unmerged | head `MergeWithMiksuu`, base `MergeFromEzcoo`. | Folder-structure correction still did not land. | Repo layout and mission-copy shape matter as much as code content. |
| #3 `Add increasing cost of repairing HQ` | Merged | merge `fbf988ed` into `v25102023`. | Early economy/repair-cost tuning. | Repair/economy changes belong in balance + authority review. |
| #4 `Spawn new players on the latest built factory` | Merged | merge `e649beae`. | Spawn placement was feature-worthy enough to isolate. | Spawn/JIP behavior deserves dedicated tests. |
| #5 `Add supply runs (Support class)` | Merged | merge `26f9fa3e`; files include `Client/Module/supplyMission/*`, `Server/Module/supplyMission/*`, side-supply functions and town init. | Supply runs landed as a broad client/server/economy feature. | Treat supply as cross-cutting, not a client action only. |
| #6 `Buy Units menu improvements` | Merged | merge `4e248dff`; title mentions hints and disabling driver slot by default. | UI affordance and AI driver behavior were coupled. | Buy-menu UX changes can alter AI/runtime defaults. |
| #7 `Commander assist hint after vote` | Merged | merge `7b55e7b7` recorded by GitHub; files include commander/endgame UI and sound resources. | Commander UX needed post-vote guidance. | Commander flows need clear feedback, but authority remains server-side. |
| #8 `Merge countdown kick` | Merged | merge `657dbe44`; commit `deed0184` increases countdown kick to 2 minutes. | Intro/welcome timing affected kick behavior. | Timing constants should be tested with intro/JIP flow. |
| #9 `Add endgame music` | Closed unmerged | head `MergeToEzcooV3`; files include endgame music/sound changes. | Media/UI change was not merged as that PR. | Closed feature PRs are not current behavior. |
| #10 `Supply run remote activation glitch fix` | Merged | merge `97dfff26`; PR body names remote truck/remote CC exploit. | Supply run exploit was real and player-facing. | Server-side validation is required for economy-bearing supply actions. |
| #11 `Add "supply truck too far" notification` | Merged | merge `8164cc33`; commit `86c8f89c`; Chernarus + Vanilla file changed. | UX feedback followed exploit guard. | Add feedback, but check JIP and spawn contexts. |
| #12 `Fix "supply truck too far" notification being run during JIP` | Merged | merge `86ec28d6`; commit `b76f9645`; PR body calls the fix "a bit hacky". | The PR #11 UX guard regressed JIP spawn. | Any action-condition notification needs late-join smoke. |

## Commit Clusters

### Supply Missions And Economy

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `d086863c` "Add supply mission (still missing mission.sqm class descriptions)" | supply mission client/server modules | Initial supply run work landed before all mission metadata was complete. |
| `65fa3332` "Fix remote supply truck glitch" and `0542edf8` "Improve reliability of supply truck detection" | `Client/Module/supplyMission/supplyMissionStart.sqf` in Chernarus and Vanilla | Client-side start detection was exploit-sensitive and needed follow-up reliability changes. |
| `b76f9645` "Fix 'supply truck too far' notification being run during JIP" | same start file | UX checks can accidentally fire during spawn/JIP lifecycle. |
| `db317706` "Player is not defined on server -> move reward fnc call to client" | supply completion message/server active file | Server/client identity assumptions caused a reward-flow correction. |
| `6861e310` "Add score for supply run only to the player having completed it" | `supplyMissionCompletedMessage.sqf` | Reward targeting needed correction to avoid broad awards. |
| `87cef74b`, `78d86810`, `994150da` | supply amount modifiers/upgrades/Takistan | Supply reward math changed over time and had to be propagated. |

### JIP / Client Lifecycle

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `b02782f1` "Move main logic of heavy attack mode to server to avoid JIP issues" | `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `updateclient.sqf` | Server-owned main logic was chosen after JIP complexity emerged. |
| `a9044821` "Refactor logic of JIP during heavy attack feature" | `Init_Client.sqf`, `Server_OnPlayerConnected.sqf`, `AttackWave.sqf` | Join flow needed explicit wiring for active attack waves. |
| `6eb09dc3` "Make JIP players spawn at HQ or factories only" | client lifecycle/spawn paths | Spawn behavior was tightened for late joiners. |

### Performance And Town AI

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `88e0749a`, `ff1ea838`, `62becdda`, `49aa1e53` | performance audit/analyzer | Diagnostics preceded major performance work. |
| `4aaa814a` | `server_town_camp.sqf`, `server_town_ai.sqf`, town-unit creation/delegation | Server loop and town-AI optimizations intentionally reduced scans and marker work. |
| `6189f3c5` | `server_town_ai.sqf` | Scan budgeting added per-cycle and per-town cadence. |
| `a20a5a0f`, `84b1b684`, `ea0bff2e`, `913ecdf6` | `server_town.sqf`, `server_town_ai.sqf`, delegation/static-defense helpers | Town defense activation needed restoration, defender filtering and diagnostics after performance changes. |

### UI, Markers And Locality

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `9a550b7a` reverts `1b23132d` "Do group leaders need actually global marker vars? Only few know." | `Client/FSM/updateteamsmarkers.sqf` | Marker variable scope is fragile and was reverted quickly. |
| `9c72a281` | marker cache optimization | Cache changes broke unit marker tracking. |
| `951e72cb` | player squad markers | Disconnect cleanup needed explicit repair. |
| `332874fd` and `9a963c19` | town SV marker visibility | Side-specific marker visibility leaked and needed fixes. |
| `a5fc24f4` | WF menu action refresh | Vehicle transitions could hide menu actions until explicitly refreshed. |

### Negative Knowledge

| Evidence | Affected area | What not to assume |
| --- | --- | --- |
| `97da2aeb`, `993e8ed5` revert accelerated day/night cycle | day/night runtime, parameters, server init | Configurable acceleration was not safe as first merged. |
| `9424f0c8` reverts `Marty_repair_camp_menu` | repair camp actions, unit init, skill apply | Repair-camp menu revival needs new validation. |
| PR #9 closed unmerged | endgame music and sound changes | Closed media/UI PR is not baseline behavior. |
| Branch families `A3_*`, `dev_*`, `0=1_*`, `oldMasterBranch` | broad repo archaeology | Branch presence is not authority; use current `master` and merged PRs first. |

## Current Documentation Impact

- [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) is the narrative lesson page built from this evidence.
- [Feature status register](Feature-Status-Register) should keep supply/JIP/town-AI/marker/reverted-feature risks visible when they are still broken, partial or risky in the rayswaynl source.
- [AI Assistant Guide](AI-Assistant-Guide) should route future agents here before they revive old branches or copy unmerged upstream work.

## Follow-Up Investigation

- Compare reverted accelerated day/night commits with the later hybrid day/night synchronization line to capture the exact failure mode.
- Inspect RPT/server notes, if available, for why `Marty_repair_camp_menu` was reverted.
- Build a branch-family index for high-value unmerged branches only after an owner asks to revive one.

## Deep History Addendum: Older Commit Clusters

### Branch Family Taxonomy From Agent-Team Sweep

| Branch family | Interpretation | Developer rule |
| --- | --- | --- |
| `v*`, `dev_*`, `test*` | Dated integration snapshots and live-test staging. | Use for chronology, not as proof that a feature survived. |
| `oldMasterBranch`, `RevertedTo2018Version` | Tombstone/rollback archaeology; `oldMasterBranch` tip `3a7972a2` deletes old master contents, and `RevertedTo2018Version` tip `44abda43` is a test commit. | Never diff these as current gameplay baselines. |
| `0=1_*`, `A3_*`, `a3*` | Arma 3 / external port experiments; later `83298186` removed `A3missionTest`. | Mine concepts only; reject A3 syntax unless OA-compatible. |
| `AntiStack*` | Multiple enforcement, monitoring, removal and reintroduction generations. | Identify generation and rollout mode before copying code. |
| `*_Debug`, `*Testing`, `*WIP`, `*_V999` | Diagnostics or live-test probes. | Preserve intent in docs; strip logs/test values before release. |
| `LoadoutManager*`, `AirRework*`, `Bomb*`, `Maverick*` | Generated aircraft/loadout/missile experiments with reversions. | Regenerate from tool inputs and in-engine test aircraft behavior. |
| `Marty_*` | Newer active upstream feature line. | Treat as stronger current-intent evidence than abandoned 2023-2024 branches, but still verify later reverts. |
| PR branches `MergeToEzcooV3`, `MergeWithMiksuu`, `SupplyRunGlitchFix` | Pull-request lineage; some merged PRs later reverted. | Check PR status plus later revert commits before reviving ideas. |

### 2018 Import And Baseline Edits

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `558537c3`, `bb9cd85e`, `f7bc288c` | initial repo and map imports | Early history is an import baseline, not clean greenfield design. |
| `6e120ebf`, `b66d2681`, `423ce4b6`, `b94e68e6` | ICBM, supply limit, LF upgrade cost, unit tier changes | Balance and config changed immediately after import. Treat early constants as historical defaults, not fixed doctrine. |

### 2022 AntiStack / Join Rewrite

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `09131233` | `Server/Module/AntiStack/clientHasConnectedAtLaunch.sqf` | A command typo broke AntiStack launch detection early. |
| `841d16af` | launch-state variable | `CONNECTED_AT_LAUNCH` changed from bool to player side, proving the variable carried more state than its name implied. |
| `88a2ef49`, `8bf294ac` | `Server/PVFunctions/RequestJoin.sqf`, teamswap | RequestJoin semantics and teamswap special cases needed follow-up fixes. |
| `448b1d85` | `Server/Module/AntiStack/callDatabaseRetrieve.sqf` | DB crash came from string/integer type mismatch. |
| `b32babc7`, `6f1d7af5` | AntiStackV6, monitoring mode | New AntiStack variants could be reverted or run monitoring-only for debug. |
| `2624e943`, `6b34b46d` | mission parameter, `RequestJoin.sqf` | Disabling AntiStack initially disabled too much; teamswap protection had to remain active. |
| `fc55456c`, `b69b901e`, `8b1e220b`, `8b8ea8e7` | `Server_OnPlayerDisconnected.sqf`, `callDatabaseStoreSide.sqf` | Disconnect score/side cleanup feeds future AntiStack team totals. |
| `5ba16fce`, `4f9c21d7`, `931ad04a` | `getTeamScore*.sqf`, `compareTeamScores.sqf`, `RequestJoin.sqf` | DB load and duplicate score retrieval became join-time gameplay risks. |
| `92a5ae70`, `3a852dff`, `5bae9665`, `6acf3c62`, `e9a1a6c3` | Takistan AntiStack files | AntiStack fixes repeatedly needed later Takistan propagation. |

### 2023 Supply / PVEH / RHUD Iteration

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `680f4191`, `8036db59` | `Common_ChangeSideSupply.sqf`, `Server_ChangeSideSupply.sqf`, `Client_ReceiveSupplyValue.sqf` | Side-supply updates moved toward server-side handling. |
| `33143928`, `591a217f`, `17b5fb6e` | supply PVEH request/receive files | publicVariable payload wrapping and array-index mistakes caused immediate fixes. |
| `6cf271a4`, `c45a1c61` | `Client_UpdateRHUD.sqf` | RHUD needed OA-specific boolean/timing workarounds. |
| `33fb2676`, `58171f5e`, `3c2efb8a` | `Server/Module/supplyMission/supplyMissionStarted.sqf` | Supply performance attempts were reverted multiple times before later safer fixes. |
| `3ff02aea` | `Client/Init/Init_Client.sqf` | `clientInitComplete` had to move to the real end of client init after a merge lost the fix. |
| `c6d2539e`, `5b056013`, `5de4d1a2` | buy-units UI, gear templates, CoIn UI | Client UI bugs clustered around shared globals, unguarded namespace lookups, and nil/null confusion. |
| `9795f317`, `a074319b`, `b7bdb70b`, `6e5b3c50`, `9c72a281`, `95a12305` | marker helpers, HQ/UAV/team markers | Marker side locality, moving-object updates and cache optimization repeatedly caused user-visible regressions. |
| `a9044821`, `c464df8b`, `8787ad79`, `3a35748f`, `cfbbbaf0`, `b02782f1` | `CLIENT_INIT_READY`, Attack Wave PV/action flow | Client/server public-variable payload schemas and addAction parameter types repeatedly drifted. |

### 2023-2024 Generated Maps, Tooling And Copy Debt

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `62279d8e`, `0c03dc88`, `abb4d812` | `.gitignore`, `version.sqf` | Generated/ignored version files are central to boot and map-specific behavior. |
| `081c1dc4`, `c312b0ec` | modded terrain folders / mission copies | Upstream explicitly used copypasted or manually copied mission files at times. |
| `812e9596` | Tasmania deletion plus `Tools/LoadoutManager/Data/Terrains/*` | Tasmania became a removed negative example after repeated terrain/version failures. |
| `24bddb66`, `1e8c3025`, `50cbc72e` | `Guides/CommanderGuide/a2WarfareCommanderGuide.md` | LLM/guesswork-generated guide content needed source correction. |
| `20eeaa3e`, `3796feb5` | `Tools/LoadoutManager/FileManagement/FileManager.cs` | LoadoutManager path logic could delete or corrupt modded map outputs. |
| `557f8126`, `0014b9e9`, branch `versionSqfDebug` | generated `version.sqf` | Version generation had preprocessor quoting/syntax hazards. |
| `c2be3919`, `6ae6f36d`, `d475eaff`, `73c9078d` | LoadoutManager generated SQF | Modded/vanilla generation logic was retrofitted after failed writes and reverted attempts. |
| `6abfc286`, `359b0cbf` | `Tools/LoadoutManager/bin/*` | Tool upgrade accidentally committed build outputs, then removed them via gitignore cleanup. |
| `2f6a4d32`, `980b3539` | aircraft loadouts / `Tools/LoadoutManager/Program.cs` | Generator output could overwrite hand-debugged aircraft/missile work, including GPT-generated combinations. |

### Removed Or Reverted Systems

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `f61f7222`, `4881e0d5` | `Client_TaskSystem.sqf`, `Init_Client.sqf`, `TownCaptured.sqf` across terrains | Task system was intentionally removed and propagated. |
| `16856ae7`, `8b7fab95` | guerilla barracks code | Guerilla operating barracks were fully removed, not merely hidden. |
| `77a07bc0` | `Construction_MediumSite.sqf`, `Construction_SmallSite.sqf`, `RequestStructure.sqf` | Construction duplicate-code refactor was reverted. |
| `31d8a06d` | `GUI_Menu_Tactical.sqf` across maps | Cheaper nuke experiment was explicitly reverted. |
| `6ba2344d` | `UAV_MarkerFix` merge | UAV marker fix branch was reverted after merge; later current behavior needs source re-check. |
| PR #3, `346e3be8` | `Action_RepairMHQ.sqf`, `Init_CommonConstants.sqf`, `stringtable.xml` | Merged HQ repair price work was later reverted, proving merge status alone is insufficient. |
| PR #9 | endgame music branch | Endgame music was closed unmerged against `v16102023`. |
| `f10d5bd9`, `8d74c332` | bomb restriction/debug branches, `Common_HandleIncomingMissile.sqf` | Bomb limiter/debug work was reverted and needs in-engine aircraft testing before revival. |
| `f67f0399`, `c23ba233`, `afe91fb6` | `Construction_StationaryDefense.sqf` | Broad nil guards for repair-truck defense construction suppressed enough behavior to be reverted. |
| `46f0a301`, `3a0b13f8` | `Server/Init/Init_Defenses.sqf` | Commenting array elements for factory walls caused syntax/runtime failure. |
| `4e6d585f`, `79680595`, `f17445c1` | `Server_BuildingKilled.sqf`, `Server_OnHQKilled.sqf` | Factory-kill score work needed immediate syntax and teamkill-scope fixes. |

### Compatibility And UI Locality

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `2a62eaa0` | `Construction_StationaryDefense.sqf` | A3 `createGroup` syntax caused runtime error in OA mission code. |
| `95a12305` | `Client/Module/UAV/uav_interface_oa.sqf` across maps | UAV marker messaging leaked to global chat and was moved to a marker helper. |
| `7e3b9f4c`, `6eb1cbfa` | `Client/FSM/updateclient.sqf`, FPS optimizer UI | Client FPS optimizer interacted badly with map-open state and needed tooltip correction. |
| `83298186` | `A3missionTest` deletion | Large A3 imported test tree was later removed; A3 branches are concept-only for OA docs. |
| `a388f073`, `00791850`, `3c6a70c3`, `7e3b9f4c` | view-distance automation | FPS control loops learned the wrong state while the map was open. |
| `b76f9645`, PR #12 | supply truck JIP notification | Client action/notification logic can run during JIP without a real player action. |

## Second-Wave Deep Dive: PR Afterlife, Tooling And Branch-Only Evidence

### PR Body / Title Evidence

| Evidence | Files / area | Finding |
| --- | --- | --- |
| PR #1, PR #2; `96809ac3`, `7a38af51`, `01ea8db4` | repo topology, `.gitmodules`, DiscordBotFramework, mission folders | Closed broad-merge PRs were not necessarily dead; individual commits and folder-structure ideas can persist outside the PR result. |
| PR #4 / `38b662aa`, later `6eb09dc3` | `Client/Init/Init_Client.sqf`, `wfbe_structures` | Latest-built-factory spawn needed later structure-type filtering; array order was too broad. |
| PR #5 / `d086863c`, `e3ec8a17` | supply missions, `mission.sqm`, `Client/Init/Init_Client.sqf` | Supply-run feature work needed lobby-class metadata and init-idempotence follow-through. |
| PR #6 / `670ecb6c` | `Client/GUI/GUI_Menu_BuyUnits.sqf` | Driver-slot preference persisted through `profileNamespace`, so UI state can survive matches. |
| PR #7 / `8c88e5ef`, `aab49c33`, later `c07fe1e6`, `d3c5cc89` | commander UX, `Sounds/description.ext`, `Music/description.ext` | Commander help, sound effects and endgame music became entangled with asset/config packaging. |

### Dormant Branch Leads

| Branch / evidence | Files / area | Finding |
| --- | --- | --- |
| `upstream/commonbalanceinit_Old` tip `37e08f33`; `upstream/AirReworkTestBranch` tip `9973ef27`; commits `5d9c4587`, `c5953651`, `ddcbd3ca` | LoadoutManager, EASA, `Common_BalanceInit.sqf` | Aircraft/loadout history contains branch-only pylon/default-tag validation lessons; generated surfaces must move together. |
| `upstream/AutomationSystems` tip `25f2b5ab` | callExtension, restart automation, backend process handoff | Direct `RESTARTSERVER` extension work evolved toward pipe/backend process handoff, absolute paths and delayed priority changes. |
| `upstream/HeadlessClientMultithreading`; `6760f1a3`, `1d79ba2a`, `6b90c872`, `f5e8fa47` | HC delegation, static defenses | Multi-HC work needed typed HC pools and side-less HC client-call filtering; update-back accounting remains a risk. |
| `upstream/MgNestRestriction` tip `498bd6c4` | static defense restrictions | Repeated wrong-block and `isKindOf` fixes show static-defense restrictions must sit in the correct class branch. |
| `upstream/Tournament_SideSpeakerWIP` tip `8ddeb502` | spectator/tournament side speaker | Branch tip admits civilian side speaker may broadcast to all players; audience/channel scope is unresolved. |
| `upstream/BlinkingDone`, `upstream/WorkingBlinking`, `upstream/BlinkingMapIconsV2`; `2f6ff43d`, `9a550b7a`, `9c1fe110` | marker blinking, event handlers | Marker blinking churned through refactor reverts, local/global marker vars, color restoration and a default-off mission parameter. |

### Tooling, Packaging And Generated Assets

| Evidence | Files / area | Finding |
| --- | --- | --- |
| current `Tools/LoadoutManager/ZipManager.cs`, earlier `0ffc3cb8` | `_MISSIONS.7z`, `Missions`, `Missions_Vanilla`, `Modded_Missions` | Current packaging is Vanilla-only plus source missions; modded packaging/generation is commented out. |
| `465a5aa5`, `0ffc3cb8` | `TempZippingDirectory`, `_MISSIONS.7z` | Release zipping moved temp output under the repo root and now rewrites the archive. |
| `2a13ce36`, merge `407c2d2d` | `ZipManager.cs`, env var `7za` | Packaging depends on a `7za` environment variable; missing 7-Zip is a packaging failure distinct from generation. |
| `3458e714`, merge `9d8f3770` | LoadoutManager file copy | File-copy propagation hit locked-file cases and moved to explicit stream copy with IOException logging. |
| `6d380c22`, `0fd730b0`, `24f4656f` | `version.sqf`, `description.ext`, mission parameters | Generated defines and parameter include order are a real config contract. |
| `aa3f0451`, `f095e461` | Takistan DB map ID, LoadoutManager post-copy fix | Generated Takistan needed generator-side repair after Chernarus copy overwrote map identity. |
| `0d0ac310` | `Server/Module/PersistanceDB/*`, callExtension | Removed `PersistanceDB` is a tombstone, but AntiStack DB and GlobalGameStats extension families remain live. |
| `a31cfdb4`, `e2d23d00` | sound generation, `.ogg` names, `Sounds/description.ext` | Sound config generation depends on `ClassName-volume.ogg` filename shape. |

### Economy, Ordnance And Compensation

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `9bf51d60`, `4c1d2fd9`, PR #3 / `7cd0e18d`, `346e3be8`, `59a995e8`, `a855081d` | `Action_RepairMHQ.sqf`, `Init_CommonConstants.sqf` | HQ repair escalation was reverted until repair economics are server-owned. |
| `5db438ca`, `31d8a06d` | `GUI_Menu_Tactical.sqf`, ICBM fee | 75k ICBM pricing was live-test data and explicitly reverted. |
| current `nukeincoming.sqf`, `GUI_Menu_Tactical.sqf`, DR-27 | ICBM request/debit authority | ICBM price/effect churn did not fix client-authoritative request/debit risk. |
| `67886498`, `82bb5daf`, current `Common_HandleAAMissiles.sqf` | Maverick missile handling | Extreme Maverick parameters were experimental and later replaced by current handler values. |
| `4720880a`, current `EASA_Init.sqf` | Mavericks/Spikes loadouts | Mavericks-to-Spikes branch is not current master truth for aircraft. |
| `0c14f001`, `82fbab1f`, `bc5f23d5`, `7fddb251` | bomb scripts and altitude/distance limits | Bomb restriction history is workaround/revert/re-add/near-disable churn, not clean policy. |
| `f17445c1`, `b31539b4`, `cc127ef4`, `415615c9` | score, bounty, teamkill paths | Score/bounty changes affect AntiStack skill and economy, not only the scoreboard. |
| `upstream/SkillDiffCompensation`, current `skillDiffCompensation.sqf`, `Common_ChangeSideSupply.sqf` | side supply, DB skill, compensation | Skill-diff compensation rides on side-supply channels that still need authority hardening. |

### AI, HC, Cleanup And Runtime

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `4aaa814a`, `6189f3c5`, `1d5092ef`, `a20a5a0f`, `84b1b684`, `ea0bff2e`, `913ecdf6` | town AI, town capture, defender tags | Town scan optimization needed restoration of remote/pre-capture activation and defender-origin filtering. |
| `a20a5a0f`, `84b1b684` | capture detection vs pre-capture activation | Capture-scan wakeup was too late; pre-capture scans were restored. |
| `ea0bff2e` | `WFBE_IsTownDefenderAI` | Defender units, crews, vehicles and groups must be tagged so they do not wake enemy towns. |
| `823ad0da`, `a6f5020e`, `99bd4be8`, `8372f5ce` | RHUD/server FPS publishing | Diagnostics can become performance bugs; FPS HUD fixes and server loops both had reverts/guards. |
| `95481b37`, DR-45 | mines cleanup, `wfbe_trashed`, town-AI despawn | Cleanup bugs are array-shape, idempotency and full-occupancy checks, not only missing deletes. |
| local `feat/ai-commander` head `4dba060e` (`585c3519`, `1a3e3def`, `4c2abced`, `4dba060e`) | `Server/AI/Commander/*`, `Server_AI_Com_Upgrade.sqf`, `Init_Server.sqf`, `Parameters.hpp` | AI commander revival is branch-only/local evidence until merged, propagated and smoked: default-on AI commander, per-side supervisor, assign/produce workers, explicit order executor and upgrade cost fixes are source-Chernarus-only. |
